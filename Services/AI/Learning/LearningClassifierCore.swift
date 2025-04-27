import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

extension AI_Learning {
    /// Core classification logic for the adaptive learning system
    class LearningClassifierCore {
        private let persistenceController: PersistenceController
        private let dataManager: LearningDataManager
        private let persistence: LearningPersistence
        private let vectorization: LearningVectorization
        private let algorithms: LearningAlgorithms
        private let metrics: LearningMetrics
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
            
            // Initialize components
            self.dataManager = LearningDataManager(persistenceController: persistenceController)
            self.persistence = LearningPersistence(persistenceController: persistenceController)
            self.vectorization = LearningVectorization()
            self.algorithms = LearningAlgorithms()
            self.metrics = LearningMetrics(persistenceController: persistenceController)
            
            print("🧠 LearningClassifierCore initialized")
        }
        
        func finishInitialization() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                // Run post-initialization verification
                self.verifyAndFixCoreDataStorage()
                let stats = self.getLearningStatistics()
                print("🧠 LearningClassifierCore finished initialization with \(stats.totalExamples) learning examples")
            }
        }
        
        // Record when user corrects an AI suggestion
        func recordUserCorrection(originalText: String, 
                                  aiSuggestion: DocumentClassifierService.DocumentSuggestions,
                                  finalUserChoice: DocumentClassifierService.DocumentSuggestions) {
            print("🧠 Recording user correction for adaptive learning")
            
            // Force comparisons to be case-insensitive and trim whitespace
            let aiFolder = aiSuggestion.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let userFolder = finalUserChoice.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            
            let aiTags = Set(aiSuggestion.suggestedTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            let userTags = Set(finalUserChoice.suggestedTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            
            // Log detailed differences
            print("🧠 CORRECTION DETAILS (normalized):")
            print("   • Title: \(aiSuggestion.suggestedTitle) → \(finalUserChoice.suggestedTitle)")
            print("   • Folder: \(aiFolder) → \(userFolder)")
            print("   • Tags AI: \(aiSuggestion.suggestedTags.joined(separator: ", "))")
            print("   • Tags User: \(finalUserChoice.suggestedTags.joined(separator: ", "))")
            print("   • Tags Added: \(userTags.subtracting(aiTags))")
            print("   • Tags Removed: \(aiTags.subtracting(userTags))")
            
            // Create a unique fingerprint for this document
            let fingerprint = vectorization.createDocumentFingerprint(originalText)
            let example = ClassificationPair(
                documentFingerprint: fingerprint,
                aiSuggestion: aiSuggestion,
                userSelection: finalUserChoice,
                timestamp: Date()
            )
            
            // Store the example in the data manager
            dataManager.storeExample(example)
            
            // Save patterns to KeywordPattern entities
            persistence.savePatterns(aiSuggestion: aiSuggestion, userSelection: finalUserChoice)
            
            // Verify data was saved by reloading
            dataManager.loadLearningExamples()
            print("🔄 Reloaded learning examples from Core Data: \(dataManager.getAllExamples().count) examples")
        }
        
        // Use the learning database to enhance OpenAI prompts
        func enhancePromptWithLearning(documentText: String, basePrompt: String) -> String {
            // Create document fingerprint for pattern matching
            let fingerprint = vectorization.createDocumentFingerprint(documentText)
            
            // Get stats for logging
            let stats = getLearningStatistics()
            
            // Skip enhancement if we don't have enough learning examples
            if stats.totalExamples < 2 {
                print("🧠 Not enough learning examples to enhance classification (need at least 2)")
                return basePrompt
            }
            
            print("🧠 Enhancing classification prompt with learning data from \(stats.totalExamples) examples")
            
            // Build enhanced prompt sections
            var enhancedSections = [String]()
            
            // Add the base prompt first
            enhancedSections.append(basePrompt)
            
            // Add a section with specific user preferences
            enhancedSections.append("\nBased on previous documents, I've observed these patterns in how the user prefers to organize:")
            
            // Add folder insights
            let folderPatterns = algorithms.buildFolderCorrectionPatterns(from: dataManager.getAllExamples())
            if !folderPatterns.isEmpty {
                enhancedSections.append("\nFOLDER PREFERENCES:")
                enhancedSections.append(contentsOf: folderPatterns)
            }
            
            // Add tag insights
            let tagPatterns = algorithms.buildTagCorrectionPatterns(from: dataManager.getAllExamples())
            if !tagPatterns.isEmpty {
                enhancedSections.append("\nTAG PREFERENCES:")
                enhancedSections.append(contentsOf: tagPatterns)
            }
            
            // Find relevant examples for context
            let relevantExamples = vectorization.findRelevantCorrectionExamples(
                examples: dataManager.getAllExamples(), 
                for: fingerprint
            )
            
            if !relevantExamples.isEmpty {
                enhancedSections.append("\nRELEVANT EXAMPLES:")
                for (index, example) in relevantExamples.enumerated().prefix(3) {
                    let aiFolder = example.aiSuggestion.suggestedFolderName ?? "no folder"
                    let userFolder = example.userSelection.suggestedFolderName ?? "no folder"
                    
                    enhancedSections.append("Example \(index + 1):")
                    if example.aiSuggestion.suggestedTitle != example.userSelection.suggestedTitle {
                        enhancedSections.append("- Changed title from '\(example.aiSuggestion.suggestedTitle)' to '\(example.userSelection.suggestedTitle)'")
                    }
                    if aiFolder != userFolder {
                        enhancedSections.append("- Changed folder from '\(aiFolder)' to '\(userFolder)'")
                    }
                    
                    // Show tag changes
                    let aiTags = Set(example.aiSuggestion.suggestedTags)
                    let userTags = Set(example.userSelection.suggestedTags)
                    
                    let tagsAdded = userTags.subtracting(aiTags)
                    let tagsRemoved = aiTags.subtracting(userTags)
                    
                    if !tagsAdded.isEmpty {
                        enhancedSections.append("- Added tags: \(Array(tagsAdded).joined(separator: ", "))")
                    }
                    if !tagsRemoved.isEmpty {
                        enhancedSections.append("- Removed tags: \(Array(tagsRemoved).joined(separator: ", "))")
                    }
                }
            }
            
            // Final instruction to follow the patterns
            enhancedSections.append("\nPlease classify this document in a way that follows these user preferences. Take these patterns into account for your suggested title, folder, and tags.")
            
            // Build the complete prompt
            let adaptivePrompt = enhancedSections.joined(separator: "\n")
            
            print("🧠 Successfully enhanced prompt with learning patterns")
            return adaptivePrompt
        }
        
        // Get learning statistics
        func getLearningStatistics() -> LearningStatistics {
            return persistence.getLearningStatistics()
        }
        
        // Debug methods for verification and repair
        
        func verifyAndFixCoreDataStorage() {
            dataManager.verifyAndFixCoreDataStorage()
        }
        
        func repairBrokenEntities() {
            dataManager.repairBrokenEntities()
        }
        
        // Debug method to get folder patterns
        func debugGetLearnedFolderPatterns() -> [(original: String, updated: String, count: Int)] {
            return persistence.getFolderCorrectionPatterns()
        }
        
        // Debug method to get recent examples
        func debugGetRecentExamples() -> [ClassificationPair] {
            // Return the 5 most recent examples
            return Array(dataManager.getAllExamples().prefix(5))
        }
        
        // Check for deleted folders and tags
        func getDeletedFoldersAndTags(existingFolders: [String], existingTags: [String]) -> (folders: [String], tags: [String]) {
            let result = algorithms.getDeletedFoldersAndTags(
                from: dataManager.getAllExamples(),
                existingFolders: existingFolders,
                existingTags: existingTags
            )
            
            // Update history if any deleted items were found
            if !result.folders.isEmpty || !result.tags.isEmpty {
                persistence.updateDeletedItemsHistory(folders: result.folders, tags: result.tags)
            }
            
            return result
        }
        
        // Get history of deleted items
        func getDeletedItemsHistory() -> [(type: String, name: String, date: Date)] {
            return persistence.getDeletedItemsHistory()
        }
        
        // Get folder-tag relationship patterns
        func getFolderTagPatternStatistics() -> [String: [(tag: String, frequency: Double)]] {
            return algorithms.getFolderTagPatternStatistics(from: dataManager.getAllExamples())
        }
    }
}

import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

/// Main implementation of the adaptive learning classifier
/// This class serves as the container for all adaptive learning components
extension AI_Learning {
    class AdaptiveLearningClassifier {
        // Core component that handles the actual classification logic
        private let classifierCore: LearningClassifierCore
        
        // Reference to the persistence controller for CoreData operations
        private let persistenceController: PersistenceController
        
        // Init with dependency injection for persistence controller
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
            
            print("🧠 Initializing AdaptiveLearningClassifier...")
            
            // Initialize the core classifier which manages all subcomponents
            self.classifierCore = LearningClassifierCore(persistenceController: persistenceController)
            
            print("🧠 AdaptiveLearningClassifier initialized")
        }
        
        // Public method for post-initialization tasks
        func finishInitialization() {
            classifierCore.finishInitialization()
        }
        
        // Record when user corrects an AI suggestion
        func recordUserCorrection(originalText: String, 
                                 aiSuggestion: DocumentClassifierService.DocumentSuggestions,
                                 finalUserChoice: DocumentClassifierService.DocumentSuggestions) {
            classifierCore.recordUserCorrection(
                originalText: originalText,
                aiSuggestion: aiSuggestion,
                finalUserChoice: finalUserChoice
            )
        }
        
        // Use the learning database to enhance OpenAI prompts
        func enhancePromptWithLearning(documentText: String, basePrompt: String) -> String {
            return classifierCore.enhancePromptWithLearning(
                documentText: documentText,
                basePrompt: basePrompt
            )
        }
        
        // Load learning examples from Core Data
        func loadLearningExamples() {
            // This is delegated to LearningDataManager inside classifierCore
        }
        
        // Get statistics about the learning database
        func getLearningStatistics() -> (totalExamples: Int, folderCorrections: Int, tagCorrections: Int) {
            let stats = classifierCore.getLearningStatistics()
            return (
                totalExamples: stats.totalExamples,
                folderCorrections: stats.folderCorrections,
                tagCorrections: stats.tagCorrections
            )
        }
        
        // Verify and fix Core Data storage issues
        func verifyAndFixCoreDataStorage() {
            classifierCore.verifyAndFixCoreDataStorage()
        }
        
        // Method to repair broken entities in Core Data
        func repairBrokenEntities() {
            classifierCore.repairBrokenEntities()
        }
        
        // Check for deleted folders and tags
        func getDeletedFoldersAndTags() -> (folders: [String], tags: [String]) {
            // Get currently existing folders and tags from Core Data
            let context = persistenceController.viewContext
            
            // Fetch all folders
            let folderFetchRequest = NSFetchRequest<Folder>(entityName: "Folder")
            let existingFolders: [String] = (try? context.fetch(folderFetchRequest).compactMap { $0.name }) ?? []
            
            // Fetch all tags
            let tagFetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
            let existingTags: [String] = (try? context.fetch(tagFetchRequest).compactMap { $0.name }) ?? []
            
            // Delegate to the classifier core
            return classifierCore.getDeletedFoldersAndTags(
                existingFolders: existingFolders,
                existingTags: existingTags
            )
        }
        
        // Get history of deleted items
        func getDeletedItemsHistory() -> [(type: String, name: String, date: Date)] {
            return classifierCore.getDeletedItemsHistory()
        }
        
        // Get folder-tag relationship patterns
        func getFolderTagPatternStatistics() -> [String: [(tag: String, frequency: Double)]] {
            return classifierCore.getFolderTagPatternStatistics()
        }
        
        // Debug methods for developer use
        
        // Get learned folder patterns for debugging
        func debugGetLearnedFolderPatterns() -> [(original: String, updated: String, count: Int)] {
            return classifierCore.debugGetLearnedFolderPatterns()
        }
        
        // Get recent examples for debugging
        func debugGetRecentExamples() -> [ClassificationPair] {
            return classifierCore.debugGetRecentExamples()
        }
    }
}

// Make ClassificationPair available at the top level for backward compatibility
typealias ClassificationPair = AI_Learning.ClassificationPair

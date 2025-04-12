import Foundation
import CoreData

class AdaptiveLearningClassifier {
    static let shared = AdaptiveLearningClassifier()
    
    // Store both AI suggestions and user's final choices
    struct ClassificationPair: Codable {
        let documentFingerprint: String  // Hash or signature of document
        let aiSuggestion: DocumentClassifierService.DocumentSuggestions
        let userSelection: DocumentClassifierService.DocumentSuggestions
        let timestamp: Date
        
        // Standard memberwise initializer
        init(documentFingerprint: String, 
             aiSuggestion: DocumentClassifierService.DocumentSuggestions,
             userSelection: DocumentClassifierService.DocumentSuggestions,
             timestamp: Date) {
            self.documentFingerprint = documentFingerprint
            self.aiSuggestion = aiSuggestion
            self.userSelection = userSelection
            self.timestamp = timestamp
        }
        
        // Custom Codable implementation because DocumentClassifierService.DocumentSuggestions isn't Codable
        enum CodingKeys: String, CodingKey {
            case documentFingerprint, timestamp
            case aiSuggestion, userSelection
        }
        
        // Custom encoding for DocumentSuggestions
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(documentFingerprint, forKey: .documentFingerprint)
            try container.encode(timestamp, forKey: .timestamp)
            
            // Encode AI suggestion
            var aiContainer = container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .aiSuggestion)
            try aiContainer.encode(aiSuggestion.suggestedTitle, forKey: .title)
            try aiContainer.encode(aiSuggestion.suggestedFolderName, forKey: .folder)
            try aiContainer.encode(aiSuggestion.suggestedTags, forKey: .tags)
            try aiContainer.encode(aiSuggestion.confidence, forKey: .confidence)
            
            // Encode user selection
            var userContainer = container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .userSelection)
            try userContainer.encode(userSelection.suggestedTitle, forKey: .title)
            try userContainer.encode(userSelection.suggestedFolderName, forKey: .folder)
            try userContainer.encode(userSelection.suggestedTags, forKey: .tags)
            try userContainer.encode(userSelection.confidence, forKey: .confidence)
        }
        
        // Custom decoding for DocumentSuggestions
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            documentFingerprint = try container.decode(String.self, forKey: .documentFingerprint)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            
            // Decode AI suggestion
            let aiContainer = try container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .aiSuggestion)
            let aiTitle = try aiContainer.decode(String.self, forKey: .title)
            // Make folder decoding safer by handling nulls
            let aiFolder: String?
            if try aiContainer.contains(.folder) && !(try aiContainer.decodeNil(forKey: .folder)) {
                aiFolder = try aiContainer.decode(String.self, forKey: .folder)
            } else {
                aiFolder = nil
            }
            let aiTags = try aiContainer.decode([String].self, forKey: .tags)
            let aiConfidence = try aiContainer.decode(Double.self, forKey: .confidence)
            
            aiSuggestion = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: aiTitle,
                suggestedFolderName: aiFolder,
                suggestedTags: aiTags,
                confidence: aiConfidence
            )
            
            // Decode user selection
            let userContainer = try container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .userSelection)
            let userTitle = try userContainer.decode(String.self, forKey: .title)
            // Make folder decoding safer by handling nulls
            let userFolder: String?
            if try userContainer.contains(.folder) && !(try userContainer.decodeNil(forKey: .folder)) {
                userFolder = try userContainer.decode(String.self, forKey: .folder)
            } else {
                userFolder = nil
            }
            let userTags = try userContainer.decode([String].self, forKey: .tags)
            let userConfidence = try userContainer.decode(Double.self, forKey: .confidence)
            
            userSelection = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: userTitle,
                suggestedFolderName: userFolder,
                suggestedTags: userTags,
                confidence: userConfidence
            )
        }
        
        // Nested coding keys for DocumentSuggestions
        enum SuggestionCodingKeys: String, CodingKey {
            case title, folder, tags, confidence
        }
    }
    
    // Database of learning examples
    private var learningExamples: [ClassificationPair] = []
    
    private init() {
        print("🧠 Initializing AdaptiveLearningClassifier...")
        
        // Make sure the KeywordPattern entity is properly initialized
        verifyAndCreateKeywordPatternEntity()
        
        // First try to load from Core Data
        loadLearningExamples()
        
        // Then check if we need to migrate old data
        migrateFromUserDefaultsIfNeeded()
        
        // Debug output current state
        print("🧠 AdaptiveLearningClassifier initialized with \(learningExamples.count) examples")
        
        // Immediately verify Core Data state
        verifyAndFixCoreDataStorage()
    }
    
    // Add a method to verify and create the KeywordPattern entity if needed
    private func verifyAndCreateKeywordPatternEntity() {
        let context = PersistenceController.shared.viewContext
        
        // Check if KeywordPattern entity exists
        if NSEntityDescription.entity(forEntityName: "KeywordPattern", in: context) == nil {
            print("⚠️ KeywordPattern entity does not exist - attempting to create it")
            
            // Since we can't dynamically create Core Data entities at runtime,
            // we'll need to ensure the data model includes this entity
            print("❌ Could not create KeywordPattern entity - it must be added to the Core Data model")
        } else {
            print("✅ KeywordPattern entity exists in the Core Data model")
            
            // Verify we can fetch from it
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "KeywordPattern")
            fetchRequest.fetchLimit = 1
            
            do {
                _ = try context.fetch(fetchRequest)
                print("✅ Successfully verified KeywordPattern entity is queryable")
            } catch {
                print("⚠️ Error verifying KeywordPattern entity: \(error.localizedDescription)")
            }
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
        let fingerprint = createDocumentFingerprint(originalText)
        let example = ClassificationPair(
            documentFingerprint: fingerprint,
            aiSuggestion: aiSuggestion,
            userSelection: finalUserChoice,
            timestamp: Date()
        )
        
        // Check if we already have this fingerprint
        let existingIndex = learningExamples.firstIndex { $0.documentFingerprint == fingerprint }
        if let index = existingIndex {
            // Replace the existing example instead of adding a duplicate
            print("🔄 Replacing existing learning example with same fingerprint")
            learningExamples[index] = example
        } else {
            // Add new example
            learningExamples.append(example)
        }
        
        // Save patterns to KeywordPattern entities
        savePatterns(aiSuggestion: aiSuggestion, userSelection: finalUserChoice)
        
        // Use direct Core Data saving which has better error handling
        saveToCoreData(example)
        // Don't call saveLearningExamples() as it tries to replace all examples
        
        print("✅ Saved learning example - now have \(learningExamples.count) examples")
        
        // Verify it was actually saved
        loadLearningExamples()
        print("🔄 Reloaded learning examples from Core Data: \(learningExamples.count) examples")
    }
    
    // Save patterns to KeywordPattern entities
    private func savePatterns(aiSuggestion: DocumentClassifierService.DocumentSuggestions, userSelection: DocumentClassifierService.DocumentSuggestions) {
        let context = PersistenceController.shared.viewContext
        
        // First verify KeywordPattern entity exists
        guard NSEntityDescription.entity(forEntityName: "KeywordPattern", in: context) != nil else {
            print("⚠️ KeywordPattern entity not available - skipping pattern saving")
            return
        }
        
        // Save folder patterns if they've changed
        if aiSuggestion.suggestedFolderName != userSelection.suggestedFolderName,
           let aiFolder = aiSuggestion.suggestedFolderName,
           let userFolder = userSelection.suggestedFolderName,
           !aiFolder.isEmpty,
           !userFolder.isEmpty {
            
            // Check if this pattern already exists
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@ AND aiValue == %@ AND userValue == %@", 
                                               "folder", aiFolder, userFolder)
            
            do {
                let existingPatterns = try context.fetch(fetchRequest)
                if let existingPattern = existingPatterns.first {
                    // Increment occurrence count
                    let occurrences = existingPattern.value(forKey: "occurrences") as? Int32 ?? 0
                    existingPattern.setValue(occurrences + 1, forKey: "occurrences")
                    print("📊 Incremented existing folder pattern: \(aiFolder) → \(userFolder) (now \(occurrences + 1))")
                } else {
                    // Create new pattern
                    let newPattern = NSEntityDescription.insertNewObject(forEntityName: "KeywordPattern", into: context)
                    newPattern.setValue(UUID(), forKey: "id")
                    newPattern.setValue("folder", forKey: "fieldType")
                    newPattern.setValue(aiFolder, forKey: "aiValue")
                    newPattern.setValue(userFolder, forKey: "userValue")
                    newPattern.setValue(1, forKey: "occurrences")
                    print("📊 Created new folder pattern: \(aiFolder) → \(userFolder)")
                }
                
                try context.save()
            } catch {
                print("❌ Error saving folder pattern: \(error.localizedDescription)")
            }
        }
        
        // Save tag patterns (added tags)
        let aiTags = Set(aiSuggestion.suggestedTags)
        let userTags = Set(userSelection.suggestedTags)
        let addedTags = userTags.subtracting(aiTags)
        let removedTags = aiTags.subtracting(userTags)
        
        // Handle added tags
        for tag in addedTags {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@ AND userValue == %@", 
                                               "tag_added", tag)
            
            do {
                let existingPatterns = try context.fetch(fetchRequest)
                if let existingPattern = existingPatterns.first {
                    // Increment occurrence count
                    let occurrences = existingPattern.value(forKey: "occurrences") as? Int32 ?? 0
                    existingPattern.setValue(occurrences + 1, forKey: "occurrences")
                    print("📊 Incremented existing added tag pattern: \(tag) (now \(occurrences + 1))")
                } else {
                    // Create new pattern
                    let newPattern = NSEntityDescription.insertNewObject(forEntityName: "KeywordPattern", into: context)
                    newPattern.setValue(UUID(), forKey: "id")
                    newPattern.setValue("tag_added", forKey: "fieldType")
                    newPattern.setValue(tag, forKey: "userValue")
                    newPattern.setValue(1, forKey: "occurrences")
                    print("📊 Created new added tag pattern: \(tag)")
                }
                
                try context.save()
            } catch {
                print("❌ Error saving added tag pattern: \(error.localizedDescription)")
            }
        }
        
        // Handle removed tags
        for tag in removedTags {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@ AND aiValue == %@", 
                                               "tag_removed", tag)
            
            do {
                let existingPatterns = try context.fetch(fetchRequest)
                if let existingPattern = existingPatterns.first {
                    // Increment occurrence count
                    let occurrences = existingPattern.value(forKey: "occurrences") as? Int32 ?? 0
                    existingPattern.setValue(occurrences + 1, forKey: "occurrences")
                    print("📊 Incremented existing removed tag pattern: \(tag) (now \(occurrences + 1))")
                } else {
                    // Create new pattern
                    let newPattern = NSEntityDescription.insertNewObject(forEntityName: "KeywordPattern", into: context)
                    newPattern.setValue(UUID(), forKey: "id")
                    newPattern.setValue("tag_removed", forKey: "fieldType")
                    newPattern.setValue(tag, forKey: "aiValue")
                    newPattern.setValue(1, forKey: "occurrences")
                    print("📊 Created new removed tag pattern: \(tag)")
                }
                
                try context.save()
            } catch {
                print("❌ Error saving removed tag pattern: \(error.localizedDescription)")
            }
        }
    }
    
    // Add this helper method for direct Core Data saving
    private func saveToCoreData(_ example: ClassificationPair) {
        let context = PersistenceController.shared.viewContext
        
        let newExample = LearningExample(context: context)
        newExample.id = UUID()
        newExample.documentFingerprint = example.documentFingerprint
        newExample.timestamp = example.timestamp
        
        // Convert suggestions to data with detailed error handling
        do {
            let aiData = try JSONEncoder().encode(example.aiSuggestion)
            newExample.aiSuggestionData = aiData
            print("✅ Successfully encoded AI suggestion data: \(aiData.count) bytes")
        } catch {
            print("❌ Error encoding AI suggestion: \(error.localizedDescription)")
        }
        
        do {
            let userSelectionData = try JSONEncoder().encode(example.userSelection)
            newExample.userSelectionData = userSelectionData
            print("✅ Successfully encoded user selection data: \(userSelectionData.count) bytes")
        } catch {
            print("❌ Error encoding user selection: \(error.localizedDescription)")
        }
        
        // Save context immediately with better error handling
        do {
            try context.save()
            print("✅ Successfully saved learning example to Core Data")
        } catch {
            print("❌ Error saving to Core Data: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
        }
    }
    
    // Use the learning database to enhance OpenAI prompts
    func enhancePromptWithLearning(documentText: String, basePrompt: String) -> String {
        // Create document fingerprint for pattern matching
        let fingerprint = createDocumentFingerprint(documentText)
        
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
        
        // Add folder insights from DocumentLearningService
        do {
            let context = PersistenceController.shared.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@", "folder")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            fetchRequest.fetchLimit = 5
            
            let folderPatterns = try context.fetch(fetchRequest)
            if !folderPatterns.isEmpty {
                enhancedSections.append("\nFOLDER PREFERENCES:")
                
                // Group by aiValue -> userValue patterns
                var folderTransitions: [String: [String]] = [:]
                for pattern in folderPatterns {
                    guard let aiValue = pattern.value(forKey: "aiValue") as? String, 
                          let userValue = pattern.value(forKey: "userValue") as? String else { continue }
                    if folderTransitions[aiValue] == nil {
                        folderTransitions[aiValue] = [userValue]
                    } else if !folderTransitions[aiValue]!.contains(userValue) {
                        folderTransitions[aiValue]!.append(userValue)
                    }
                }
                
                // Add folder transition patterns to prompt
                for (aiFolder, userFolders) in folderTransitions {
                    let folderList = userFolders.joined(separator: ", ")
                    enhancedSections.append("- When content suggests folder '\(aiFolder)', user prefers '\(folderList)'")
                }
            }
        } catch {
            print("⚠️ Error fetching folder patterns: \(error.localizedDescription)")
        }
        
        // Add tag insights from DocumentLearningService
        do {
            let context = PersistenceController.shared.viewContext
            let addedTagsRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            addedTagsRequest.predicate = NSPredicate(format: "fieldType == %@", "tag_added")
            addedTagsRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            addedTagsRequest.fetchLimit = 5
            
            let addedTagPatterns = try context.fetch(addedTagsRequest)
            if !addedTagPatterns.isEmpty {
                enhancedSections.append("\nTAG PREFERENCES:")
                
                // Extract commonly added tags
                var commonlyAddedTags: [String] = []
                for pattern in addedTagPatterns {
                    if let tag = pattern.value(forKey: "userValue") as? String, !tag.isEmpty, !commonlyAddedTags.contains(tag) {
                        commonlyAddedTags.append(tag)
                    }
                }
                
                // Add to prompt
                if !commonlyAddedTags.isEmpty {
                    enhancedSections.append("- User frequently adds these tags: \(commonlyAddedTags.joined(separator: ", "))")
                }
            }
            
            // Fetch commonly removed tags
            let removedTagsRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            removedTagsRequest.predicate = NSPredicate(format: "fieldType == %@", "tag_removed")
            removedTagsRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            removedTagsRequest.fetchLimit = 5
            
            let removedTagPatterns = try context.fetch(removedTagsRequest)
            if !removedTagPatterns.isEmpty {
                // Extract commonly removed tags
                var commonlyRemovedTags: [String] = []
                for pattern in removedTagPatterns {
                    if let tag = pattern.value(forKey: "aiValue") as? String, !tag.isEmpty, !commonlyRemovedTags.contains(tag) {
                        commonlyRemovedTags.append(tag)
                    }
                }
                
                // Add to prompt
                if !commonlyRemovedTags.isEmpty {
                    enhancedSections.append("- User frequently removes these tags: \(commonlyRemovedTags.joined(separator: ", "))")
                }
            }
        } catch {
            print("⚠️ Error fetching tag patterns: \(error.localizedDescription)")
        }
        
        // Find relevant examples for context
        let relevantExamples = findRelevantCorrectionExamples(for: fingerprint)
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
    
    // Build folder correction patterns based on learning data
    private func buildFolderCorrectionPatterns() -> [String] {
        var patterns = [String]()
        var folderTransitions = [String: [String]]()
        
        // Analyze all folder transitions
        for example in learningExamples {
            let aiFolder = example.aiSuggestion.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let userFolder = example.userSelection.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Skip if no change
            if aiFolder.lowercased() == userFolder.lowercased() {
                continue
            }
            
            // Add to transitions dictionary
            if !folderTransitions.keys.contains(aiFolder) {
                folderTransitions[aiFolder] = [userFolder]
            } else {
                folderTransitions[aiFolder]?.append(userFolder)
            }
        }
        
        // Find common transitions (where user consistently changes a folder name)
        for (fromFolder, toFolders) in folderTransitions {
            let counts = NSCountedSet(array: toFolders)
            if let mostCommon = counts.max(by: { counts.count(for: $0) < counts.count(for: $1) }) as? String {
                let count = counts.count(for: mostCommon)
                if count >= 2 {
                    if fromFolder.isEmpty {
                        patterns.append("When documents aren't assigned a folder, user prefers '\(mostCommon)' (\(count) times)")
                    } else {
                        patterns.append("When AI suggests '\(fromFolder)', user prefers '\(mostCommon)' (\(count) times)")
                    }
                }
            }
        }
        
        return patterns
    }
    
    // Build tag correction patterns
    private func buildTagCorrectionPatterns() -> [String] {
        var patterns = [String]()
        
        // Count how often each tag is added or removed
        var tagsAdded = [String: Int]()
        var tagsRemoved = [String: Int]()
        
        for example in learningExamples {
            let aiTags = Set(example.aiSuggestion.suggestedTags.map { $0.lowercased() })
            let userTags = Set(example.userSelection.suggestedTags.map { $0.lowercased() })
            
            // Added tags
            for tag in userTags.subtracting(aiTags) {
                tagsAdded[tag, default: 0] += 1
            }
            
            // Removed tags
            for tag in aiTags.subtracting(userTags) {
                tagsRemoved[tag, default: 0] += 1
            }
        }
        
        // Find frequently added tags
        let frequentlyAdded = tagsAdded.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(5)
        
        if !frequentlyAdded.isEmpty {
            let tagsList = frequentlyAdded.map { "\($0.key) (\($0.value) times)" }.joined(separator: ", ")
            patterns.append("User frequently adds these tags: \(tagsList)")
        }
        
        // Find frequently removed tags
        let frequentlyRemoved = tagsRemoved.filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(5)
        
        if !frequentlyRemoved.isEmpty {
            let tagsList = frequentlyRemoved.map { "\($0.key) (\($0.value) times)" }.joined(separator: ", ")
            patterns.append("User frequently removes these tags: \(tagsList)")
        }
        
        // Analyze topic-specific tags
        let commonTopics = analyzeTags(by: "topic")
        if !commonTopics.isEmpty {
            patterns.append("For topic-related tags, user prefers: \(commonTopics.joined(separator: ", "))")
        }
        
        // Analyze document-type tags
        let documentTypes = analyzeTags(by: "document type")
        if !documentTypes.isEmpty {
            patterns.append("For document type tags, user prefers: \(documentTypes.joined(separator: ", "))")
        }
        
        return patterns
    }
    
    // Helper to analyze tags by category
    private func analyzeTags(by category: String) -> [String] {
        // This would ideally use NLP to categorize tags, but we'll use a simplified approach
        // In a real implementation, you might use a more sophisticated categorization
        
        // For now, return common tags the user has added more than once
        let addedTags = learningExamples.flatMap { example in
            let aiTags = Set(example.aiSuggestion.suggestedTags.map { $0.lowercased() })
            let userTags = Set(example.userSelection.suggestedTags.map { $0.lowercased() })
            return Array(userTags.subtracting(aiTags))
        }
        
        let counts = NSCountedSet(array: addedTags)
        return counts.compactMap { tag in
            if counts.count(for: tag) >= 2, let tagStr = tag as? String {
                return tagStr
            }
            return nil
        }
    }
    
    // Build title correction patterns
    private func buildTitleCorrectionPatterns() -> [String] {
        var patterns = [String]()
        var titleChanges = [String]()
        
        for example in learningExamples {
            let aiTitle = example.aiSuggestion.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let userTitle = example.userSelection.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if aiTitle.lowercased() != userTitle.lowercased() {
                titleChanges.append("Changed '\(aiTitle)' to '\(userTitle)'")
            }
        }
        
        // Look for capitalization patterns
        let uppercaseChanges = titleChanges.filter { $0.contains(" to '") && $0.split(separator: " to '")[1].first?.isUppercase == true }
        let lowercaseChanges = titleChanges.filter { $0.contains(" to '") && $0.split(separator: " to '")[1].first?.isLowercase == true }
        
        if uppercaseChanges.count > lowercaseChanges.count && uppercaseChanges.count >= 2 {
            patterns.append("User prefers titles that start with uppercase letters")
        } else if lowercaseChanges.count > uppercaseChanges.count && lowercaseChanges.count >= 2 {
            patterns.append("User prefers titles that start with lowercase letters")
        }
        
        // Look for length patterns
        let shorterChanges = titleChanges.filter {
            let parts = $0.split(separator: " to '")
            guard parts.count == 2 else { return false }
            let before = parts[0].dropFirst(9) // Drop "Changed '"
            let after = parts[1].dropLast(1)   // Drop trailing "'"
            return after.count < before.count
        }
        
        if shorterChanges.count >= 2 && Float(shorterChanges.count) / Float(titleChanges.count) > 0.5 {
            patterns.append("User prefers shorter, more concise titles")
        }
        
        return patterns
    }
    
    // Find examples that might be relevant to current document
    private func findRelevantCorrectionExamples(for fingerprint: String) -> [ClassificationPair] {
        // Start with recent examples (showing user's latest preferences)
        let recentExamples = learningExamples
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)
        
        // Find patterns where AI was consistently corrected
        let consistentCorrections = findConsistentCorrectionPatterns()
        
        // Combine recent and consistent examples
        var relevantExamples = Array(recentExamples)
        relevantExamples.append(contentsOf: consistentCorrections)
        
        return Array(relevantExamples.prefix(10))  // Limit to control prompt size
    }
    
    // Identify patterns where user consistently makes the same type of correction
    private func findConsistentCorrectionPatterns() -> [ClassificationPair] {
        var patterns: [ClassificationPair] = []
        
        // Example: Find cases where user consistently recategorizes a specific folder
        let folderRenames = Dictionary(grouping: learningExamples) { example in
            // Group by cases where AI suggested one folder but user chose another
            let aiFolder = example.aiSuggestion.suggestedFolderName ?? "Unknown"
            let userFolder = example.userSelection.suggestedFolderName ?? "Unknown"
            
            if aiFolder != userFolder {
                return "\(aiFolder) -> \(userFolder)"
            }
            return "unchanged"
        }
        
        // Add most common folder corrections
        for (_, examples) in folderRenames.filter({ $0.key != "unchanged" }) {
            if examples.count >= 2 {  // Threshold for "consistent" pattern
                patterns.append(contentsOf: examples.prefix(2))
            }
        }
        
        // Similarly for tags (find tags that are consistently added or removed)
        let tagCorrections = learningExamples.filter {
            Set($0.aiSuggestion.suggestedTags) != Set($0.userSelection.suggestedTags)
        }
        
        // Group by added tags
        let tagAdditions = Dictionary(grouping: tagCorrections) { example in
            let aiTags = Set(example.aiSuggestion.suggestedTags)
            let userTags = Set(example.userSelection.suggestedTags)
            let addedTags = userTags.subtracting(aiTags)
            return Array(addedTags).sorted().joined(separator: ", ")
        }
        
        // Add examples where the same tags are consistently added
        for (addedTagsKey, examples) in tagAdditions {
            if !addedTagsKey.isEmpty && examples.count >= 2 {
                patterns.append(contentsOf: examples.prefix(2))
            }
        }
        
        return patterns
    }
    
    // Create a fingerprint/signature for the document to help identify patterns
    private func createDocumentFingerprint(_ text: String) -> String {
        // Simple implementation: use first N words + key phrases
        let words = text.components(separatedBy: " ").prefix(30).joined(separator: " ")
        
        // Extract potential keywords (simplified)
        let potentialKeywords = text.components(separatedBy: " ")
            .filter { $0.count > 5 }  // Longer words might be keywords
            .prefix(20)
            .joined(separator: " ")
        
        return "\(words) || \(potentialKeywords)"
    }
    
    // Persistence
    private func saveLearningExamples() {
        let context = PersistenceController.shared.viewContext
        
        // First delete existing records to avoid duplicates
        let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
        if let existingExamples = try? context.fetch(fetchRequest) {
            for example in existingExamples {
                context.delete(example)
            }
        }
        
        // Add new examples to Core Data
        for example in learningExamples {
            let newExample = LearningExample(context: context)
            newExample.id = UUID()
            newExample.documentFingerprint = example.documentFingerprint
            newExample.timestamp = example.timestamp
            
            // Convert suggestions to data
            if let aiData = try? JSONEncoder().encode(example.aiSuggestion) {
                newExample.aiSuggestionData = aiData
            }
            
            if let userSelectionData = try? JSONEncoder().encode(example.userSelection) {
                newExample.userSelectionData = userSelectionData
            }
        }
        
        // Save context
        try? context.save()
        print("✅ Saved \(learningExamples.count) examples to Core Data")
    }
    
    func loadLearningExamples() {
        // IMPORTANT: Clear the existing array first to prevent duplicates
        learningExamples.removeAll()
        
        let context = PersistenceController.shared.viewContext
        let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
        
        // Create a fingerprint tracker to avoid duplicates even during loading
        var seenFingerprints = Set<String>()
        
        do {
            let fetchedExamples = try context.fetch(fetchRequest)
            print("✅ Loaded \(fetchedExamples.count) learning examples from Core Data")
            
            // Convert Core Data objects to our model objects
            for example in fetchedExamples {
                if let fingerprint = example.documentFingerprint,
                   let timestamp = example.timestamp,
                   let aiData = example.aiSuggestionData,
                   let userSelectionData = example.userSelectionData {
                    
                    // Skip if we've already seen this fingerprint in this load session
                    if seenFingerprints.contains(fingerprint) {
                        print("⚠️ Skipped duplicate example for fingerprint: \(fingerprint)")
                        continue
                    }
                    
                    seenFingerprints.insert(fingerprint)
                    
                    do {
                        let aiSuggestion = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: aiData)
                        let userSelection = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: userSelectionData)
                        
                        let pair = ClassificationPair(
                            documentFingerprint: fingerprint,
                            aiSuggestion: aiSuggestion,
                            userSelection: userSelection,
                            timestamp: timestamp
                        )
                        
                        learningExamples.append(pair)
                        
                    } catch {
                        print("❌ Error decoding learning example: \(error)")
                    }
                }
            }
            
            print("🔍 Core Data contains \(fetchedExamples.count) learning examples")
            print("🧠 Loaded \(learningExamples.count) unique examples to memory")
            
        } catch {
            print("❌ Error loading learning examples: \(error)")
        }
    }
    
    // For debugging or settings screen
    func getLearningStatistics() -> (totalExamples: Int, folderCorrections: Int, tagCorrections: Int) {
        // Count directly from Core Data to ensure accuracy
        let context = PersistenceController.shared.viewContext
        let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
        
        do {
            let coreDataExamples = try context.fetch(fetchRequest)
            print("🔍 Core Data contains \(coreDataExamples.count) learning examples")
            
            // Count from Core Data objects directly
            var folderCount = 0
            var tagCount = 0
            
            for example in coreDataExamples {
                if let aiData = example.aiSuggestionData,
                   let userData = example.userSelectionData {
                    
                    do {
                        let aiSuggestion = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: aiData)
                        let userSelection = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: userData)
                        
                        // Check folder corrections
                        let aiFolder = aiSuggestion.suggestedFolderName?.lowercased() ?? ""
                        let userFolder = userSelection.suggestedFolderName?.lowercased() ?? ""
                        if aiFolder != userFolder {
                            folderCount += 1
                        }
                        
                        // Check tag corrections (using sets to ignore order)
                        let aiTags = Set(aiSuggestion.suggestedTags.map { $0.lowercased() })
                        let userTags = Set(userSelection.suggestedTags.map { $0.lowercased() })
                        if aiTags != userTags {
                            tagCount += 1
                        }
                        
                    } catch {
                        print("❌ Error decoding example during stats calculation: \(error)")
                    }
                }
            }
            
            return (coreDataExamples.count, folderCount, tagCount)
            
        } catch {
            print("❌ Error calculating learning statistics: \(error)")
            return (0, 0, 0)
        }
    }
    
    // Method to clear all learning data
    func clearLearningData() {
        // First clear history
        clearDeletedItemsHistory()
        
        // Clear the in-memory examples
        learningExamples.removeAll()
        
        // Clear learning examples from Core Data
        let context = PersistenceController.shared.viewContext
        let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
        
        do {
            let examples = try context.fetch(fetchRequest)
            print("🧹 Deleting \(examples.count) learning examples from Core Data")
            
            for example in examples {
                context.delete(example)
            }
            
            // Save context
            try context.save()
            print("✅ Successfully cleared learning examples")
        } catch {
            print("❌ Error clearing learning examples: \(error.localizedDescription)")
        }
        
        // Clear KeywordPatterns from Core Data
        clearKeywordPatterns()
        
        // Clear statistics
        UserDefaults.standard.removeObject(forKey: StatKeys.totalChanges)
        UserDefaults.standard.removeObject(forKey: StatKeys.titleChanges)
        UserDefaults.standard.removeObject(forKey: StatKeys.folderChanges)
        UserDefaults.standard.removeObject(forKey: StatKeys.tagChanges)
        
        print("🧹 Cleared all learning statistics")
    }
    
    // Helper method to clear KeywordPatterns
    private func clearKeywordPatterns() {
        let context = PersistenceController.shared.viewContext
        
        // First verify KeywordPattern entity exists
        guard NSEntityDescription.entity(forEntityName: "KeywordPattern", in: context) != nil else {
            print("⚠️ KeywordPattern entity not available - skipping pattern deletion")
            return
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
        
        do {
            let patterns = try context.fetch(fetchRequest)
            print("🧹 Deleting \(patterns.count) keyword patterns from Core Data")
            
            for pattern in patterns {
                context.delete(pattern)
            }
            
            // Save context
            try context.save()
            print("✅ Successfully cleared keyword patterns")
        } catch {
            print("❌ Error clearing keyword patterns: \(error.localizedDescription)")
        }
    }
    
    // Add this method to help debug Core Data storage
    func debugDataStore() {
        // Check Core Data
        let context = PersistenceController.shared.viewContext
        let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
        
        do {
            let coreDataCount = try context.count(for: fetchRequest)
            print("🔍 DEBUG: Core Data contains \(coreDataCount) learning examples")
            print("🔍 DEBUG: In-memory array contains \(learningExamples.count) examples")
            
            // Check if UserDefaults still has old data
            if UserDefaults.standard.data(forKey: "AdaptiveLearningExamples") != nil {
                print("⚠️ WARNING: Found old UserDefaults data that should be migrated")
            }
        } catch {
            print("❌ ERROR checking Core Data: \(error.localizedDescription)")
        }
    }
    
    // Add this method to migrate old UserDefaults data to Core Data
    private func migrateFromUserDefaultsIfNeeded() {
        // Check if there's old data in UserDefaults
        if let migrationData = UserDefaults.standard.data(forKey: "AdaptiveLearningExamples"), 
           !migrationData.isEmpty {
            print("🔄 Found old learning data in UserDefaults - migrating to Core Data")
            
            do {
                // Decode the data directly
                let oldExamples = try JSONDecoder().decode([ClassificationPair].self, from: migrationData)
                
                // Add to current examples if not empty
                if !oldExamples.isEmpty {
                    print("🔄 Migrating \(oldExamples.count) examples from UserDefaults to Core Data")
                    learningExamples.append(contentsOf: oldExamples)
                    
                    // Save to Core Data
                    saveLearningExamples()
                    
                    // Remove from UserDefaults after successful migration
                    UserDefaults.standard.removeObject(forKey: "AdaptiveLearningExamples")
                    print("✅ Migration complete, removed old UserDefaults data")
                }
            } catch {
                print("❌ Error migrating from UserDefaults: \(error.localizedDescription)")
            }
        }
    }
    
    // Add this method for testing persistence
    func forceSaveAndVerify() {
        // Original count
        let originalCount = learningExamples.count
        
        // Save to Core Data
        saveLearningExamples()
        
        // Clear memory array
        learningExamples = []
        
        // Reload from Core Data
        loadLearningExamples()
        
        // Verify
        let reloadedCount = learningExamples.count
        print("💾 Persistence test: Original: \(originalCount), Reloaded: \(reloadedCount)")
        if originalCount == reloadedCount {
            print("✅ Core Data persistence is working correctly")
        } else {
            print("⚠️ Core Data persistence issue - counts don't match")
        }
    }
    
    // Add this method for development testing
    func addSampleLearningDataForDevelopment() {
        // Only add if there's no existing data
        if learningExamples.isEmpty {
            print("🔧 Adding sample learning data for development")
            
            // Create sample DocumentSuggestions
            let aiSuggestion1 = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: "Invoice XYZ",
                suggestedFolderName: "Receipts",
                suggestedTags: ["invoice", "payment", "business"],
                confidence: 0.85
            )
            
            let userSelection1 = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: "Invoice XYZ",
                suggestedFolderName: "Finances",
                suggestedTags: ["invoice", "payment", "taxes"],
                confidence: 1.0
            )
            
            // Add sample data
            let example1 = ClassificationPair(
                documentFingerprint: "sample_invoice_fingerprint",
                aiSuggestion: aiSuggestion1,
                userSelection: userSelection1,
                timestamp: Date()
            )
            
            learningExamples.append(example1)
            
            // Second example
            let aiSuggestion2 = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: "Medical Report",
                suggestedFolderName: "Documents",
                suggestedTags: ["health", "report", "doctor"],
                confidence: 0.75
            )
            
            let userSelection2 = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: "Medical Report",
                suggestedFolderName: "Medical",
                suggestedTags: ["health", "report", "doctor", "records"],
                confidence: 1.0
            )
            
            let example2 = ClassificationPair(
                documentFingerprint: "sample_medical_fingerprint",
                aiSuggestion: aiSuggestion2,
                userSelection: userSelection2,
                timestamp: Date().addingTimeInterval(-86400) // 1 day ago
            )
            
            learningExamples.append(example2)
            
            // Save to storage
            saveLearningExamples()
            print("✅ Added \(learningExamples.count) sample learning examples for development")
        }
    }
    
    // Add this method to verify and fix Core Data storage issues
    func verifyAndFixCoreDataStorage() {
        print("🔍 Verifying learning data storage...")
        
        // Get a fresh context for verification
        let context = PersistenceController.shared.viewContext
        let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
        
        do {
            let coreDataExamples = try context.fetch(fetchRequest)
            print("🔍 Found \(coreDataExamples.count) examples in Core Data")
            
            // Check for duplicates in Core Data and clean them if found
            var seenFingerprints = Set<String>()
            var exampleToDelete = [LearningExample]()
            var hasChanges = false
            
            for example in coreDataExamples {
                if let fingerprint = example.documentFingerprint {
                    if seenFingerprints.contains(fingerprint) {
                        // This is a duplicate, mark for deletion
                        exampleToDelete.append(example)
                        hasChanges = true
                    } else {
                        // First time seeing this fingerprint
                        seenFingerprints.insert(fingerprint)
                    }
                }
            }
            
            // Delete duplicates if found
            if hasChanges && !exampleToDelete.isEmpty {
                print("🧹 Removing \(exampleToDelete.count) duplicate examples from Core Data")
                for example in exampleToDelete {
                    context.delete(example)
                }
                
                // Save changes
                try context.save()
                
                // Since we modified Core Data, reload our memory cache
                learningExamples.removeAll()
                loadLearningExamples()
            } else if learningExamples.count != seenFingerprints.count {
                // If the in-memory count doesn't match, reload
                print("⚠️ Mismatch between memory (\(learningExamples.count)) and Core Data (\(seenFingerprints.count) unique examples)")
                learningExamples.removeAll()
                loadLearningExamples()
            }
            
            // Now repair any broken entries
            repairBrokenEntities()
            
        } catch {
            print("❌ Error verifying Core Data storage: \(error.localizedDescription)")
        }
    }
    
    // Method to repair broken entities in Core Data
    private func repairBrokenEntities() {
        print("🔧 Checking for broken learning examples in Core Data...")
        
        let context = PersistenceController.shared.viewContext
        let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
        
        do {
            let coreDataExamples = try context.fetch(fetchRequest)
            var brokenExamplesCount = 0
            
            for example in coreDataExamples {
                if let aiData = example.aiSuggestionData,
                   let userSelectionData = example.userSelectionData {
                    
                    do {
                        // Try to decode
                        _ = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: aiData)
                        _ = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: userSelectionData)
                        // If we get here, decoding succeeded
                    } catch {
                        // Failed to decode, mark as broken
                        brokenExamplesCount += 1
                        // Either fix or delete broken example
                        context.delete(example)
                        print("🧹 Deleted broken learning example: \(error.localizedDescription)")
                    }
                }
            }
            
            if brokenExamplesCount > 0 {
                print("🧹 Removed \(brokenExamplesCount) broken learning examples from Core Data")
                try context.save()
                
                // Reload learning examples
                learningExamples.removeAll()
                loadLearningExamples()
            } else {
                print("✅ No broken learning examples found in Core Data")
            }
            
        } catch {
            print("❌ Error repairing Core Data: \(error.localizedDescription)")
        }
    }
    
    // Constants for UserDefaults keys
    private struct UserDefaultsKeys {
        static let deletedFolderHistory = "deletedFolderHistory"
        static let deletedTagHistory = "deletedTagHistory"
        static let deletionHistoryTimestamps = "deletionHistoryTimestamps"
    }
    
    // Method to identify tags and folders that were consistently removed/deleted
    func getDeletedFoldersAndTags() -> (folders: [String], tags: [String]) {
        // Initialize empty sets for tracking deleted items
        var potentiallyDeletedFolders = Set<String>()
        var potentiallyDeletedTags = Set<String>()
        
        // Track occurrences of deleted items
        var folderDeletionCount: [String: Int] = [:]
        var tagDeletionCount: [String: Int] = [:]
        
        // Also track items that are still in use (not deleted)
        var activelyUsedFolders = Set<String>()
        var activelyUsedTags = Set<String>()
        
        // Analyze learning examples to find consistently deleted folders and tags
        for example in learningExamples {
            // Check for folder changes
            if let aiFolder = example.aiSuggestion.suggestedFolderName, 
               aiFolder.lowercased() != (example.userSelection.suggestedFolderName ?? "").lowercased() {
                // AI suggested a folder that user changed
                potentiallyDeletedFolders.insert(aiFolder.lowercased())
                folderDeletionCount[aiFolder.lowercased(), default: 0] += 1
            }
            
            // If user selected a folder, mark it as actively used
            if let userFolder = example.userSelection.suggestedFolderName, !userFolder.isEmpty {
                activelyUsedFolders.insert(userFolder.lowercased())
            }
            
            // Check for tag removals
            let aiTags = Set(example.aiSuggestion.suggestedTags.map { $0.lowercased() })
            let userTags = Set(example.userSelection.suggestedTags.map { $0.lowercased() })
            
            // Find tags that were removed
            let removedTags = aiTags.subtracting(userTags)
            for tag in removedTags {
                potentiallyDeletedTags.insert(tag)
                tagDeletionCount[tag, default: 0] += 1
            }
            
            // Mark user-selected tags as actively used
            for tag in userTags {
                activelyUsedTags.insert(tag)
            }
        }
        
        // Filter out items that are still actively used
        let deletedFolders = potentiallyDeletedFolders
            .filter { folder in 
                let isDeleted = !activelyUsedFolders.contains(folder) && 
                              (folderDeletionCount[folder] ?? 0) >= 2 // Only include if deleted multiple times
                
                // Debug output for each potentially deleted folder
                if isDeleted {
                    print("📊 Folder '\(folder)' considered deleted: removed \(folderDeletionCount[folder] ?? 0) times, not actively used")
                } else if potentiallyDeletedFolders.contains(folder) {
                    if activelyUsedFolders.contains(folder) {
                        print("📊 Folder '\(folder)' NOT considered deleted: still actively used")
                    } else if (folderDeletionCount[folder] ?? 0) < 2 {
                        print("📊 Folder '\(folder)' NOT considered deleted: only removed \(folderDeletionCount[folder] ?? 0) time(s)")
                    }
                }
                
                return isDeleted
            }
        
        let deletedTags = potentiallyDeletedTags
            .filter { tag in 
                let isDeleted = !activelyUsedTags.contains(tag) && 
                              (tagDeletionCount[tag] ?? 0) >= 2 // Only include if deleted multiple times
                
                // Debug output for each potentially deleted tag
                if isDeleted {
                    print("📊 Tag '\(tag)' considered deleted: removed \(tagDeletionCount[tag] ?? 0) times, not actively used")
                } else if potentiallyDeletedTags.contains(tag) {
                    if activelyUsedTags.contains(tag) {
                        print("📊 Tag '\(tag)' NOT considered deleted: still actively used")
                    } else if (tagDeletionCount[tag] ?? 0) < 2 {
                        print("📊 Tag '\(tag)' NOT considered deleted: only removed \(tagDeletionCount[tag] ?? 0) time(s)")
                    }
                }
                
                return isDeleted
            }
        
        print("🔍 Found \(deletedFolders.count) consistently deleted folders")
        print("🔍 Found \(deletedTags.count) consistently deleted tags")
        
        // Update the history of deleted folders and tags
        updateDeletedItemsHistory(folders: Array(deletedFolders), tags: Array(deletedTags))
        
        return (Array(deletedFolders), Array(deletedTags))
    }
    
    // Update and maintain history of deleted items
    private func updateDeletedItemsHistory(folders: [String], tags: [String]) {
        let defaults = UserDefaults.standard
        let timestamp = Date()
        
        // Get existing history
        var folderHistory = defaults.stringArray(forKey: UserDefaultsKeys.deletedFolderHistory) ?? []
        var tagHistory = defaults.stringArray(forKey: UserDefaultsKeys.deletedTagHistory) ?? []
        var timestampHistory = defaults.array(forKey: UserDefaultsKeys.deletionHistoryTimestamps) as? [TimeInterval] ?? []
        
        // Update history if there are changes
        if !folders.isEmpty || !tags.isEmpty {
            // Add new entries
            folderHistory.append(contentsOf: folders)
            tagHistory.append(contentsOf: tags)
            
            // Add timestamps for each new entry
            let newTimestamps = Array(repeating: timestamp.timeIntervalSince1970, count: max(folders.count, tags.count))
            timestampHistory.append(contentsOf: newTimestamps)
            
            // Remove duplicates but keep most recent entries
            var uniqueFolders = Set<String>()
            var uniqueTags = Set<String>()
            var newFolderHistory: [String] = []
            var newTagHistory: [String] = []
            var newTimestampHistory: [TimeInterval] = []
            
            // Process in reverse order (newest first)
            for i in (0..<max(folderHistory.count, tagHistory.count)).reversed() {
                // Process folders
                if i < folderHistory.count {
                    let folder = folderHistory[i]
                    if !uniqueFolders.contains(folder) {
                        uniqueFolders.insert(folder)
                        newFolderHistory.insert(folder, at: 0)
                        
                        // Add timestamp if needed
                        if i < timestampHistory.count {
                            newTimestampHistory.insert(timestampHistory[i], at: 0)
                        } else {
                            // Use current time for missing timestamps
                            newTimestampHistory.insert(timestamp.timeIntervalSince1970, at: 0)
                        }
                    }
                }
                
                // Process tags
                if i < tagHistory.count {
                    let tag = tagHistory[i]
                    if !uniqueTags.contains(tag) {
                        uniqueTags.insert(tag)
                        newTagHistory.insert(tag, at: 0)
                        
                        // Timestamps already added for folders
                        if i >= folderHistory.count && i < timestampHistory.count {
                            newTimestampHistory.insert(timestampHistory[i], at: 0)
                        }
                    }
                }
            }
            
            // Limit history size
            let maxHistorySize = 100
            if newFolderHistory.count > maxHistorySize {
                newFolderHistory = Array(newFolderHistory.prefix(maxHistorySize))
            }
            if newTagHistory.count > maxHistorySize {
                newTagHistory = Array(newTagHistory.prefix(maxHistorySize))
            }
            if newTimestampHistory.count > maxHistorySize {
                newTimestampHistory = Array(newTimestampHistory.prefix(maxHistorySize))
            }
            
            // Save updated history
            defaults.set(newFolderHistory, forKey: UserDefaultsKeys.deletedFolderHistory)
            defaults.set(newTagHistory, forKey: UserDefaultsKeys.deletedTagHistory)
            defaults.set(newTimestampHistory, forKey: UserDefaultsKeys.deletionHistoryTimestamps)
            
            print("📝 Updated deletion history: \(newFolderHistory.count) folders, \(newTagHistory.count) tags")
        }
    }
    
    // Retrieve history of deleted items
    func getDeletedItemsHistory() -> [(type: String, name: String, date: Date)] {
        let defaults = UserDefaults.standard
        
        let folderHistory = defaults.stringArray(forKey: UserDefaultsKeys.deletedFolderHistory) ?? []
        let tagHistory = defaults.stringArray(forKey: UserDefaultsKeys.deletedTagHistory) ?? []
        let timestampHistory = defaults.array(forKey: UserDefaultsKeys.deletionHistoryTimestamps) as? [TimeInterval] ?? []
        
        var history: [(type: String, name: String, date: Date)] = []
        
        // Process folders
        for (index, folder) in folderHistory.enumerated() {
            let timestamp = index < timestampHistory.count ? 
                            Date(timeIntervalSince1970: timestampHistory[index]) :
                            Date()
            history.append((type: "Folder", name: folder, date: timestamp))
        }
        
        // Process tags
        for (index, tag) in tagHistory.enumerated() {
            let timestamp = index < timestampHistory.count ? 
                            Date(timeIntervalSince1970: timestampHistory[index]) :
                            Date()
            history.append((type: "Tag", name: tag, date: timestamp))
        }
        
        // Sort by date (newest first)
        history.sort { $0.date > $1.date }
        
        return history
    }
    
    // Clear deletion history
    func clearDeletedItemsHistory() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.deletedFolderHistory)
        defaults.removeObject(forKey: UserDefaultsKeys.deletedTagHistory)
        defaults.removeObject(forKey: UserDefaultsKeys.deletionHistoryTimestamps)
        print("🧹 Cleared deleted items history")
    }
    
    // Get folder-tag pattern statistics for debugging
    func getFolderTagPatternStatistics() -> [String: [(tag: String, frequency: Double)]] {
        // Initialize result
        var folderTagPatterns: [String: [(tag: String, frequency: Double)]] = [:]
        
        // Get context
        let context = PersistenceController.shared.viewContext
        
        // Fetch all folders
        let folderFetchRequest = NSFetchRequest<Folder>(entityName: "Folder")
        
        do {
            let folders = try context.fetch(folderFetchRequest)
            
            for folder in folders {
                guard let folderName = folder.name, let folderId = folder.id?.uuidString else { continue }
                
                // Fetch documents in this folder
                let documentFetchRequest = NSFetchRequest<Document>(entityName: "Document")
                documentFetchRequest.predicate = NSPredicate(format: "folderId == %@", folderId)
                
                let documents = try context.fetch(documentFetchRequest)
                let documentCount = documents.count
                
                if documentCount > 0 {
                    // Count tag occurrences
                    var tagCounts: [String: Int] = [:]
                    
                    for document in documents {
                        if let tags = document.tags as? Set<Tag> {
                            for tag in tags {
                                if let tagName = tag.name {
                                    tagCounts[tagName, default: 0] += 1
                                }
                            }
                        }
                    }
                    
                    // Convert to frequencies and sort
                    var tagFrequencies: [(tag: String, frequency: Double)] = []
                    
                    for (tag, count) in tagCounts {
                        let frequency = Double(count) / Double(documentCount)
                        // Include all tags for comprehensive statistics
                        tagFrequencies.append((tag: tag, frequency: frequency))
                    }
                    
                    // Sort by frequency
                    tagFrequencies.sort { $0.frequency > $1.frequency }
                    
                    // Add to results
                    folderTagPatterns[folderName] = tagFrequencies
                }
            }
            
            // Print summary
            print("📊 FOLDER-TAG PATTERN STATISTICS:")
            
            for (folder, patterns) in folderTagPatterns {
                // Count documents in this folder
                let docFetchRequest = NSFetchRequest<Document>(entityName: "Document")
                if let folderObj = folders.first(where: { $0.name == folder }),
                   let folderId = folderObj.id?.uuidString {
                    docFetchRequest.predicate = NSPredicate(format: "folderId == %@", folderId)
                    let count = try context.count(for: docFetchRequest)
                    
                    print("📁 \(folder) (\(count) documents):")
                    
                    // Only print top tags
                    let topTags = patterns.prefix(5)
                    for (index, tagInfo) in topTags.enumerated() {
                        let percentValue = Int(tagInfo.frequency * 100)
                        print("   \(index + 1). \(tagInfo.tag): \(percentValue)% of documents")
                    }
                }
            }
            
        } catch {
            print("❌ Error fetching folder-tag statistics: \(error.localizedDescription)")
        }
        
        return folderTagPatterns
    }
    
    // Debug methods for viewing learning patterns in the UI
    
    // Get learned folder patterns for debugging UI
    func debugGetLearnedFolderPatterns() -> [(original: String, updated: String, count: Int)] {
        let context = PersistenceController.shared.viewContext
        var patterns: [(original: String, updated: String, count: Int)] = []
        
        // First check if the KeywordPattern entity exists
        guard NSEntityDescription.entity(forEntityName: "KeywordPattern", in: context) != nil else {
            print("⚠️ KeywordPattern entity not available - skipping folder pattern retrieval")
            return []
        }
        
        do {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@", "folder")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            
            let results = try context.fetch(fetchRequest)
            
            for pattern in results {
                if let aiValue = pattern.value(forKey: "aiValue") as? String, 
                   let userValue = pattern.value(forKey: "userValue") as? String,
                   let occurrences = pattern.value(forKey: "occurrences") as? Int32 {
                    patterns.append((
                        original: aiValue,
                        updated: userValue,
                        count: Int(occurrences)
                    ))
                }
            }
        } catch {
            print("❌ Error fetching folder patterns: \(error.localizedDescription)")
        }
        
        return patterns
    }
    
    // Get learned tag patterns for debugging UI
    func debugGetLearnedTagPatterns() -> [(action: String, tag: String, count: Int)] {
        let context = PersistenceController.shared.viewContext
        var patterns: [(action: String, tag: String, count: Int)] = []
        
        // First check if the KeywordPattern entity exists
        guard NSEntityDescription.entity(forEntityName: "KeywordPattern", in: context) != nil else {
            print("⚠️ KeywordPattern entity not available - skipping tag pattern retrieval")
            return []
        }
        
        do {
            // Get added tags
            let addedTagsRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            addedTagsRequest.predicate = NSPredicate(format: "fieldType == %@", "tag_added")
            addedTagsRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            
            let addedResults = try context.fetch(addedTagsRequest)
            
            for pattern in addedResults {
                if let tag = pattern.value(forKey: "userValue") as? String,
                   let occurrences = pattern.value(forKey: "occurrences") as? Int32 {
                    patterns.append((
                        action: "Added",
                        tag: tag,
                        count: Int(occurrences)
                    ))
                }
            }
            
            // Get removed tags
            let removedTagsRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            removedTagsRequest.predicate = NSPredicate(format: "fieldType == %@", "tag_removed")
            removedTagsRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            
            let removedResults = try context.fetch(removedTagsRequest)
            
            for pattern in removedResults {
                if let tag = pattern.value(forKey: "aiValue") as? String,
                   let occurrences = pattern.value(forKey: "occurrences") as? Int32 {
                    patterns.append((
                        action: "Removed",
                        tag: tag,
                        count: Int(occurrences)
                    ))
                }
            }
        } catch {
            print("❌ Error fetching tag patterns: \(error.localizedDescription)")
        }
        
        return patterns
    }
    
    // Get learned title patterns for debugging UI
    func debugGetLearnedTitlePatterns() -> [(original: String, updated: String)] {
        var patterns: [(original: String, updated: String)] = []
        
        // For now we'll just return a sample of title changes from learning examples
        for example in learningExamples.prefix(10) {
            if example.aiSuggestion.suggestedTitle != example.userSelection.suggestedTitle {
                patterns.append((
                    original: example.aiSuggestion.suggestedTitle,
                    updated: example.userSelection.suggestedTitle
                ))
            }
        }
        
        return patterns
    }
    
    // Get recent examples for debugging UI
    func debugGetRecentExamples() -> [ClassificationPair] {
        // Return the 5 most recent examples
        return Array(learningExamples.prefix(5))
    }
}

// MARK: - Codable Extensions

// Extension to make DocumentClassifierService.DocumentSuggestions Codable for storage
extension DocumentClassifierService.DocumentSuggestions: Codable {
    enum CodingKeys: String, CodingKey {
        case suggestedTitle, suggestedFolderName, suggestedTags, confidence
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(suggestedTitle, forKey: .suggestedTitle)
        try container.encode(suggestedFolderName, forKey: .suggestedFolderName)
        try container.encode(suggestedTags, forKey: .suggestedTags)
        try container.encode(confidence, forKey: .confidence)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let suggestedTitle = try container.decode(String.self, forKey: .suggestedTitle)
        
        // Handle optional suggestedFolderName with null value
        let suggestedFolderName: String?
        if try container.contains(.suggestedFolderName) && !(try container.decodeNil(forKey: .suggestedFolderName)) {
            suggestedFolderName = try container.decode(String.self, forKey: .suggestedFolderName)
        } else {
            suggestedFolderName = nil
        }
        
        let suggestedTags = try container.decode([String].self, forKey: .suggestedTags)
        let confidence = try container.decode(Double.self, forKey: .confidence)
        
        // Pass the values to the initializer
        self.init(
            suggestedTitle: suggestedTitle,
            suggestedFolderName: suggestedFolderName,
            suggestedTags: suggestedTags,
            confidence: confidence
        )
    }
}

// The TokenUsage extension doesn't seem applicable to this case,
// comment it out for now as it doesn't appear to be a member of DocumentClassifierService
// extension DocumentClassifierService.TokenUsage: Codable {} 

// MARK: - Learning Methods for Individual Changes

extension AdaptiveLearningClassifier {
    
    // Keys for tracking learning statistics in UserDefaults
    private struct StatKeys {
        static let totalChanges = "learning_stat_total_changes"
        static let titleChanges = "learning_stat_title_changes"
        static let folderChanges = "learning_stat_folder_changes"
        static let tagChanges = "learning_stat_tag_changes"
    }
    
    // Track when user changes the title from AI suggestion
    func learnFromTitleChange(original: String, updated: String) {
        print("🧠 Learning from title change: '\(original)' → '\(updated)'")
        
        // Check if this is a valid learning opportunity
        if original.isEmpty || updated.isEmpty || original == updated {
            print("⚠️ Not a valid title change to learn from")
            return
        }
        
        // Track title change count
        let currentCount = UserDefaults.standard.integer(forKey: StatKeys.titleChanges)
        UserDefaults.standard.set(currentCount + 1, forKey: StatKeys.titleChanges)
        
        // Future enhancement: Store title patterns in a dedicated table
    }
    
    // Track when user changes the folder from AI suggestion
    func learnFromFolderChange(original: String?, updated: String?) {
        print("🧠 Learning from folder change: '\(original ?? "none")' → '\(updated ?? "none")'")
        
        // Skip if both are nil or equal
        if original == updated {
            print("⚠️ Not a valid folder change to learn from")
            return
        }
        
        // Normalize values for comparison
        let normalizedOriginal = original?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let normalizedUpdated = updated?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        
        if normalizedOriginal == normalizedUpdated {
            print("⚠️ Not a valid folder change to learn from after normalization")
            return
        }
        
        // Track folder change count
        let currentCount = UserDefaults.standard.integer(forKey: StatKeys.folderChanges)
        UserDefaults.standard.set(currentCount + 1, forKey: StatKeys.folderChanges)
        
        // Future enhancement: Store folder mappings in a dedicated table
    }
    
    // Track when user adds or removes tags from AI suggestion
    func learnFromTagChanges(added: [String], removed: [String]) {
        // Skip if no changes
        if added.isEmpty && removed.isEmpty {
            print("⚠️ No tag changes to learn from")
            return
        }
        
        print("🧠 Learning from tag changes:")
        if !added.isEmpty {
            print("  - Added tags: \(added.joined(separator: ", "))")
        }
        if !removed.isEmpty {
            print("  - Removed tags: \(removed.joined(separator: ", "))")
        }
        
        // Track tag change count
        let currentCount = UserDefaults.standard.integer(forKey: StatKeys.tagChanges)
        UserDefaults.standard.set(currentCount + 1, forKey: StatKeys.tagChanges)
        
        // Future enhancement: Store tag preferences in a dedicated table
    }
    
    // Increment the overall learning statistics
    func incrementLearningStatistics() {
        print("📊 Incrementing adaptive learning statistics")
        
        // Increment total changes counter
        let currentTotal = UserDefaults.standard.integer(forKey: StatKeys.totalChanges)
        UserDefaults.standard.set(currentTotal + 1, forKey: StatKeys.totalChanges)
        
        // Log current stats
        let stats = getLearningStatistics()
        print("📊 Current learning statistics:")
        print("  - Total changes: \(stats.totalExamples)")
        print("  - Title changes: \(stats.folderCorrections)")
        print("  - Folder changes: \(stats.folderCorrections)")
        print("  - Tag changes: \(stats.tagCorrections)")
    }
}

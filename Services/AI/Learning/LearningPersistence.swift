import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

extension AI_Learning {
    /// Handles persistence of learning patterns and keyword associations
    class LearningPersistence {
        // Reference to persistence controller
        private let persistenceController: PersistenceController
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
        }
        
        // Save patterns to KeywordPattern entities
        func savePatterns(aiSuggestion: DocumentClassifierService.DocumentSuggestions, userSelection: DocumentClassifierService.DocumentSuggestions) {
            let context = persistenceController.viewContext
            
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
        
        // Get learning statistics from Core Data
        func getLearningStatistics() -> LearningStatistics {
            // Count directly from Core Data to ensure accuracy
            let context = persistenceController.viewContext
            let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
            
            do {
                let examples = try context.fetch(fetchRequest)
                
                // Count folder and tag corrections
                var folderCorrections = 0
                var tagCorrections = 0
                
                for example in examples {
                    // Skip examples without proper data
                    guard let aiData = example.aiSuggestionData,
                          let userData = example.userSelectionData else {
                        continue
                    }
                    
                    do {
                        // Decode AI suggestion
                        let aiSuggestion = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: aiData)
                        
                        // Decode user selection
                        let userSelection = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: userData)
                        
                        // Count folder corrections
                        if aiSuggestion.suggestedFolderName != userSelection.suggestedFolderName {
                            folderCorrections += 1
                        }
                        
                        // Count tag corrections
                        let aiTagSet = Set(aiSuggestion.suggestedTags)
                        let userTagSet = Set(userSelection.suggestedTags)
                        
                        if aiTagSet != userTagSet {
                            tagCorrections += 1
                        }
                    } catch {
                        // Skip examples with decoding errors
                        continue
                    }
                }
                
                return LearningStatistics(
                    totalExamples: examples.count,
                    folderCorrections: folderCorrections,
                    tagCorrections: tagCorrections
                )
            } catch {
                print("❌ Error calculating learning statistics: \(error)")
                return LearningStatistics(totalExamples: 0, folderCorrections: 0, tagCorrections: 0)
            }
        }
        
        // Get patterns for folder corrections
        func getFolderCorrectionPatterns() -> [(original: String, updated: String, count: Int)] {
            let context = persistenceController.viewContext
            var patterns: [(original: String, updated: String, count: Int)] = []
            
            // Fetch folder patterns
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@", "folder")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            
            do {
                let results = try context.fetch(fetchRequest)
                
                for pattern in results {
                    guard let original = pattern.value(forKey: "aiValue") as? String,
                          let updated = pattern.value(forKey: "userValue") as? String,
                          let count = pattern.value(forKey: "occurrences") as? Int32 else {
                        continue
                    }
                    
                    patterns.append((original: original, updated: updated, count: Int(count)))
                }
            } catch {
                print("❌ Error fetching folder patterns: \(error.localizedDescription)")
            }
            
            return patterns
        }
        
        // Get patterns for added tags
        func getAddedTagPatterns() -> [(tag: String, count: Int)] {
            let context = persistenceController.viewContext
            var patterns: [(tag: String, count: Int)] = []
            
            // Fetch tag_added patterns
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@", "tag_added")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            
            do {
                let results = try context.fetch(fetchRequest)
                
                for pattern in results {
                    guard let tag = pattern.value(forKey: "userValue") as? String,
                          let count = pattern.value(forKey: "occurrences") as? Int32 else {
                        continue
                    }
                    
                    patterns.append((tag: tag, count: Int(count)))
                }
            } catch {
                print("❌ Error fetching added tag patterns: \(error.localizedDescription)")
            }
            
            return patterns
        }
        
        // Get patterns for removed tags
        func getRemovedTagPatterns() -> [(tag: String, count: Int)] {
            let context = persistenceController.viewContext
            var patterns: [(tag: String, count: Int)] = []
            
            // Fetch tag_removed patterns
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "KeywordPattern")
            fetchRequest.predicate = NSPredicate(format: "fieldType == %@", "tag_removed")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occurrences", ascending: false)]
            
            do {
                let results = try context.fetch(fetchRequest)
                
                for pattern in results {
                    guard let tag = pattern.value(forKey: "aiValue") as? String,
                          let count = pattern.value(forKey: "occurrences") as? Int32 else {
                        continue
                    }
                    
                    patterns.append((tag: tag, count: Int(count)))
                }
            } catch {
                print("❌ Error fetching removed tag patterns: \(error.localizedDescription)")
            }
            
            return patterns
        }
        
        // Update tracking for deleted folders and tags
        func updateDeletedItemsHistory(folders: [String], tags: [String]) {
            let defaults = UserDefaults.standard
            let timestamp = Date()
            
            // Get existing history
            var folderHistory = defaults.stringArray(forKey: StatKeys.deletedFolderHistory) ?? []
            var tagHistory = defaults.stringArray(forKey: StatKeys.deletedTagHistory) ?? []
            
            // Add new entries with timestamp
            let dateFormatter = ISO8601DateFormatter()
            let timestampStr = dateFormatter.string(from: timestamp)
            
            for folder in folders {
                let entry = "\(folder)|\(timestampStr)"
                folderHistory.append(entry)
            }
            
            for tag in tags {
                let entry = "\(tag)|\(timestampStr)"
                tagHistory.append(entry)
            }
            
            // Keep only the most recent 100 entries
            if folderHistory.count > 100 {
                folderHistory = Array(folderHistory.suffix(100))
            }
            
            if tagHistory.count > 100 {
                tagHistory = Array(tagHistory.suffix(100))
            }
            
            // Save back to UserDefaults
            defaults.set(folderHistory, forKey: StatKeys.deletedFolderHistory)
            defaults.set(tagHistory, forKey: StatKeys.deletedTagHistory)
            
            if !folders.isEmpty || !tags.isEmpty {
                print("📊 Updated deleted items history - added \(folders.count) folders and \(tags.count) tags")
            }
        }
        
        // Get history of deleted items
        func getDeletedItemsHistory() -> [(type: String, name: String, date: Date)] {
            let defaults = UserDefaults.standard
            
            let folderHistory = defaults.stringArray(forKey: StatKeys.deletedFolderHistory) ?? []
            let tagHistory = defaults.stringArray(forKey: StatKeys.deletedTagHistory) ?? []
            
            var historyItems = [(type: String, name: String, date: Date)]()
            let dateFormatter = ISO8601DateFormatter()
            
            // Parse folder history
            for entry in folderHistory {
                let components = entry.components(separatedBy: "|")
                if components.count >= 2,
                   let date = dateFormatter.date(from: components[1]) {
                    historyItems.append((type: "folder", name: components[0], date: date))
                }
            }
            
            // Parse tag history
            for entry in tagHistory {
                let components = entry.components(separatedBy: "|")
                if components.count >= 2,
                   let date = dateFormatter.date(from: components[1]) {
                    historyItems.append((type: "tag", name: components[0], date: date))
                }
            }
            
            // Sort by most recent first
            return historyItems.sorted { $0.date > $1.date }
        }
    }
}

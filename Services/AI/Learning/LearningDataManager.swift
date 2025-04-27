import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

extension AI_Learning {
    /// Handles data management for adaptive learning examples
    class LearningDataManager {
        // Reference to persistence controller
        private let persistenceController: PersistenceController
        
        // Database of learning examples
        private var learningExamples: [ClassificationPair] = []
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
            
            // Make sure the KeywordPattern entity is properly initialized
            verifyAndCreateKeywordPatternEntity()
            
            // Load examples from Core Data
            loadLearningExamples()
            
            // Debug output current state
            print("🧠 LearningDataManager initialized with \(learningExamples.count) examples")
        }
        
        // Add a method to verify and create the KeywordPattern entity if needed
        private func verifyAndCreateKeywordPatternEntity() {
            let context = persistenceController.viewContext
            
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
        
        // Get all learning examples
        func getAllExamples() -> [ClassificationPair] {
            return learningExamples
        }
        
        // Add this helper method for direct Core Data saving
        func saveToCoreData(_ example: ClassificationPair) {
            let context = persistenceController.viewContext
            
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
        
        func loadLearningExamples() {
            // IMPORTANT: Clear the existing array first to prevent duplicates
            learningExamples.removeAll()
            
            let context = persistenceController.viewContext
            let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
            
            do {
                let coreDataExamples = try context.fetch(fetchRequest)
                
                for example in coreDataExamples {
                    // Skip examples without proper data
                    guard let fingerprint = example.documentFingerprint,
                          let aiData = example.aiSuggestionData,
                          let userData = example.userSelectionData,
                          let timestamp = example.timestamp else {
                        print("⚠️ Skipping learning example with missing data")
                        continue
                    }
                    
                    do {
                        // Decode AI suggestion
                        let aiSuggestion = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: aiData)
                        
                        // Decode user selection
                        let userSelection = try JSONDecoder().decode(DocumentClassifierService.DocumentSuggestions.self, from: userData)
                        
                        // Create and add the example
                        let classificationPair = ClassificationPair(
                            documentFingerprint: fingerprint,
                            aiSuggestion: aiSuggestion,
                            userSelection: userSelection,
                            timestamp: timestamp
                        )
                        
                        learningExamples.append(classificationPair)
                    } catch {
                        print("⚠️ Error decoding learning example: \(error.localizedDescription)")
                    }
                }
                
                print("✅ Loaded \(learningExamples.count) learning examples from Core Data")
            } catch {
                print("❌ Error loading examples from Core Data: \(error.localizedDescription)")
            }
        }
        
        func saveLearningExamples() {
            let context = persistenceController.viewContext
            
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
        
        // Check for and fix any broken entries
        func verifyAndFixCoreDataStorage() {
            print("🔍 Verifying learning data storage...")
            
            // Get a fresh context for verification
            let context = persistenceController.viewContext
            let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
            
            do {
                let examples = try context.fetch(fetchRequest)
                var brokenExamples = 0
                
                for example in examples {
                    // Check for broken examples
                    let fingerprintMissing = example.documentFingerprint == nil
                    let aiDataMissing = example.aiSuggestionData == nil
                    let userDataMissing = example.userSelectionData == nil
                    let timestampMissing = example.timestamp == nil
                    
                    if fingerprintMissing || aiDataMissing || userDataMissing || timestampMissing {
                        brokenExamples += 1
                        // Delete the broken example
                        context.delete(example)
                    }
                }
                
                if brokenExamples > 0 {
                    print("🔧 Found and deleted \(brokenExamples) broken learning examples")
                    try context.save()
                    
                    // Reload learning examples
                    loadLearningExamples()
                } else {
                    print("✅ No broken learning examples found")
                }
            } catch {
                print("❌ Error verifying Core Data storage: \(error.localizedDescription)")
            }
        }
        
        // Method to repair broken entities in Core Data
        func repairBrokenEntities() {
            print("🔧 Checking for broken learning examples in Core Data...")
            
            let context = persistenceController.viewContext
            let fetchRequest: NSFetchRequest<LearningExample> = LearningExample.fetchRequest()
            
            do {
                let coreDataExamples = try context.fetch(fetchRequest)
                
                // Stats for repair report
                var examplesChecked = 0
                var examplesFlagged = 0
                var examplesRepaired = 0
                var examplesDeleted = 0
                
                for example in coreDataExamples {
                    examplesChecked += 1
                    var needsRepair = false
                    
                    // Check required fields
                    if example.id == nil {
                        example.id = UUID()
                        needsRepair = true
                    }
                    
                    if example.documentFingerprint == nil || example.documentFingerprint?.isEmpty == true {
                        // This is a critical field - example can't be used without it
                        context.delete(example)
                        examplesDeleted += 1
                        continue
                    }
                    
                    if example.timestamp == nil {
                        example.timestamp = Date()
                        needsRepair = true
                    }
                    
                    // Check embedded data
                    if example.aiSuggestionData == nil {
                        // We can't repair this
                        context.delete(example)
                        examplesDeleted += 1
                        continue
                    }
                    
                    if example.userSelectionData == nil {
                        // We can't repair this
                        context.delete(example)
                        examplesDeleted += 1
                        continue
                    }
                    
                    if needsRepair {
                        examplesFlagged += 1
                        examplesRepaired += 1
                    }
                }
                
                // Save any changes
                if examplesRepaired > 0 || examplesDeleted > 0 {
                    try context.save()
                }
                
                print("🔧 Repair completed:")
                print("   • Checked: \(examplesChecked) examples")
                print("   • Flagged: \(examplesFlagged) examples needing repair")
                print("   • Repaired: \(examplesRepaired) examples")
                print("   • Deleted: \(examplesDeleted) examples that couldn't be repaired")
                
                // If any changes were made, reload
                if examplesRepaired > 0 || examplesDeleted > 0 {
                    loadLearningExamples()
                }
            } catch {
                print("❌ Error repairing entities: \(error.localizedDescription)")
            }
        }
        
        // Store a new learning example
        func storeExample(_ example: ClassificationPair) {
            // Check if we already have this fingerprint
            let existingIndex = learningExamples.firstIndex { $0.documentFingerprint == example.documentFingerprint }
            if let index = existingIndex {
                // Replace the existing example instead of adding a duplicate
                print("🔄 Replacing existing learning example with same fingerprint")
                learningExamples[index] = example
            } else {
                // Add new example
                learningExamples.append(example)
            }
            
            // Use direct Core Data saving which has better error handling
            saveToCoreData(example)
            
            print("✅ Saved learning example - now have \(learningExamples.count) examples")
        }
    }
}

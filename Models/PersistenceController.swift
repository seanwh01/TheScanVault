import CoreData
import CloudKit
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ScanVault")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure iCloud sync capabilities
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.TSV.app"
        )
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // For previews and testing
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
}

extension PersistenceController {
    func forceFlushChangesToDisk() {
        let context = container.viewContext
        
        // Only proceed if there are unsaved changes
        guard context.hasChanges else { 
            print("No changes to flush to disk")
            return 
        }
        
        // Save the context
        do {
            try context.save()
            print("✅ Changes saved to context")
            
            // Get the persistent store description
            guard let description = container.persistentStoreDescriptions.first else {
                print("⚠️ No persistent store description found")
                return
            }
            
            // Force-save to disk by recreating the coordinator
            let coordinator = container.persistentStoreCoordinator
            
            // Remove and recreate the store
            guard let storeURL = description.url else {
                print("⚠️ No store URL in description")
                return
            }
            
            do {
                try coordinator.performAndWait {
                    // Get all persistent stores
                    let stores = coordinator.persistentStores
                    
                    // For each store associated with our URL, remove and recreate it
                    for store in stores where store.url == storeURL {
                        try coordinator.remove(store)
                        try coordinator.addPersistentStore(
                            ofType: store.type,
                            configurationName: store.configurationName,
                            at: storeURL,
                            options: description.options
                        )
                        print("✅ Rebuilt persistent store to flush changes to disk")
                    }
                }
            } catch {
                print("⚠️ Error rebuilding persistent store: \(error)")
            }
        } catch {
            print("⚠️ Error saving context: \(error)")
        }
    }

    func verifyDocumentExists(id: UUID, completion: @escaping (Bool) -> Void) {
        // Create a fresh context to verify
        let verifyContext = container.newBackgroundContext()
        
        verifyContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Document")
            request.predicate = NSPredicate(format: "entityId == %@", id as CVarArg)
            
            do {
                let count = try verifyContext.count(for: request)
                let exists = count > 0
                print("🔍 Document verified to exist in fresh context: \(exists)")
                
                DispatchQueue.main.async {
                    completion(exists)
                }
            } catch {
                print("⚠️ Error verifying document: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    func fetchDocument(with id: UUID) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Document")
        request.predicate = NSPredicate(format: "entityId == %@", id as CVarArg)
        do {
            let results = try container.viewContext.fetch(request)
            return results.first
        } catch {
            print("Error fetching document: \(error)")
            return nil
        }
    }

    @objc private func handleDocumentDeletedNotification(_ notification: Notification) {
        // Handle the notification
        if let documentId = notification.userInfo?["documentId"] as? UUID {
            // Perform any necessary cleanup or refresh operations
            print("Document deleted notification received for ID: \(documentId)")
        }
    }

    // Load the Core Data store
    func loadPersistentStores(completionHandler: @escaping (Error?) -> Void) {
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error loading store: \(error), \(error.userInfo)")
                completionHandler(error)
            } else {
                print("✅ Core Data store loaded successfully")
                
                // Enable Core Data CloudKit sync if user is premium (using in-memory containers for testing)
                let settings = self.container.persistentStoreDescriptions.first?.cloudKitContainerOptions
                print("☁️ CloudKit settings configured: \(settings != nil)")
                
                // Check if KeywordPattern entity exists, create it if needed
                self.verifyAndCreateKeywordPatternEntity()
                
                completionHandler(nil)
            }
        }
    }
    
    // Verify that the KeywordPattern entity exists and can be used
    private func verifyAndCreateKeywordPatternEntity() {
        let context = container.viewContext
        
        // Check if we can create a KeywordPattern entity
        let entity = NSEntityDescription.entity(forEntityName: "KeywordPattern", in: context)
        if entity == nil {
            print("⚠️ KeywordPattern entity not found in Core Data model - will be created dynamically")
            
            // Create entity description
            let keywordPatternEntity = NSEntityDescription()
            keywordPatternEntity.name = "KeywordPattern"
            keywordPatternEntity.managedObjectClassName = "KeywordPattern"
            
            // Create attributes
            let idAttribute = NSAttributeDescription()
            idAttribute.name = "patternId"
            idAttribute.attributeType = .UUIDAttributeType
            idAttribute.isOptional = true
            
            let keywordAttribute = NSAttributeDescription()
            keywordAttribute.name = "keyword"
            keywordAttribute.attributeType = .stringAttributeType
            keywordAttribute.isOptional = true
            
            let fieldTypeAttribute = NSAttributeDescription()
            fieldTypeAttribute.name = "fieldType"
            fieldTypeAttribute.attributeType = .stringAttributeType
            fieldTypeAttribute.isOptional = true
            
            let aiValueAttribute = NSAttributeDescription()
            aiValueAttribute.name = "aiValue"
            aiValueAttribute.attributeType = .stringAttributeType
            aiValueAttribute.isOptional = true
            
            let userValueAttribute = NSAttributeDescription()
            userValueAttribute.name = "userValue"
            userValueAttribute.attributeType = .stringAttributeType
            userValueAttribute.isOptional = true
            
            let occurrencesAttribute = NSAttributeDescription()
            occurrencesAttribute.name = "occurrences"
            occurrencesAttribute.attributeType = .integer32AttributeType
            occurrencesAttribute.defaultValue = 0
            
            let firstSeenAttribute = NSAttributeDescription()
            firstSeenAttribute.name = "firstSeen"
            firstSeenAttribute.attributeType = .dateAttributeType
            firstSeenAttribute.isOptional = true
            
            let lastSeenAttribute = NSAttributeDescription()
            lastSeenAttribute.name = "lastSeen"
            lastSeenAttribute.attributeType = .dateAttributeType
            lastSeenAttribute.isOptional = true
            
            // Add attributes to entity
            keywordPatternEntity.properties = [
                idAttribute,
                keywordAttribute,
                fieldTypeAttribute,
                aiValueAttribute,
                userValueAttribute,
                occurrencesAttribute,
                firstSeenAttribute,
                lastSeenAttribute
            ]
            
            // Add entity to managed object model
            var entities = container.managedObjectModel.entities
            entities.append(keywordPatternEntity)
            container.managedObjectModel.entities = entities
            
            print("✅ KeywordPattern entity dynamically added to Core Data model")
        } else {
            print("✅ KeywordPattern entity found in Core Data model")
        }
    }
}

#if os(iOS)
// iOS-only code
#elseif os(macOS)
// macOS alternative code
#endif 

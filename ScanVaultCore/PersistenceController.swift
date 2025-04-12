import CoreData
import CloudKit

public class PersistenceController {
    public static let shared = PersistenceController()
    
    public let container: NSPersistentCloudKitContainer
    
    // Add this to maintain compatibility with the current codebase
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    public init() {
        container = NSPersistentCloudKitContainer(name: "ScanVault")
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to get persistent store description")
        }
        
        // Configure CloudKit integration
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.TSV.app"
        )
        
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Failed to load persistent stores: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
} 
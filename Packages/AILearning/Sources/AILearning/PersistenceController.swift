import Foundation
import CoreData

/// This file contains a minimal definition of the PersistenceController
/// that matches the one used in the main app, allowing for dependency injection

/// PersistenceController class for CoreData operations
public class PersistenceController {
    /// The main Core Data view context
    public var viewContext: NSManagedObjectContext {
        get {
            // This will be injected from the main app at runtime
            // This is just a placeholder for compilation
            fatalError("PersistenceController must be provided by the main app")
        }
    }
    
    /// Saves changes to the Core Data store
    public func save() {
        // This will be handled by the real PersistenceController
        // This is just a placeholder for compilation
    }
}

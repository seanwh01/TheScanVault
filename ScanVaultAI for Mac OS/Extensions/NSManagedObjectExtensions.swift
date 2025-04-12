import Foundation
import CoreData

// Make NSManagedObject identifiable for ForEach
extension NSManagedObject: Identifiable {
    public var id: NSManagedObjectID {
        return self.objectID
    }
} 
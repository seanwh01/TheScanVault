import Foundation
import CoreData

/// This file contains stub implementations of Core Data entities used by the AILearning module
/// They mirror the real entities in the main app but only contain the properties needed by the module

/// Folder entity
public class Folder: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

/// Tag entity
public class Tag: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

/// KeywordPattern entity for storing learned patterns
public class KeywordPattern: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var patternType: String?
    @NSManaged public var originalValue: String?
    @NSManaged public var correctedValue: String?
    @NSManaged public var keywords: [String]?
    @NSManaged public var frequency: Int16
    @NSManaged public var lastUsed: Date?
    @NSManaged public var createdAt: Date?
}

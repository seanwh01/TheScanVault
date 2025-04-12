import Foundation
import CoreData

@objc(KeywordPattern)
public class KeywordPattern: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var keyword: String?
    @NSManaged public var fieldType: String?
    @NSManaged public var aiValue: String?
    @NSManaged public var userValue: String?
    @NSManaged public var occurrences: Int32
    @NSManaged public var firstSeen: Date?
    @NSManaged public var lastSeen: Date?
}

extension KeywordPattern {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<KeywordPattern> {
        return NSFetchRequest<KeywordPattern>(entityName: "KeywordPattern")
    }
} 
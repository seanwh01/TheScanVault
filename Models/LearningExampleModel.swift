import Foundation
import CoreData

@objc(LearningExample)
public class LearningExample: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var documentFingerprint: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var aiSuggestionData: Data?
    @NSManaged public var userSelectionData: Data?
}

extension LearningExample {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LearningExample> {
        return NSFetchRequest<LearningExample>(entityName: "LearningExample")
    }
} 
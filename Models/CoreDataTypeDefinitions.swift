import Foundation
import CoreData

// IMPORTANT: This file provides basic declarations for Core Data entities
// to satisfy the compiler across both iOS and macOS targets

#if os(iOS)
@objc(Document)
public class Document: NSManagedObject {
    @NSManaged public var title: String?
    @NSManaged public var text: String?
    @NSManaged public var pdfData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var folderId: UUID?
    @NSManaged public var comments: String?
    @NSManaged public var tags: NSSet?
    @NSManaged public var documentData: Data?
    @NSManaged public var thumbnail: Data?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var aiModelUsed: String?
    @NSManaged public var isLocked: Bool
    
    public class func fetchRequest() -> NSFetchRequest<Document> {
        return NSFetchRequest<Document>(entityName: "Document")
    }

    // MARK: Generated accessors for tags
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

@objc(Folder)
public class Folder: NSManagedObject {
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    
    public class func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }
}

@objc(Tag)
public class Tag: NSManagedObject {
    @NSManaged public var name: String?
    @NSManaged public var documents: NSSet?
    @NSManaged public var createdAt: Date?
    
    public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }
}

@objc(CloudDocument)
public class CloudDocument: NSManagedObject {
    @NSManaged public var documentId: UUID?
    @NSManaged public var lockPassword: String?
    @NSManaged public var recordId: String?
    @NSManaged public var encryptedData: Data?
    @NSManaged public var iv: Data?
    @NSManaged public var lastSynced: Date?
    
    public class func fetchRequest() -> NSFetchRequest<CloudDocument> {
        return NSFetchRequest<CloudDocument>(entityName: "CloudDocument")
    }
}

// MARK: Generated accessors for documents
extension Tag {
    @objc(addDocumentsObject:)
    @NSManaged public func addToDocuments(_ value: Document)
    
    @objc(removeDocumentsObject:)
    @NSManaged public func removeFromDocuments(_ value: Document)
    
    @objc(addDocuments:)
    @NSManaged public func addToDocuments(_ values: NSSet)
    
    @objc(removeDocuments:)
    @NSManaged public func removeFromDocuments(_ values: NSSet)
}
#endif

// Add Core Data entity definitions for macOS
#if os(macOS)
@objc(Document)
public class Document: NSManagedObject {
    @NSManaged public var title: String?
    @NSManaged public var text: String?
    @NSManaged public var pdfData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var folderId: UUID?
    @NSManaged public var comments: String?
    @NSManaged public var tags: NSSet?
    @NSManaged public var documentData: Data?
    @NSManaged public var thumbnail: Data?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var aiModelUsed: String?
    @NSManaged public var isLocked: Bool
    
    public class func fetchRequest() -> NSFetchRequest<Document> {
        return NSFetchRequest<Document>(entityName: "Document")
    }

    // MARK: Generated accessors for tags
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

@objc(Folder)
public class Folder: NSManagedObject {
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    
    public class func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }
}

@objc(Tag)
public class Tag: NSManagedObject {
    @NSManaged public var name: String?
    @NSManaged public var documents: NSSet?
    @NSManaged public var createdAt: Date?
    
    public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }
}

@objc(CloudDocument)
public class CloudDocument: NSManagedObject {
    @NSManaged public var documentId: UUID?
    @NSManaged public var lockPassword: String?
    @NSManaged public var recordId: String?
    @NSManaged public var encryptedData: Data?
    @NSManaged public var iv: Data?
    @NSManaged public var lastSynced: Date?
    
    public class func fetchRequest() -> NSFetchRequest<CloudDocument> {
        return NSFetchRequest<CloudDocument>(entityName: "CloudDocument")
    }
}

// MARK: Generated accessors for documents
extension Tag {
    @objc(addDocumentsObject:)
    @NSManaged public func addToDocuments(_ value: Document)
    
    @objc(removeDocumentsObject:)
    @NSManaged public func removeFromDocuments(_ value: Document)
    
    @objc(addDocuments:)
    @NSManaged public func addToDocuments(_ values: NSSet)
    
    @objc(removeDocuments:)
    @NSManaged public func removeFromDocuments(_ values: NSSet)
}
#endif

// For backward compatibility with existing code
// DO NOT add id properties here - they are already defined in Core Data
extension Document {
    public var entityId: UUID? {
        get { return value(forKey: "id") as? UUID }
        set { setValue(newValue, forKey: "id") }
    }
}

extension Folder {
    public var entityId: UUID? {
        get { return value(forKey: "id") as? UUID }
        set { setValue(newValue, forKey: "id") }
    }
}

extension Tag {
    public var entityId: UUID? {
        get { return value(forKey: "id") as? UUID }
        set { setValue(newValue, forKey: "id") }
    }
} 
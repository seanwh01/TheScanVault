import Foundation
import CoreData

// MARK: - Folder Extensions
public extension NSManagedObject {
    // Safely get managed object context
    var safeContext: NSManagedObjectContext? {
        return self.managedObjectContext
    }
}

// MARK: - Folder Convenience Methods
public extension Folder {
    @objc var displayName: String {
        return self.name ?? "Untitled Folder"
    }
    
    static func create(in context: NSManagedObjectContext, name: String) -> Folder {
        let folder = Folder(context: context)
        folder.id = UUID()
        folder.name = name
        folder.createdAt = Date()
        return folder
    }
    
    static func fetchAll(in context: NSManagedObjectContext) -> [Folder] {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching folders: \(error)")
            return []
        }
    }
}

// MARK: - Document Convenience Methods
public extension Document {
    @objc var displayTitle: String {
        return self.title ?? "Untitled Document"
    }
    
    static func create(in context: NSManagedObjectContext, title: String, pdfData: Data? = nil) -> Document {
        let document = Document(context: context)
        document.id = UUID()
        document.title = title
        document.createdAt = Date()
        document.documentData = pdfData
        return document
    }
    
    static func fetchAll(in context: NSManagedObjectContext) -> [Document] {
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching documents: \(error)")
            return []
        }
    }
    
    static func fetchDocuments(in folder: Folder?, context: NSManagedObjectContext) -> [Document] {
        let request: NSFetchRequest<Document> = Document.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
        
        if let folder = folder {
            request.predicate = NSPredicate(format: "folder == %@", folder)
        } else {
            request.predicate = NSPredicate(format: "folder == NIL")
        }
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching documents: \(error)")
            return []
        }
    }
}
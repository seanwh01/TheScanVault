import Foundation
import CoreData
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
// If you need UIImage equivalent on macOS
typealias UIImage = NSImage
#endif

// Helper to check entity name
extension NSManagedObject {
    func isEntityType(_ name: String) -> Bool {
        return self.entity.name == name
    }
}

// Helper to check entity name
func entityExists(for name: String, in context: NSManagedObjectContext) -> Bool {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
    fetchRequest.fetchLimit = 1
    
    do {
        let count = try context.count(for: fetchRequest)
        return count > 0
    } catch {
        print("Error checking for entity \(name): \(error)")
        return false
    }
}

// MARK: - CoreData Model Extensions

// Document extension for Core Data
#if os(macOS)
// Helper method to get the folder for a document
extension NSManagedObject {
    func folder(in context: NSManagedObjectContext) -> NSManagedObject? {
        guard self.entity.name == "Document" else { return nil }
        guard let folderId = self.value(forKey: "folderId") as? UUID else { return nil }
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "Folder")
        request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Error fetching folder: \(error)")
            return nil
        }
    }
}
#endif

// Helper function to verify if the Core Data model contains an entity
func verifyEntityExists(entityName: String) -> Bool {
    let model = NSManagedObjectModel.mergedModel(from: [Bundle.main])
    return model?.entities.contains(where: { $0.name == entityName }) ?? false
}

// MARK: - Document Entity Extension
extension NSManagedObject {
    // Convenience getters and setters for Document properties
    var documentEntityId: UUID? {
        get { 
            guard self.entity.name == "Document" else { return nil }
            return self.value(forKey: "id") as? UUID 
        }
        set { 
            guard self.entity.name == "Document" else { return }
            self.setValue(newValue, forKey: "id") 
        }
    }
    
    var documentIdHelper: UUID? {
        get { return self.documentEntityId }
        set { self.documentEntityId = newValue }
    }
    
    // Convenience getters and setters for Folder properties
    var folderEntityId: UUID? {
        get { 
            guard self.entity.name == "Folder" else { return nil }
            return self.value(forKey: "id") as? UUID 
        }
        set { 
            guard self.entity.name == "Folder" else { return }
            self.setValue(newValue, forKey: "id") 
        }
    }
    
    var folderIdHelper: UUID? {
        get { return self.folderEntityId }
        set { self.folderEntityId = newValue }
    }
    
    // Convenience getters and setters for Tag properties
    var tagEntityId: UUID? {
        get { 
            guard self.entity.name == "Tag" else { return nil }
            return self.value(forKey: "id") as? UUID 
        }
        set { 
            guard self.entity.name == "Tag" else { return }
            self.setValue(newValue, forKey: "id") 
        }
    }
    
    var tagIdHelper: UUID? {
        get { return self.tagEntityId }
        set { self.tagEntityId = newValue }
    }
}

// MARK: - NSManagedObject Extensions

// Extension to add methods for handling Folder entities
extension NSManagedObject {
    
    class func createFolder(title: String, context: NSManagedObjectContext) -> NSManagedObject? {
        guard let folder = NSEntityDescription.insertNewObject(forEntityName: "Folder", into: context) as? NSManagedObject else {
            return nil
        }
        
        folder.setValue(title, forKey: "name")
        folder.setValue(UUID(), forKey: "id")
        folder.setValue(Date(), forKey: "createdAt")
        
        return folder
    }
    
    class func createDocument(title: String, folderId: UUID?, data: Data?, context: NSManagedObjectContext) -> NSManagedObject? {
        guard let document = NSEntityDescription.insertNewObject(forEntityName: "Document", into: context) as? NSManagedObject else {
            return nil
        }
        
        document.setValue(title, forKey: "title")
        document.setValue(UUID(), forKey: "id")
        document.setValue(folderId, forKey: "folderId")
        document.setValue(Date(), forKey: "createdAt")
        document.setValue(Date(), forKey: "updatedAt")
        document.setValue(data, forKey: "pdfData")
        
        return document
    }
    
    class func documentTitleDisplay(document: NSManagedObject) -> String {
        if let title = document.value(forKey: "title") as? String, !title.isEmpty {
            return title
        } else {
            return "Untitled Document"
        }
    }
    
    class func folderNameDisplay(folder: NSManagedObject) -> String {
        if let name = folder.value(forKey: "name") as? String, !name.isEmpty {
            return name
        } else {
            return "Untitled Folder"
        }
    }
}

// Extension methods for KeywordPattern
extension NSManagedObject {
    var keywordPatternId: UUID? {
        get { 
            guard self.entity.name == "KeywordPattern" else { return nil }
            return self.value(forKey: "id") as? UUID 
        }
        set { 
            guard self.entity.name == "KeywordPattern" else { return }
            self.setValue(newValue, forKey: "id") 
        }
    }
} 

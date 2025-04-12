import CoreData
import Foundation
@testable import ScanVaultAI_for_Mac_OS

// MARK: - NSPersistentContainer In-Memory Extension
extension NSPersistentContainer {
    static func inMemoryContainer(name: String) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: name)
        for description in container.persistentStoreDescriptions {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.type = NSInMemoryStoreType
            description.shouldAddStoreAsynchronously = false
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load in-memory persistent stores: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }
}

// MARK: - TestDataUtilities
class TestDataUtilities {
    // Create test document
    static func createTestDocument(in context: NSManagedObjectContext, title: String = "Test Document", date: Date = Date()) -> Document {
        let document = Document(context: context)
        document.id = UUID()
        document.title = title
        document.createdAt = date
        document.updatedAt = date
        document.text = "Test document content"
        
        return document
    }
    
    // Create multiple test documents with different creation dates
    static func createTestDocuments(in context: NSManagedObjectContext, titles: [String], dates: [Date]? = nil) -> [Document] {
        var documents: [Document] = []
        
        for (index, title) in titles.enumerated() {
            let date = dates?[safe: index] ?? Date().addingTimeInterval(-TimeInterval(index * 3600))
            let document = createTestDocument(in: context, title: title, date: date)
            documents.append(document)
        }
        
        try? context.save()
        return documents
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 
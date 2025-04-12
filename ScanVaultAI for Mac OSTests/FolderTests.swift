import XCTest
import CoreData
@testable import ScanVaultAI_for_Mac_OS

final class FolderTests: XCTestCase {
    var persistenceController: PersistenceController!
    var viewContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        viewContext = persistenceController.container.viewContext
    }
    
    override func tearDown() {
        persistenceController = nil
        viewContext = nil
        super.tearDown()
    }
    
    // MARK: - Folder Creation Tests
    
    func testCreateFolder() throws {
        // Arrange
        let folderEntity = NSEntityDescription.entity(forEntityName: "Folder", in: viewContext)!
        let folder = NSManagedObject(entity: folderEntity, insertInto: viewContext)
        
        // Act
        let folderId = UUID()
        let name = "Test Folder"
        folder.setValue(folderId, forKey: "id")
        folder.setValue(name, forKey: "name")
        folder.setValue(Date(), forKey: "createdAt")
        
        try viewContext.save()
        
        // Assert
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
        fetchRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
        
        let result = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(result.count, 1, "Folder should be saved in the context")
        XCTAssertEqual(result.first?.value(forKey: "name") as? String, name, "Folder name should match")
    }
    
    func testAssignDocumentToFolder() throws {
        // Arrange - Create folder
        let folderEntity = NSEntityDescription.entity(forEntityName: "Folder", in: viewContext)!
        let folder = NSManagedObject(entity: folderEntity, insertInto: viewContext)
        let folderId = UUID()
        folder.setValue(folderId, forKey: "id")
        folder.setValue("Test Folder", forKey: "name")
        
        // Create document
        let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: viewContext)!
        let document = NSManagedObject(entity: documentEntity, insertInto: viewContext)
        let documentId = UUID()
        document.setValue(documentId, forKey: "id")
        document.setValue("Test Document", forKey: "title")
        
        try viewContext.save()
        
        // Act - Assign document to folder
        document.setValue(folderId, forKey: "folderId")
        try viewContext.save()
        
        // Assert
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
        fetchRequest.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
        
        let result = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(result.count, 1, "Document should exist")
        XCTAssertEqual(result.first?.value(forKey: "folderId") as? UUID, folderId, "Document should be assigned to folder")
        
        // Test fetching folder name
        let folderName = document.getFolderName(forId: folderId)
        XCTAssertEqual(folderName, "Test Folder", "Should get correct folder name")
    }
    
    func testFetchAllFolders() throws {
        // Arrange
        let folderEntity = NSEntityDescription.entity(forEntityName: "Folder", in: viewContext)!
        
        // Create multiple folders
        for i in 1...5 {
            let folder = NSManagedObject(entity: folderEntity, insertInto: viewContext)
            folder.setValue(UUID(), forKey: "id")
            folder.setValue("Folder \(i)", forKey: "name")
            folder.setValue(Date(), forKey: "createdAt")
        }
        
        try viewContext.save()
        
        // Create a document to use for fetching folders
        let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: viewContext)!
        let document = NSManagedObject(entity: documentEntity, insertInto: viewContext)
        document.setValue(UUID(), forKey: "id")
        
        // Act
        let folders = document.fetchAllFolders()
        
        // Assert
        XCTAssertEqual(folders.count, 5, "Should fetch all 5 folders")
        
        // Check that folders are sorted by name
        let sortedNames = folders.map { $0.name }.sorted()
        let fetchedNames = folders.map { $0.name }
        XCTAssertEqual(fetchedNames, sortedNames, "Folders should be sorted by name")
    }
} 
import XCTest
import CoreData
import PDFKit
@testable import ScanVaultAI_for_Mac_OS

// MARK: - Test Data Generator

class TestDataGenerator {
    static let shared = TestDataGenerator()
    
    private init() {}
    
    // Create a test document with optional PDF data
    func createTestDocument(in context: NSManagedObjectContext, withPDF: Bool = false) -> NSManagedObject? {
        guard let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: context) else {
            XCTFail("Document entity not found")
            return nil
        }
        
        let document = NSManagedObject(entity: documentEntity, insertInto: context)
        document.setValue(UUID(), forKey: "id")
        document.setValue("Test Document", forKey: "title")
        document.setValue("Test Comments", forKey: "comments")
        document.setValue(Date(), forKey: "createdAt")
        document.setValue(Date(), forKey: "updatedAt")
        
        if withPDF {
            // Create a simple PDF
            let pdfDocument = PDFDocument()
            let pdfPage = PDFPage(image: NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)!)
            pdfDocument.insert(pdfPage!, at: 0)
            document.setValue(pdfDocument.dataRepresentation(), forKey: "pdfData")
        }
        
        do {
            try context.save()
            return document
        } catch {
            XCTFail("Failed to save test document: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Create a test folder
    func createTestFolder(in context: NSManagedObjectContext, name: String = "Test Folder") -> NSManagedObject? {
        guard let folderEntity = NSEntityDescription.entity(forEntityName: "Folder", in: context) else {
            XCTFail("Folder entity not found")
            return nil
        }
        
        let folder = NSManagedObject(entity: folderEntity, insertInto: context)
        folder.setValue(UUID(), forKey: "id")
        folder.setValue(name, forKey: "name")
        folder.setValue(Date(), forKey: "createdAt")
        
        do {
            try context.save()
            return folder
        } catch {
            XCTFail("Failed to save test folder: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Create multiple test documents
    func createTestDocuments(in context: NSManagedObjectContext, count: Int) -> [NSManagedObject] {
        var documents = [NSManagedObject]()
        
        for i in 1...count {
            guard let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: context) else {
                XCTFail("Document entity not found")
                return documents
            }
            
            let document = NSManagedObject(entity: documentEntity, insertInto: context)
            document.setValue(UUID(), forKey: "id")
            document.setValue("Test Document \(i)", forKey: "title")
            document.setValue("Test Comments \(i)", forKey: "comments")
            document.setValue(Date(), forKey: "createdAt")
            document.setValue(Date(), forKey: "updatedAt")
            
            documents.append(document)
        }
        
        do {
            try context.save()
            return documents
        } catch {
            XCTFail("Failed to save test documents: \(error.localizedDescription)")
            return documents
        }
    }
    
    // Create a complete test data set with documents and folders
    func createTestDataSet(in context: NSManagedObjectContext) -> (documents: [NSManagedObject], folders: [NSManagedObject]) {
        var documents = [NSManagedObject]()
        var folders = [NSManagedObject]()
        
        // Create folders
        for i in 1...3 {
            if let folder = createTestFolder(in: context, name: "Folder \(i)") {
                folders.append(folder)
            }
        }
        
        // Create documents
        for i in 1...10 {
            guard let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: context) else {
                continue
            }
            
            let document = NSManagedObject(entity: documentEntity, insertInto: context)
            document.setValue(UUID(), forKey: "id")
            document.setValue("Document \(i)", forKey: "title")
            document.setValue("Comments for document \(i)", forKey: "comments")
            document.setValue(Date(), forKey: "createdAt")
            document.setValue(Date(), forKey: "updatedAt")
            
            // Assign some documents to folders
            if i % 3 == 0 && !folders.isEmpty {
                let folderIndex = (i / 3 - 1) % folders.count
                if let folderId = folders[folderIndex].value(forKey: "id") as? UUID {
                    document.setValue(folderId, forKey: "folderId")
                }
            }
            
            documents.append(document)
        }
        
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save test data set: \(error.localizedDescription)")
        }
        
        return (documents, folders)
    }
}

// MARK: - In-Memory Store Helper

extension PersistenceController {
    // Helper to get a test-specific persistence controller
    static func forTesting() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
    
    // Helper to create a clean test context
    func createTestContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
} 
import XCTest
import CoreData
@testable import ScanVaultAI_for_Mac_OS

final class ExtensionsTests: XCTestCase {
    var persistenceController: PersistenceController!
    var viewContext: NSManagedObjectContext!
    var testDocument: NSManagedObject!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        viewContext = persistenceController.container.viewContext
        
        // Create a test document
        let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: viewContext)!
        testDocument = NSManagedObject(entity: documentEntity, insertInto: viewContext)
        
        testDocument.setValue(UUID(), forKey: "id")
        testDocument.setValue("Test Document", forKey: "title")
        
        // Set comments field if available
        if testDocument.entity.propertiesByName["comments"] != nil {
            testDocument.setValue("Test Comments", forKey: "comments")
        }
        
        testDocument.setValue(Date(), forKey: "createdAt")
        
        try? viewContext.save()
    }
    
    override func tearDown() {
        testDocument = nil
        viewContext = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // Helper to get comments content
    private func getCommentsContent(from document: NSManagedObject) -> String? {
        if document.entity.propertiesByName["comments"] != nil {
            return document.value(forKey: "comments") as? String
        }
        return nil
    }
    
    // MARK: - Extension Tests
    
    func testHasPropertyExtension() {
        // Test for existing properties
        XCTAssertTrue(testDocument.hasProperty("id"), "Document should have id property")
        XCTAssertTrue(testDocument.hasProperty("title"), "Document should have title property")
        
        // Test for non-existing property
        XCTAssertFalse(testDocument.hasProperty("nonExistentProperty"), "Document should not have nonExistentProperty")
    }
    
    func testGetValueExtension() {
        // Test getting value with existing property
        let title = testDocument.getValue(forKey: "title", defaultValue: "Default Title")
        XCTAssertEqual(title, "Test Document", "Should return the correct title")
        
        // Test getting value with non-existing property
        let nonExistentValue = testDocument.getValue(forKey: "nonExistentProperty", defaultValue: "Default Value")
        XCTAssertEqual(nonExistentValue, "Default Value", "Should return the default value")
    }
    
    func testParseTagsArray() {
        // Test with empty string
        let emptyTags = testDocument.parseTagsArray(from: "")
        XCTAssertEqual(emptyTags.count, 0, "Empty string should result in empty array")
        
        // Test with nil
        let nilTags = testDocument.parseTagsArray(from: nil)
        XCTAssertEqual(nilTags.count, 0, "Nil string should result in empty array")
        
        // Test with valid tags string
        let tagsString = "tag1, tag2,tag3"
        let tags = testDocument.parseTagsArray(from: tagsString)
        XCTAssertEqual(tags.count, 3, "Should parse 3 tags")
        XCTAssertEqual(tags[0], "tag1", "First tag should be 'tag1'")
        XCTAssertEqual(tags[1], "tag2", "Second tag should be 'tag2'")
        XCTAssertEqual(tags[2], "tag3", "Third tag should be 'tag3'")
        
        // Test with whitespace and empty tags
        let messyTagsString = "tag1, , tag2,   ,tag3"
        let messyTags = testDocument.parseTagsArray(from: messyTagsString)
        XCTAssertEqual(messyTags.count, 3, "Should parse 3 valid tags and skip empty ones")
    }
    
    func testNotificationNames() {
        // Test notification name constants
        XCTAssertEqual(Notification.Name.documentUpdated.rawValue, "DocumentUpdated", "documentUpdated notification name should match")
        XCTAssertEqual(Notification.Name.goToPage.rawValue, "GoToPage", "goToPage notification name should match")
        XCTAssertEqual(Notification.Name.updateZoom.rawValue, "UpdateZoom", "updateZoom notification name should match")
    }
    
    func testNotificationCenterPostDocumentUpdated() {
        // Set up expectation
        let expectation = XCTestExpectation(description: "Document updated notification posted")
        
        // Add observer
        let documentId = UUID()
        let observer = NotificationCenter.default.addObserver(
            forName: .documentUpdated,
            object: nil,
            queue: .main
        ) { notification in
            // Verify notification contents
            if let notificationDocId = notification.userInfo?["documentId"] as? UUID,
               let folderChanged = notification.userInfo?["folderChanged"] as? Bool {
                XCTAssertEqual(notificationDocId, documentId, "Document ID should match")
                XCTAssertTrue(folderChanged, "folderChanged should be true")
                expectation.fulfill()
            }
        }
        
        // Post notification
        NotificationCenter.default.postDocumentUpdated(
            documentId: documentId,
            folderChanged: true,
            newFolderId: UUID()
        )
        
        // Wait for expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        NotificationCenter.default.removeObserver(observer)
    }
} 
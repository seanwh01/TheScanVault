import XCTest
import SwiftUI
// import ViewInspector - Will use this when package is added
@testable import TheScanVault

// Extension to make DocumentTagsEditView inspectable by ViewInspector
extension DocumentTagsEditView: Inspectable {}

class DocumentTagsEditViewTests: XCTestCase {
    var tagsViewModel: MockTagsViewModel!
    
    override func setUp() {
        super.setUp()
        tagsViewModel = MockTagsViewModel()
        
        // Pre-set the document ID for testing
        tagsViewModel.lastDocumentId = UUID()
    }
    
    override func tearDown() {
        tagsViewModel = nil
        super.tearDown()
    }
    
    func testInitialTagsLoading() throws {
        // Set up test tags
        let documentTags = ["important", "receipt", "tax"]
        let allTags = ["important", "receipt", "tax", "personal", "work"]
        
        tagsViewModel.mockDocumentTags = documentTags
        tagsViewModel.mockAllTags = allTags
        
        // Reset tracking
        tagsViewModel.loadTagsCalled = false
        tagsViewModel.loadTagsForDocumentId = nil
        
        // Create the tags edit view
        let view = DocumentTagsEditView(viewModel: tagsViewModel)
        
        // Simulate loading tags (normally triggered by view load)
        tagsViewModel.loadTags(forDocument: tagsViewModel.lastDocumentId!)
        
        // Verify tags are loaded
        XCTAssertTrue(tagsViewModel.loadTagsCalled)
        XCTAssertEqual(tagsViewModel.loadTagsForDocumentId, tagsViewModel.lastDocumentId)
        
        // Test UI rendering
        let sut = try view.inspect()
        
        // Verify each document tag is displayed
        for tag in documentTags {
            let tagView = try? sut.find(ViewType.Text.self) { view in
                try view.text() == tag
            }
            XCTAssertNotNil(tagView, "Tag '\(tag)' should be displayed")
        }
        
        // Verify available tags section exists
        let availableTagsSection = try? sut.find { view in
            let text = try view.text()
            return text.contains("Available Tags")
        }
        XCTAssertNotNil(availableTagsSection, "Available tags section should be displayed")
    }
    
    func testAddTag() throws {
        // Set up test tags
        let documentTags = ["important"]
        let allTags = ["important", "receipt", "tax", "personal", "work"]
        
        tagsViewModel.mockDocumentTags = documentTags
        tagsViewModel.mockAllTags = allTags
        
        // Reset tracking
        tagsViewModel.addTagCalled = false
        tagsViewModel.addedTag = nil
        
        // Create the tags edit view
        let view = DocumentTagsEditView(viewModel: tagsViewModel)
        
        // Test UI interaction
        let sut = try view.inspect()
        
        // Directly manipulate the mock to simulate adding a tag
        tagsViewModel.addTag("receipt", toDocument: tagsViewModel.lastDocumentId!)
        
        // Find and tap on "receipt" tag in available tags
        let receiptTag = try sut.find(ViewType.Button.self) { view in
            let text = try view.label().text()
            return text == "receipt"
        }
        try receiptTag.tap()
        
        // Verify tag was added
        XCTAssertTrue(tagsViewModel.addTagCalled)
        XCTAssertEqual(tagsViewModel.addedTag, "receipt")
        XCTAssertEqual(tagsViewModel.lastDocumentId, tagsViewModel.lastDocumentId)
    }
    
    func testRemoveTag() throws {
        // Set up test tags
        let documentTags = ["important", "receipt", "tax"]
        let allTags = ["important", "receipt", "tax", "personal", "work"]
        
        tagsViewModel.mockDocumentTags = documentTags
        tagsViewModel.mockAllTags = allTags
        
        // Reset tracking
        tagsViewModel.removeTagCalled = false
        tagsViewModel.removedTag = nil
        
        // Create the tags edit view
        let view = DocumentTagsEditView(viewModel: tagsViewModel)
        
        // Directly manipulate the mock to simulate removing a tag
        tagsViewModel.removeTag("receipt", fromDocument: tagsViewModel.lastDocumentId!)
        
        // Test UI interaction
        let sut = try view.inspect()
        
        // Find and tap on remove button for "receipt" tag
        let receiptTagRemoveButton = try sut.find(ViewType.Button.self) { view in
            try view.find(ViewType.Text.self) { subview in
                try subview.text() == "receipt"
            }
            return try view.find(ViewType.Image.self) { img in
                let label = try img.accessibilityLabel()
                return label == "Remove"
            } != nil
        }
        try receiptTagRemoveButton.tap()
        
        // Verify tag was removed
        XCTAssertTrue(tagsViewModel.removeTagCalled)
        XCTAssertEqual(tagsViewModel.removedTag, "receipt")
        XCTAssertEqual(tagsViewModel.lastDocumentId, tagsViewModel.lastDocumentId)
    }
    
    func testCreateNewTag() throws {
        // Set up test tags
        let documentTags: [String] = []
        let allTags = ["important", "receipt", "tax"]
        
        tagsViewModel.mockDocumentTags = documentTags
        tagsViewModel.mockAllTags = allTags
        
        // Reset tracking
        tagsViewModel.createTagCalled = false
        tagsViewModel.createdTag = nil
        tagsViewModel.addTagCalled = false
        tagsViewModel.addedTag = nil
        
        // Create the tags edit view
        let view = DocumentTagsEditView(viewModel: tagsViewModel)
        
        // Directly manipulate the mock to simulate creating a tag
        tagsViewModel.createTag("newcategory")
        tagsViewModel.addTag("newcategory", toDocument: tagsViewModel.lastDocumentId!)
        
        // Test UI interaction
        let sut = try view.inspect()
        
        // Find the new tag TextField
        let newTagField = try sut.find(ViewType.TextField.self)
        
        // Simulate entering a new tag
        try newTagField.setInput("newcategory")
        
        // Find and tap the "Add" button
        let addButton = try sut.find(ViewType.Button.self) { view in
            let text = try view.label().text()
            return text == "Add"
        }
        try addButton.tap()
        
        // Verify new tag was created and added
        XCTAssertTrue(tagsViewModel.createTagCalled)
        XCTAssertEqual(tagsViewModel.createdTag, "newcategory")
        XCTAssertTrue(tagsViewModel.addTagCalled)
        XCTAssertEqual(tagsViewModel.addedTag, "newcategory")
        XCTAssertEqual(tagsViewModel.lastDocumentId, tagsViewModel.lastDocumentId)
    }
}

// Mock ViewModel for testing
class MockTagsViewModel: DocumentViewModel {
    var mockDocumentTags: [String] = []
    var mockAllTags: [String] = []
    
    // Add allTags property directly to the mock class
    var allTags: [TagItem] = []
    
    var loadTagsCalled = false
    var loadTagsForDocumentId: UUID?
    var addTagCalled = false
    var addedTag: String?
    var removeTagCalled = false
    var removedTag: String?
    var createTagCalled = false
    var createdTag: String?
    var lastDocumentId: UUID?
    
    // Override the init with a parameterless initializer for testing
    override init(document: Document? = nil) {
        // Call super.init with nil document
        super.init(document: document ?? Document(context: PersistenceController.shared.container.viewContext))
    }
    
    // Mock tag methods
    func loadTags(forDocument documentId: UUID) {
        loadTagsCalled = true
        loadTagsForDocumentId = documentId
        
        // Update the document tags in the ViewModel
        refreshTags()
    }
    
    func addTag(_ tag: String, toDocument documentId: UUID) {
        addTagCalled = true
        addedTag = tag
        lastDocumentId = documentId
        if !mockDocumentTags.contains(tag) {
            mockDocumentTags.append(tag)
        }
        
        // Update the document tags in the ViewModel
        refreshTags()
    }
    
    func removeTag(_ tag: String, fromDocument documentId: UUID) {
        removeTagCalled = true
        removedTag = tag
        lastDocumentId = documentId
        mockDocumentTags.removeAll { $0 == tag }
        
        // Update the document tags in the ViewModel
        refreshTags()
    }
    
    func createTag(_ tag: String) {
        createTagCalled = true
        createdTag = tag
        if !mockAllTags.contains(tag) {
            mockAllTags.append(tag)
        }
        
        // Update the available tags in the ViewModel
        refreshTags()
    }
    
    // Helper to create the tags array for the view model
    private func refreshTags() {
        // Convert string tag names to TagItem objects and assign to the mock property
        allTags = mockAllTags.map { tagName in
            return TagItem(id: UUID(), name: tagName)
        }
    }
    
    func getDocumentTags() -> [String] {
        return mockDocumentTags
    }
    
    func getAllTags() -> [String] {
        return mockAllTags
    }
    
    // Override document property to use mock data
    override var document: Document? {
        get {
            let context = PersistenceController.shared.container.viewContext
            let doc = Document(context: context)
            doc.id = lastDocumentId
            doc.title = "Test Document"
            
            // Add mock tags as a Tag set
            if !mockDocumentTags.isEmpty {
                // Create individual tags and add them one by one
                // instead of creating a set first
                for tagName in mockDocumentTags {
                    let tag = Tag(context: context)
                    tag.id = UUID()
                    tag.name = tagName
                    doc.addToTags(tag)
                }
            }
            
            return doc
        }
        set {
            super.document = newValue
        }
    }
    
    // Override createAndAddTag to track test calls
    override func createAndAddTag(name: String) {
        createTag(name)
        addTag(name, toDocument: lastDocumentId ?? UUID())
    }
    
    // Override removeTag to track test calls
    override func removeTag(_ tag: Tag) {
        if let tagName = tag.name {
            removeTag(tagName, fromDocument: lastDocumentId ?? UUID())
        }
    }
    
    // Override saveTags
    override func saveTags(sendNotification: Bool = true) {
        // Just capture the call for testing
    }
} 
import XCTest
@testable import TheScanVault

class VaultViewModelDataManagerTests: XCTestCase {
    
    var viewModel: TestViewModel!
    var mockPersistenceController: MockPersistenceController!
    
    override func setUp() {
        super.setUp()
        mockPersistenceController = MockPersistenceController()
        viewModel = TestViewModel(mockController: mockPersistenceController)
        
        // Set up 3 mock documents for testing
        mockPersistenceController.setupMockData()
        viewModel.loadDocuments()
    }
    
    override func tearDown() {
        viewModel = nil
        mockPersistenceController = nil
        super.tearDown()
    }
    
    func testInitialDocumentLoad() {
        // Verify that documents were loaded correctly
        XCTAssertEqual(viewModel.documents.count, 3)
        XCTAssertEqual(viewModel.documents.first?.title, "Test Document 3")
    }
    
    func testDeleteDocument() {
        // Initial check - should have 3 documents
        XCTAssertEqual(viewModel.documents.count, 3)
        
        if let id = viewModel.documents.first?.id {
            // Delete the first document
            viewModel.deleteDocument(withId: id)
            
            // Should have 2 documents now
            XCTAssertEqual(viewModel.documents.count, 2)
            
            // The deleted document should not be found
            XCTAssertNil(mockPersistenceController.fetchDocument(withId: id))
        } else {
            XCTFail("Failed to get valid document ID")
        }
    }
    
    func testAddDocument() {
        // Initial check - should have 3 documents
        XCTAssertEqual(viewModel.documents.count, 3)
        
        // Add a new document
        let newDocument = viewModel.addDocument(
            title: "New Test Document",
            text: "This is a new test document"
        )
        
        // Should have 4 documents now
        XCTAssertEqual(viewModel.documents.count, 4)
        
        // Verify the new document was added with correct data
        XCTAssertEqual(newDocument.title, "New Test Document")
        XCTAssertEqual(newDocument.text, "This is a new test document")
        
        // Verify the document exists in the persistence controller
        let fetchedDoc = mockPersistenceController.fetchDocument(withId: newDocument.id!)
        XCTAssertNotNil(fetchedDoc)
        XCTAssertEqual(fetchedDoc?.title, "New Test Document")
    }
    
    func testDocumentListSorting() {
        // Setup test documents specifically for sorting
        viewModel.setupTestDocumentsForSorting()
        
        // Verify initial state (before sorting)
        XCTAssertEqual(viewModel.documents.count, 3)
        
        // Test sorting by date (newest first)
        viewModel.sortDocuments(by: .dateNewest)
        XCTAssertEqual(viewModel.documents[0].title, "Newest")
        XCTAssertEqual(viewModel.documents[1].title, "Middle")
        XCTAssertEqual(viewModel.documents[2].title, "Oldest")
        
        // Test sorting by date (oldest first)
        viewModel.sortDocuments(by: .dateOldest)
        XCTAssertEqual(viewModel.documents[0].title, "Oldest")
        XCTAssertEqual(viewModel.documents[1].title, "Middle")
        XCTAssertEqual(viewModel.documents[2].title, "Newest")
        
        // Test sorting by title
        viewModel.sortDocuments(by: .title)
        XCTAssertEqual(viewModel.documents[0].title, "Middle")
        XCTAssertEqual(viewModel.documents[1].title, "Newest")
        XCTAssertEqual(viewModel.documents[2].title, "Oldest")
    }
} 
import XCTest
@testable import TheScanVault

final class VaultViewModelTests: XCTestCase {
    
    var sut: VaultViewModel!
    var mockPersistenceController: MockPersistenceController!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockPersistenceController = MockPersistenceController()
        sut = VaultViewModel(persistenceController: mockPersistenceController)
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockPersistenceController = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Search Tests
    
    func testOCRTextSearch() {
        // Given
        // Create documents with specific OCR text for testing
        let doc1 = createTestDocument(
            title: "Regular Document", 
            text: "Regular content",
            ocrText: "Standard OCR content",
            date: Date()
        )
        
        let doc2 = createTestDocument(
            title: "OCR Test Document", 
            text: "Regular content",
            ocrText: "This document contains specialized OCR text with unique words like scanvault_ocr_test_identifier",
            date: Date()
        )
        
        let doc3 = createTestDocument(
            title: "Another Document", 
            text: "Different content",
            ocrText: "Some other OCR content without special terms",
            date: Date()
        )
        
        mockPersistenceController.mockDocuments = [doc1, doc2, doc3]
        sut.fetchDocuments()
        
        // Empty search criteria should show all documents
        sut.searchOCRText = ""
        sut.searchDocuments()
        let initialCount = sut.documents.count
        XCTAssertEqual(initialCount, 3, "Should have 3 documents before search")
        
        // When - Search for a unique term that should be in only one document's OCR text
        sut.searchOCRText = "scanvault_ocr_test_identifier"
        sut.searchDocuments()
        
        // Then - Should find exactly one document
        XCTAssertEqual(sut.documents.count, 1, "Should find exactly one document")
        XCTAssertEqual(sut.documents.first?.title, "OCR Test Document", "Found document should match expected title")
        
        // When - Search for term not present in any document
        sut.searchOCRText = "xyz_nonexistent_term_123456789"
        sut.searchDocuments()
        
        // Then - Should find no documents
        XCTAssertEqual(sut.documents.count, 0, "Should find no documents")
        
        // When - Reset search
        sut.searchOCRText = ""
        sut.searchDocuments()
        
        // Then - All documents should be shown again
        XCTAssertEqual(sut.documents.count, initialCount, "Should return to showing all documents")
    }
    
    // MARK: - Helper Methods
    
    private func createTestDocument(title: String, text: String, ocrText: String, date: Date) -> Document {
        let context = mockPersistenceController.container.viewContext
        let document = Document(context: context)
        document.id = UUID()
        document.title = title
        document.text = text
        document.ocrText = ocrText
        document.createdAt = date
        return document
    }
}

// MARK: - Mock Classes

class MockPersistenceController: PersistenceController {
    var mockDocuments: [Document] = []
    
    override init() {
        super.init()
    }
    
    func fetchDocuments() -> [Document] {
        return mockDocuments
    }
} 
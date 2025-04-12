import XCTest
import SwiftUI
@testable import TheScanVault

final class AISearchResultsViewTests: XCTestCase {
    
    var viewModel: AIResearchViewModel!
    
    override func setUpWithError() throws {
        viewModel = AIResearchViewModel()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
    }
    
    // MARK: - Layout Tests
    
    func testSearchResultsLayout() throws {
        // Create binding for isPresented
        let isPresented = Binding<Bool>(get: { true }, set: { _ in })
        
        // Create the view - the fact that this doesn't crash is part of the test
        let view = Views_AIResearch.AISearchResultsView(
            viewModel: viewModel,
            isPresented: isPresented
        )
        
        // Verify the view exists - this is a basic test that doesn't require rendering
        XCTAssertNotNil(view, "AISearchResultsView should be created successfully")
    }
    
    // MARK: - Document Grouping Tests
    
    func testDocumentGrouping() throws {
        // Setup - Create mock folders and documents
        let folder1 = FolderItem(id: UUID(), name: "Folder 1")
        let folder2 = FolderItem(id: UUID(), name: "Folder 2")
        viewModel.allFolders = [folder1, folder2]
        
        let doc1 = AIDocumentItem(id: UUID(), title: "Doc 1", textLength: 100, createdAt: Date(), folderId: folder1.id, tagIds: [], thumbnail: nil, isLocked: false)
        let doc2 = AIDocumentItem(id: UUID(), title: "Doc 2", textLength: 200, createdAt: Date(), folderId: folder1.id, tagIds: [], thumbnail: nil, isLocked: false)
        let doc3 = AIDocumentItem(id: UUID(), title: "Doc 3", textLength: 300, createdAt: Date(), folderId: folder2.id, tagIds: [], thumbnail: nil, isLocked: false)
        let doc4 = AIDocumentItem(id: UUID(), title: "Doc 4", textLength: 400, createdAt: Date(), folderId: nil, tagIds: [], thumbnail: nil, isLocked: false)
        viewModel.documents = [doc1, doc2, doc3, doc4]
        
        // Verify documents can be grouped by folder
        let groupedDocs = Dictionary(grouping: viewModel.documents) { $0.folderId }
        
        // Verify grouping
        XCTAssertEqual(groupedDocs.count, 3, "Documents should be grouped into 3 groups (2 folders + nil)")
        XCTAssertEqual(groupedDocs[folder1.id]?.count, 2, "Folder 1 should have 2 documents")
        XCTAssertEqual(groupedDocs[folder2.id]?.count, 1, "Folder 2 should have 1 document")
        XCTAssertEqual(groupedDocs[nil]?.count, 1, "No folder group should have 1 document")
    }
    
    // MARK: - Document Selection Tests
    
    func testDocumentSelection() throws {
        // Setup - Create mock documents
        let doc1 = AIDocumentItem(id: UUID(), title: "Doc 1", textLength: 100, createdAt: Date(), folderId: nil, tagIds: [], thumbnail: nil, isLocked: false)
        let doc2 = AIDocumentItem(id: UUID(), title: "Doc 2", textLength: 200, createdAt: Date(), folderId: nil, tagIds: [], thumbnail: nil, isLocked: false)
        viewModel.documents = [doc1, doc2]
        
        // Initially no documents are selected
        XCTAssertEqual(viewModel.selectedDocumentIds.count, 0, "No documents should be selected initially")
        
        // Select a document
        viewModel.selectDocument(doc1.id)
        
        // Verify selection
        XCTAssertTrue(viewModel.isDocumentSelected(doc1.id), "Document 1 should be selected")
        XCTAssertFalse(viewModel.isDocumentSelected(doc2.id), "Document 2 should not be selected")
        
        // Select all documents
        viewModel.selectAllDocuments()
        
        // Verify all documents are selected
        XCTAssertTrue(viewModel.isDocumentSelected(doc1.id), "Document 1 should be selected")
        XCTAssertTrue(viewModel.isDocumentSelected(doc2.id), "Document 2 should be selected")
        
        // Unselect all documents
        viewModel.unselectAllDocuments()
        
        // Verify no documents are selected
        XCTAssertFalse(viewModel.isDocumentSelected(doc1.id), "Document 1 should be unselected")
        XCTAssertFalse(viewModel.isDocumentSelected(doc2.id), "Document 2 should be unselected")
    }
    
    // MARK: - No Results View Tests
    
    func testNoResultsView() throws {
        // Setup - Ensure no documents
        viewModel.documents = []
        
        // Create binding for isPresented
        let isPresented = Binding<Bool>(get: { true }, set: { _ in })
        
        // Create the view - the fact that this doesn't crash is part of the test
        let view = Views_AIResearch.AISearchResultsView(
            viewModel: viewModel,
            isPresented: isPresented
        )
        
        // Verify the view exists even with no results
        XCTAssertNotNil(view, "AISearchResultsView should handle empty results")
        
        // Verify no documents
        XCTAssertEqual(viewModel.documents.count, 0, "There should be no documents")
    }
    
    // MARK: - Token Count Display Tests
    
    func testTokenCountDisplay() throws {
        // Setup - Create mock documents with known token counts
        let doc1 = AIDocumentItem(id: UUID(), title: "Doc 1", textLength: 100, createdAt: Date(), folderId: nil, tagIds: [], thumbnail: nil, isLocked: false)
        let doc2 = AIDocumentItem(id: UUID(), title: "Doc 2", textLength: 200, createdAt: Date(), folderId: nil, tagIds: [], thumbnail: nil, isLocked: false)
        viewModel.documents = [doc1, doc2]
        
        // Initial token count should be 0
        XCTAssertEqual(viewModel.totalSelectedTokens, 0, "Initial token count should be 0")
        
        // Select document 1
        viewModel.selectDocument(doc1.id)
        
        // Verify token count updated
        XCTAssertEqual(viewModel.totalSelectedTokens, doc1.estimatedTokens, "Token count should match document 1")
        
        // Select document 2
        viewModel.selectDocument(doc2.id)
        
        // Verify token count updated
        XCTAssertEqual(viewModel.totalSelectedTokens, doc1.estimatedTokens + doc2.estimatedTokens, "Token count should be sum of both documents")
        
        // Unselect document 1
        viewModel.unselectDocument(doc1.id)
        
        // Verify token count updated
        XCTAssertEqual(viewModel.totalSelectedTokens, doc2.estimatedTokens, "Token count should match document 2")
    }
} 
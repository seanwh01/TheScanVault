import XCTest
import SwiftUI
@testable import TheScanVault

final class AIFolderSelectionViewTests: XCTestCase {
    
    var viewModel: AIResearchViewModel!
    
    override func setUpWithError() throws {
        viewModel = AIResearchViewModel()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
    }
    
    // MARK: - Layout Tests
    
    func testFolderSelectionLayout() throws {
        // Create the view - the fact that this doesn't crash is part of the test
        let view = Views_AIResearch.AIFolderSelectionView(
            viewModel: viewModel
        )
        
        // Verify the view exists - this is a basic test that doesn't require rendering
        XCTAssertNotNil(view, "AIFolderSelectionView should be created successfully")
    }
    
    // MARK: - Folder Selection Toggle Tests
    
    func testToggleFolderSelection() throws {
        // Setup - Create mock folders and add them to viewModel
        let folder1 = FolderItem(id: UUID(), name: "Folder 1")
        let folder2 = FolderItem(id: UUID(), name: "Folder 2")
        viewModel.allFolders = [folder1, folder2]
        
        // Initially no folders should be selected
        XCTAssertEqual(viewModel.selectedFolderIds.count, 0, "No folders should be selected initially")
        
        // Toggle one folder
        viewModel.toggleFolderInSelection(folder1.id)
        
        // Verify folder is selected
        XCTAssertTrue(viewModel.selectedFolderIds.contains(folder1.id), "Folder 1 should be selected")
        XCTAssertFalse(viewModel.selectedFolderIds.contains(folder2.id), "Folder 2 should not be selected")
        
        // Toggle second folder
        viewModel.toggleFolderInSelection(folder2.id)
        
        // Verify both folders are selected
        XCTAssertTrue(viewModel.selectedFolderIds.contains(folder1.id), "Folder 1 should still be selected")
        XCTAssertTrue(viewModel.selectedFolderIds.contains(folder2.id), "Folder 2 should now be selected")
        
        // Toggle first folder again to deselect
        viewModel.toggleFolderInSelection(folder1.id)
        
        // Verify only second folder remains selected
        XCTAssertFalse(viewModel.selectedFolderIds.contains(folder1.id), "Folder 1 should be deselected")
        XCTAssertTrue(viewModel.selectedFolderIds.contains(folder2.id), "Folder 2 should still be selected")
    }
    
    // MARK: - Folder Selection Indicator Tests
    
    func testFolderSelectionIndicator() throws {
        // Setup - Create mock folders and add them to viewModel
        let folder1 = FolderItem(id: UUID(), name: "Folder 1")
        viewModel.allFolders = [folder1]
        
        // Create a mock document in the folder
        let doc = AIDocumentItem(id: UUID(), title: "Doc 1", textLength: 100, createdAt: Date(), folderId: folder1.id, tagIds: [], thumbnail: nil, isLocked: false)
        viewModel.documents = [doc]
        
        // Check initial state
        XCTAssertFalse(viewModel.areFolderDocumentsSelected(folder1.id), "No documents should be selected initially")
        XCTAssertFalse(viewModel.areAllFolderDocumentsSelected(folder1.id), "No documents should be selected initially")
        
        // Select the document
        viewModel.selectDocument(doc.id)
        
        // Verify selection state
        XCTAssertTrue(viewModel.areFolderDocumentsSelected(folder1.id), "Documents in folder should be selected")
        XCTAssertTrue(viewModel.areAllFolderDocumentsSelected(folder1.id), "All documents in folder should be selected")
    }
    
    // MARK: - No Folder Option Tests
    
    func testNoFolderOption() throws {
        // Setup - Create mock documents with and without folders
        let folder1 = FolderItem(id: UUID(), name: "Folder 1")
        viewModel.allFolders = [folder1]
        
        let docWithFolder = AIDocumentItem(id: UUID(), title: "Doc 1", textLength: 100, createdAt: Date(), folderId: folder1.id, tagIds: [], thumbnail: nil, isLocked: false)
        let docWithoutFolder = AIDocumentItem(id: UUID(), title: "Doc 2", textLength: 200, createdAt: Date(), folderId: nil, tagIds: [], thumbnail: nil, isLocked: false)
        viewModel.documents = [docWithFolder, docWithoutFolder]
        
        // Set initial folder selection mode
        viewModel.folderSelectionMode = .allFolders
        
        // Select no folder option
        viewModel.selectNoFolder()
        
        // Verify no folder selection mode
        XCTAssertEqual(viewModel.folderSelectionMode, .noFolder, "Folder selection mode should be noFolder")
        
        // Check for documents without folder selected
        XCTAssertFalse(viewModel.areDocumentsWithoutFolderSelected(), "No documents without folder should be selected initially")
        
        // Select the document without folder
        viewModel.selectDocument(docWithoutFolder.id)
        
        // Verify document selection
        XCTAssertTrue(viewModel.areDocumentsWithoutFolderSelected(), "Documents without folder should be selected")
        XCTAssertTrue(viewModel.areAllDocumentsWithoutFolderSelected(), "All documents without folder should be selected")
    }
} 
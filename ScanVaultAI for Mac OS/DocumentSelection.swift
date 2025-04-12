import Foundation
import Combine

/// Manages the selection state of documents in the app
class DocumentSelection: ObservableObject {
    /// The currently selected document ID
    @Published var selectedDocumentId: UUID?
    
    /// The currently selected folder ID
    @Published var selectedFolderId: UUID?
    
    /// Flag indicating whether a document is being viewed
    @Published var isViewingDocument: Bool = false
    
    /// Initialize with default empty selection
    init() {
        // Default initialization with no selection
    }
    
    /// Set the selected document
    /// - Parameter documentId: The UUID of the selected document, or nil to clear selection
    func selectDocument(_ documentId: UUID?) {
        self.selectedDocumentId = documentId
        self.isViewingDocument = documentId != nil
    }
    
    /// Set the selected folder
    /// - Parameter folderId: The UUID of the selected folder, or nil to clear selection
    func selectFolder(_ folderId: UUID?) {
        self.selectedFolderId = folderId
        // When selecting a folder, clear any document selection
        if folderId != nil {
            self.selectedDocumentId = nil
            self.isViewingDocument = false
        }
    }
    
    /// Clear all selections
    func clearSelections() {
        self.selectedDocumentId = nil
        self.selectedFolderId = nil
        self.isViewingDocument = false
    }
} 
import Foundation
import SwiftUI

// MARK: - Folder Selection Type

enum FolderSelectionType: Equatable {
    case allFolders
    case noFolder
    case specificFolder(UUID)
    
    var displayText: String {
        switch self {
        case .allFolders:
            return "All Folders"
        case .noFolder:
            return "< No Folder Assigned >"
        case .specificFolder:
            return "" // Will be replaced with actual folder name
        }
    }
    
    static func == (lhs: FolderSelectionType, rhs: FolderSelectionType) -> Bool {
        switch (lhs, rhs) {
        case (.allFolders, .allFolders):
            return true
        case (.noFolder, .noFolder):
            return true
        case (.specificFolder(let lhsId), .specificFolder(let rhsId)):
            return lhsId == rhsId
        default:
            return false
        }
    }
}

// MARK: - Document List Item

struct DocumentListItem: Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let folderName: String?
    let tagNames: [String]
    let text: String?
    
    // Add a static property that can be swapped in tests for the implementation
    static var isDocumentLockedImpl: (UUID) -> Bool = { documentId in
        DocumentLockManager.shared.isDocumentLocked(documentId)
    }
    
    var isLocked: Bool {
        return DocumentListItem.isDocumentLockedImpl(id)
    }
}

// MARK: - Vault Data Types in Namespace

extension ViewModels_Vault {
    // MARK: - Tag Item
    
    struct TagItem: Identifiable, Hashable {
        let id: UUID
        let name: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: TagItem, rhs: TagItem) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // MARK: - Folder Item
    
    struct FolderItem: Identifiable, Hashable {
        let id: UUID
        let name: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // MARK: - UUID Extensions
    
    static let defaultNoFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
} 
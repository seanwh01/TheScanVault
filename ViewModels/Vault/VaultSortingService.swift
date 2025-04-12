import SwiftUI
import Combine
import Foundation

extension ViewModels_Vault {
    class VaultSortingService {
        // MARK: - Sorting Options
        enum SortOption {
            case date
            case title
            case folder
            
            var description: String {
                switch self {
                case .date: return "Date"
                case .title: return "Title"
                case .folder: return "Folder"
                }
            }
        }
        
        // MARK: - Sorting Properties
        @Published var sortOption: SortOption = .date
        @Published var sortAscending = false
        
        // MARK: - Sorting Methods
        func sortDocuments(_ documents: [DocumentListItem]) -> [DocumentListItem] {
            switch sortOption {
            case .date:
                return documents.sorted { 
                    sortAscending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt 
                }
            case .title:
                return documents.sorted { 
                    sortAscending ? $0.title < $1.title : $0.title > $1.title 
                }
            case .folder:
                return documents.sorted { 
                    let folder1 = $0.folderName ?? ""
                    let folder2 = $1.folderName ?? ""
                    return sortAscending ? folder1 < folder2 : folder1 > folder2
                }
            }
        }
        
        func toggleSortDirection() {
            sortAscending.toggle()
        }
        
        func setSortOption(_ option: SortOption) {
            sortOption = option
        }
    }
} 
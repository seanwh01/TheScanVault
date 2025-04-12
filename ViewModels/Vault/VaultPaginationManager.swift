import SwiftUI
import Combine
import Foundation

extension ViewModels_Vault {
    class VaultPaginationManager {
        // MARK: - Pagination Properties
        @Published var currentPage = 0
        @Published var documentsPerPage = 50
        @Published var isLastPage = false
        @Published var isLoadingMoreDocuments = false
        
        // MARK: - Pagination Methods
        
        func resetPagination() {
            currentPage = 0
            isLastPage = false
        }
        
        func loadNextPage(searchService: VaultSearchService, completion: @escaping () -> Void) {
            guard !isLastPage && !isLoadingMoreDocuments else {
                completion()
                return
            }
            
            isLoadingMoreDocuments = true
            
            // Increment the page number
            currentPage += 1
            
            // Perform the search with the current page
            searchService.searchDocumentsWithFreshContext(
                page: currentPage,
                perPage: documentsPerPage
            ) { [weak self] (_, isLastPage) in
                guard let self = self else { return }
                
                // Update last page flag
                self.isLastPage = isLastPage
                self.isLoadingMoreDocuments = false
                
                completion()
            }
        }
        
        func setDocumentsPerPage(_ count: Int) {
            guard count > 0 else { return }
            documentsPerPage = count
            resetPagination()
        }
    }
} 
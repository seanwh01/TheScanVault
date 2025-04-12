import SwiftUI
import Combine
import Foundation

extension ViewModels_Vault {
    class VaultStateManager {
        // MARK: - UI State Properties
        @Published var isListViewActive = true
        @Published var showSearchBar = false
        @Published var showAdvancedFilters = false
        @Published var isPresentingDocumentDetail = false
        @Published var selectedDocumentId: UUID?
        
        // MARK: - UI State Methods
        
        func toggleViewMode() {
            isListViewActive.toggle()
        }
        
        func toggleSearchBar() {
            showSearchBar.toggle()
            
            // If hiding the search bar, also hide advanced filters
            if !showSearchBar {
                showAdvancedFilters = false
            }
        }
        
        func toggleAdvancedFilters() {
            showAdvancedFilters.toggle()
        }
        
        func showDocumentDetail(documentId: UUID) {
            selectedDocumentId = documentId
            isPresentingDocumentDetail = true
        }
        
        func hideDocumentDetail() {
            isPresentingDocumentDetail = false
            selectedDocumentId = nil
        }
        
        // MARK: - CloudKit State
        
        func checkCloudKitAvailability() {
            // Use CloudSyncManager's shared instance to check account status
            // for consistent container usage
            CloudSyncManager.shared.checkCloudAvailability(retryCount: 2)
        }
    }
} 
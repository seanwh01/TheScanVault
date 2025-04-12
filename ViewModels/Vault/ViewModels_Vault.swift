import SwiftUI
import CoreData
import Combine
import CloudKit
import Foundation

/// Namespace for VaultViewModel components to prevent naming conflicts
enum ViewModels_Vault {
    // This is a namespace to group all related components

    // MARK: - Main VaultViewModel Implementation
    
    class VaultViewModel: ObservableObject {
        // Core properties
        private(set) var documentLockManager = DocumentLockManager.shared
        private(set) var persistenceController: PersistenceController
        var viewContext: NSManagedObjectContext {
            return persistenceController.container.viewContext
        }
        
        // Published properties for UI state
        @Published var documents: [DocumentListItem] = []
        @Published var isLoading = false
        @Published var refreshCounter = 0
        @Published var forceRefreshTrigger = UUID()
        
        // Search services
        let searchService: VaultSearchService
        let filterService: VaultFilterService
        let sortingService: VaultSortingService
        let documentManager: VaultDocumentManager
        let paginationManager: VaultPaginationManager
        let stateManager: VaultStateManager
        
        // MARK: - Initialization
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
            
            // Initialize services with the persistence controller
            self.searchService = VaultSearchService(persistenceController: persistenceController)
            self.filterService = VaultFilterService(persistenceController: persistenceController)
            self.sortingService = VaultSortingService()
            self.documentManager = VaultDocumentManager(persistenceController: persistenceController)
            self.paginationManager = VaultPaginationManager()
            self.stateManager = VaultStateManager()
            
            // Setup the services
            setupServices()
            setupNotifications()
        }
        
        init() {
            self.persistenceController = PersistenceController.shared
            
            // Initialize services with the shared persistence controller
            self.searchService = VaultSearchService(persistenceController: persistenceController)
            self.filterService = VaultFilterService(persistenceController: persistenceController)
            self.sortingService = VaultSortingService()
            self.documentManager = VaultDocumentManager(persistenceController: persistenceController)
            self.paginationManager = VaultPaginationManager()
            self.stateManager = VaultStateManager()
            
            // Setup the services
            setupServices()
            setupNotifications()
        }
        
        // MARK: - Setup Methods
        
        private func setupServices() {
            // Connect the services to each other
            searchService.setupBindings(
                filterService: filterService,
                sortingService: sortingService,
                documentManager: documentManager
            )
            
            // Set up publisher subscriptions
            setupPublisherSubscriptions()
        }
        
        private func setupPublisherSubscriptions() {
            // Subscribe to search results
            searchService.documentsPublisher
                .sink { [weak self] documents in
                    self?.documents = documents
                    self?.isLoading = false
                }
                .store(in: &searchService.cancellables)
            
            // Subscribe to loading state
            searchService.isLoadingPublisher
                .sink { [weak self] isLoading in
                    self?.isLoading = isLoading
                }
                .store(in: &searchService.cancellables)
        }
        
        private func setupNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refreshDocuments),
                name: NSNotification.Name("RefreshVaultDocuments"),
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(documentAdded(_:)),
                name: NSNotification.Name("DocumentAdded"),
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(documentUpdated(_:)),
                name: NSNotification.Name("DocumentUpdated"),
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(documentFolderChanged(_:)),
                name: NSNotification.Name("DocumentFolderChanged"),
                object: nil
            )
        }
        
        // MARK: - Notification Handlers
        
        @objc private func refreshDocuments() {
            searchService.performSearch()
        }
        
        @objc private func documentAdded(_ notification: Notification) {
            if let documentId = notification.userInfo?["documentId"] as? UUID {
                print("Document added with ID: \(documentId)")
                searchService.performSearch()
            }
        }
        
        @objc private func documentUpdated(_ notification: Notification) {
            if let documentId = notification.userInfo?["documentId"] as? UUID {
                print("Document updated notification received for ID: \(documentId)")
                searchService.searchDocumentsWithFreshContext()
            }
        }
        
        @objc private func documentFolderChanged(_ notification: Notification) {
            if let documentId = notification.userInfo?["documentId"] as? UUID {
                print("Document folder change notification received for ID: \(documentId)")
                
                // Clear folder filters
                if filterService.folderSelectionType != .allFolders {
                    filterService.folderSelectionType = .allFolders
                    filterService.selectedFolder = nil
                }
                
                // Perform search with fresh context
                searchService.searchDocumentsWithFreshContext()
            }
        }
        
        // MARK: - Public Methods
        
        // Method to fetch all metadata
        func fetchAllTagsAndFolders() {
            filterService.fetchAllTags()
            filterService.fetchAllFolders()
        }
        
        // Method to refresh all data
        func refreshAllData() {
            isLoading = true
            viewContext.refreshAllObjects()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                
                self.filterService.forceRefreshMetadata()
                self.searchService.performSearch()
                self.filterService.cleanupSelectedTags()
                
                self.isLoading = false
            }
        }
        
        // MARK: - Document Lock Methods
        
        // Document lock methods forwarded to document lock manager
        func hasDocumentLock() -> Bool {
            return documentLockManager.hasDocumentLock()
        }
        
        func isDocumentLocked(_ documentId: UUID) -> Bool {
            return documentLockManager.isDocumentLocked(documentId)
        }
        
        func verifyDocumentLockPassword(_ password: String, for documentId: UUID? = nil) -> Bool {
            return documentLockManager.verifyDocumentLockPassword(password)
        }
        
        func lockDocument(_ documentId: UUID) {
            documentLockManager.lockDocument(documentId)
        }
        
        func unlockDocument(_ documentId: UUID) {
            documentLockManager.unlockDocument(documentId)
        }
        
        func toggleDocumentLock(_ documentId: UUID) {
            if isDocumentLocked(documentId) {
                unlockDocument(documentId)
            } else {
                lockDocument(documentId)
            }
        }
        
        func forceRefreshDocumentLockStates() {
            print("🔄 VaultViewModel: Force refreshing document lock states")
            documentLockManager.forceRefreshDocumentLockState()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.forceRefreshTrigger = UUID()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                self.forceRefreshTrigger = UUID()
            }
        }
        
        func verifyAndUnlockDocument(_ password: String, documentId: UUID) -> Bool {
            if verifyDocumentLockPassword(password) {
                unlockDocument(documentId)
                return true
            }
            return false
        }
        
        func refreshDocumentsAfterLockChange() {
            print("🔄 Refreshing documents after lock state change")
            forceRefreshTrigger = UUID()
            searchService.refreshDataWithoutNavigation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.searchService.searchDocumentsWithFreshContext()
            }
        }
        
        func isFolderLocked(_ folderName: String) -> Bool {
            return documentLockManager.isFolderLocked(folderName)
        }
    }
} 
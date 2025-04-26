import SwiftUI
import CoreData
import Combine
import CloudKit
import Foundation

// This file serves as a proxy for the refactored VaultViewModel
// Maintaining backward compatibility with existing code
class VaultViewModel: ObservableObject {
    // Reference to the actual implementation
    private let implementation: ViewModels_Vault.VaultViewModel
    
    // MARK: - Forward properties
    
    var persistenceController: PersistenceController {
        return implementation.persistenceController
    }
    
    var viewContext: NSManagedObjectContext {
        return implementation.viewContext
    }
    
    var documentLockManager: DocumentLockManager {
        return implementation.documentLockManager
    }
    
    // MARK: - Published properties forwarding
    
    @Published var documents: [DocumentListItem] = []
    @Published var isLoading = false
    
    // Date filter properties
    @Published var fromDate: Date {
        didSet { implementation.filterService.fromDate = fromDate }
    }
    
    @Published var toDate: Date {
        didSet { implementation.filterService.toDate = toDate }
    }
    
    @Published var isDateFilterActive: Bool {
        didSet { implementation.filterService.isDateFilterActive = isDateFilterActive }
    }
    
    @Published var isSelectingFromDate: Bool {
        didSet { implementation.filterService.isSelectingFromDate = isSelectingFromDate }
    }
    
    @Published var showDatePicker: Bool {
        didSet { implementation.filterService.showDatePicker = showDatePicker }
    }
    
    // Search filter properties
    @Published var searchTitle: String {
        didSet { implementation.filterService.searchTitle = searchTitle }
    }
    
    @Published var searchText: String {
        didSet { implementation.filterService.searchText = searchText }
    }
    
    @Published var searchOCRText: String {
        didSet { implementation.filterService.searchOCRText = searchOCRText }
    }
    
    // Tag filter properties
    @Published var selectedTags: Set<UUID> {
        didSet { implementation.filterService.selectedTags = selectedTags }
    }
    
    @Published var showNoTagsOption: Bool {
        didSet { implementation.filterService.showNoTagsOption = showNoTagsOption }
    }
    
    @Published var allTags: [ViewModels_Vault.TagItem] = []
    
    // Folder filter properties
    @Published var selectedFolder: UUID? {
        didSet { implementation.filterService.selectedFolder = selectedFolder }
    }
    
    @Published var folderSelectionType: FolderSelectionType {
        didSet { implementation.filterService.folderSelectionType = folderSelectionType }
    }
    
    @Published var selectedFolderIds: Set<UUID> {
        didSet { implementation.filterService.selectedFolderIds = selectedFolderIds }
    }
    
    @Published var showNoFolderDocuments: Bool {
        didSet { implementation.filterService.showNoFolderDocuments = showNoFolderDocuments }
    }
    
    @Published var showFolderOptions: Bool {
        didSet { implementation.filterService.showFolderOptions = showFolderOptions }
    }
    
    @Published var allFolders: [ViewModels_Vault.FolderItem] = []
    
    // Latest document properties
    @Published var showLatestOnly: Bool {
        didSet { implementation.filterService.showLatestOnly = showLatestOnly }
    }
    
    @Published var latestDocumentId: UUID? {
        didSet { implementation.filterService.latestDocumentId = latestDocumentId }
    }
    
    @Published var forceShowNewestDocument: Bool {
        didSet { implementation.filterService.forceShowNewestDocument = forceShowNewestDocument }
    }
    
    // Refresh properties
    @Published var refreshCounter: Int {
        didSet { implementation.refreshCounter = refreshCounter }
    }
    
    @Published var forceRefreshTrigger: UUID {
        didSet { implementation.forceRefreshTrigger = forceRefreshTrigger }
    }
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController) {
        // Create the actual implementation
        self.implementation = ViewModels_Vault.VaultViewModel(persistenceController: persistenceController)
        
        // Initialize all published properties
        self.fromDate = self.implementation.filterService.fromDate
        self.toDate = self.implementation.filterService.toDate
        self.searchTitle = ""
        self.searchText = ""
        self.searchOCRText = ""
        self.selectedTags = []
        self.selectedFolder = nil
        self.folderSelectionType = .allFolders
        self.selectedFolderIds = []
        self.showNoFolderDocuments = false
        self.showFolderOptions = false
        self.showDatePicker = false
        self.isSelectingFromDate = true
        self.showNoTagsOption = false
        self.showLatestOnly = false
        self.latestDocumentId = nil
        self.forceShowNewestDocument = false
        self.isDateFilterActive = false
        self.refreshCounter = 0
        self.forceRefreshTrigger = UUID()
        
        // Setup subscribers to update the proxy properties
        setupSubscribers()
    }
    
    private func setupSubscribers() {
        // Subscribe to documents updates from the real implementation
        implementation.$documents
            .receive(on: DispatchQueue.main) // Ensure updates on main thread
            .sink { [weak self] documents in
                print("Proxy received \(documents.count) documents")
                // Directly assign for initial load/full refresh triggered by implementation's publisher
                // loadMoreDocuments will handle appending manually.
                self?.documents = documents
            }
            // Store cancellable in the implementation's store, or create a new one here
            .store(in: &implementation.searchService.cancellables) // Assuming SearchService holds cancellables
        
        // Subscribe to loading state
        implementation.$isLoading
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            // Store cancellable in the implementation's store, or create a new one here
            .store(in: &implementation.searchService.cancellables) // Assuming SearchService holds cancellables
        
        // Subscribe to tag updates
        implementation.filterService.$allTags
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tags in
                self?.allTags = tags
            }
            // Store cancellable in the implementation's store, or create a new one here
            .store(in: &implementation.searchService.cancellables) // Assuming SearchService holds cancellables
        
        // Subscribe to folder updates
        implementation.filterService.$allFolders
            .receive(on: DispatchQueue.main)
            .sink { [weak self] folders in
                self?.allFolders = folders
            }
            // Store cancellable in the implementation's store, or create a new one here
            .store(in: &implementation.searchService.cancellables) // Assuming SearchService holds cancellables
    }
    
    // MARK: - Method Forwarding
    
    // Document retrieval method needed by DocumentResultsView
    func fetchDocument(_ id: UUID) -> Document? {
        return implementation.documentManager.fetchDocument(id)
    }
    
    // Search and filter methods
    
    func fetchAllTagsAndFolders() {
        implementation.fetchAllTagsAndFolders()
    }
    
    func searchDocuments() {
        implementation.searchService.performSearch()
    }
    
    func searchDocumentsWithFreshContext(page: Int = 0, perPage: Int = 50, completion: @escaping ([DocumentListItem], Bool) -> Void = {_, _ in }) {
        implementation.searchService.searchDocumentsWithFreshContext(page: page, perPage: perPage, completion: completion)
    }
    
    func searchDocumentsWithFreshContext() {
        print("Proxy: Triggering searchDocumentsWithFreshContext (page 0)")
        // Call the implementation's method. Assuming results are handled by the publisher.
        // Use a large page size to simulate fetching 'all' for a refresh.
        // Let the publisher handle updating self.documents for a full refresh.
        implementation.searchService.searchDocumentsWithFreshContext(page: 0, perPage: 1000) { _, _ in
            // Completion handler might not be needed if publisher updates the list
            print("Proxy: searchDocumentsWithFreshContext completion received (results updated via publisher)")
        }
    }
    
    func loadMoreDocuments(currentPage: Int, documentsPerPage: Int, completion: @escaping (Bool) -> Void) {
        let nextPage = currentPage + 1
        print("Proxy: Triggering loadMoreDocuments (requesting page \(nextPage))")
        isLoading = true // Manually set loading true for pagination
        implementation.searchService.searchDocumentsWithFreshContext(page: nextPage, perPage: documentsPerPage) { [weak self] (newItems, allLoaded) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("Proxy: Received \(newItems.count) new items for page \(nextPage). All loaded: \(allLoaded)")
                // Append new items to the existing list
                self.documents.append(contentsOf: newItems)
                self.isLoading = false // Turn off loading indicator
                completion(allLoaded) // Notify the view if all documents are loaded
            }
        }
    }
    
    func toggleNoTagsOption() {
        implementation.filterService.toggleNoTagsOption()
    }
    
    func toggleTag(_ tag: ViewModels_Vault.TagItem) {
        implementation.filterService.toggleTag(tag)
    }
    
    func clearFilters() {
        implementation.filterService.clearFilters()
    }
    
    func fetchAllTags() {
        implementation.filterService.fetchAllTags()
    }
    
    func fetchAllFolders() {
        implementation.filterService.fetchAllFolders()
    }
    
    func fetchDocuments() {
        implementation.searchService.performSearch()
    }
    
    // Folder methods
    
    func resetFolderSelection() {
        implementation.filterService.resetFolderSelection()
    }
    
    func selectNoFolder() {
        implementation.filterService.selectNoFolder()
    }
    
    func selectFolder(_ folderId: UUID) {
        implementation.filterService.selectFolder(folderId)
    }
    
    func toggleFolderSelection(_ folderId: UUID) {
        implementation.filterService.toggleFolderSelection(folderId)
    }
    
    func selectAllFolders() {
        // Add all folder IDs to selection
        selectedFolderIds.removeAll()
        allFolders.forEach { folder in
            selectedFolderIds.insert(folder.id)
        }
    }
    
    func deselectAllFolders() {
        // Clear all folder selections
        selectedFolderIds.removeAll()
    }
    
    // Refresh methods
    
    func forceRefreshMetadata() {
        implementation.filterService.forceRefreshMetadata()
    }
    
    func refreshAllData() {
        implementation.refreshAllData()
    }
    
    func cleanupSelectedTags() {
        implementation.filterService.cleanupSelectedTags()
    }
    
    func forceRefreshAllMetadata() {
        implementation.filterService.forceRefreshMetadata()
    }
    
    func refreshDataWithoutNavigation() {
        implementation.searchService.refreshDataWithoutNavigation()
    }
    
    // Document management methods
    
    func checkIfDocumentExists(id: UUID) -> Bool {
        return implementation.documentManager.checkIfDocumentExists(id: id)
    }
    
    func deleteDocument(_ id: UUID) {
        implementation.documentManager.deleteDocument(id)
    }
    
    func forceShowLatestDocuments() {
        // This functionality lets the view force-load the most recent documents
        // Reset filters and set up to show latest documents
        clearFilters()
        showLatestOnly = false
        
        // Force refresh documents with fresh context
        searchDocumentsWithFreshContext()
        
        // For insurance, do a second refresh after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshDataWithoutNavigation()
        }
    }
    
    // Document lock methods
    
    func hasDocumentLock() -> Bool {
        return implementation.hasDocumentLock()
    }
    
    func isDocumentLocked(_ documentId: UUID) -> Bool {
        return implementation.isDocumentLocked(documentId)
    }
    
    func verifyDocumentLockPassword(_ password: String, for documentId: UUID? = nil) -> Bool {
        return implementation.verifyDocumentLockPassword(password, for: documentId)
    }
    
    func lockDocument(_ documentId: UUID) {
        implementation.lockDocument(documentId)
    }
    
    func unlockDocument(_ documentId: UUID) {
        implementation.unlockDocument(documentId)
    }
    
    func toggleDocumentLock(_ documentId: UUID) {
        implementation.toggleDocumentLock(documentId)
    }
    
    func forceRefreshDocumentLockStates() {
        implementation.forceRefreshDocumentLockStates()
    }
    
    func verifyAndUnlockDocument(_ password: String, documentId: UUID) -> Bool {
        return implementation.verifyAndUnlockDocument(password, documentId: documentId)
    }
    
    func refreshDocumentsAfterLockChange() {
        implementation.refreshDocumentsAfterLockChange()
    }
    
    func isFolderLocked(_ folderName: String) -> Bool {
        return implementation.isFolderLocked(folderName)
    }
    
    // Utility methods
    
    func printFolderDistribution() {
        implementation.filterService.printFolderDistribution()
    }
    
    func cleanupOCRInComments() {
        implementation.documentManager.cleanupOCRInComments()
    }
    
    func moveAllOCRFromCommentsToTextField() {
        implementation.documentManager.moveAllOCRFromCommentsToTextField()
    }
    
    func checkOCRTextAvailability() {
        implementation.documentManager.checkOCRTextAvailability()
    }
    
    func checkDocumentsInFolder(folderId: UUID?) {
        implementation.documentManager.checkDocumentsInFolder(folderId: folderId)
    }
    
    func checkCloudKitAvailability() {
        implementation.stateManager.checkCloudKitAvailability()
    }
}
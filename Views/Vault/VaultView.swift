import SwiftUI
import CoreData
import UIKit

struct VaultView: View {
    @StateObject private var viewModel: VaultViewModel
    @State private var showResults = false
    @State private var showDateRangeOptions = false
    @State private var showTagsOptions = false
    @State private var showFolderOptions = false
    @State private var hasAppeared = false
    @State private var isRefreshing = false
    @State private var hasRefreshed = false
    @State private var areNotificationsPaused = false
    @State private var showDocumentLockAlert = false
    @State private var showDocumentLockSetupPrompt = false
    @State private var showPasswordVerification = false
    @State private var documentLockPassword = ""
    @State private var selectedDocument: Document?
    @State private var documentToLock: DocumentItem?
    @State private var showLockError = false
    @State private var lockErrorMessage = ""
    @State private var showLockSuccessAlert = false
    @State private var lockSuccessMessage = ""
    @State private var showingPasswordPrompt = false
    @State private var selectedDocumentId: UUID?
    @State private var passwordInput = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var passwordError = false
    @State private var documentToOpen: Document? = nil
    
    // Constants for consistent styling
    private let cornerRadius: CGFloat = 12
    private let fieldHeight: CGFloat = 50
    
    // Add this to the VaultView struct at the top level
    // This will ensure we stop the loading indicator after a fixed time
    private let loadingTimeout = 2.0 // 2 seconds max loading time
    
    // State variables for controlling sheet presentation
    @State private var showDocumentDetailSheet = false
    @State private var showDocumentOpenSheet = false
    
    // Add back the pagination variables that were removed
    @State private var showDebugOptions = false
    @State private var isLoadingMoreDocuments = false
    @State private var currentPage = 0
    @State private var allDocumentsLoaded = false
    
    init() {
        self._viewModel = StateObject(wrappedValue: VaultViewModel())
    }
    
    var body: some View {
        NavigationView {
            // Main content
            mainContent
        }
        // External sheets and alerts
        .sheet(isPresented: $showDocumentDetailSheet) {
            buildDocumentDetailSheet()
        }
        .alert("Incorrect Password", isPresented: $passwordError) {
            Button("OK", role: .cancel) { 
                passwordInput = ""
            }
        } message: {
            Text("The password you entered is incorrect. Please try again.")
        }
        .onChange(of: showingPasswordPrompt) { _, newValue in
            if newValue {
                handlePasswordSubmit()
            }
        }
        .onChange(of: viewModel.selectedFolderIds) { _, newValue in
            print("Selected folders changed to \(newValue.count)")
            print("Current selection: \(newValue)")
        }
        .sheet(isPresented: $showDocumentOpenSheet) {
            buildDocumentOpenSheet()
        }
    }
    
    // MARK: - View Components
    
    // Main ZStack content
    private var mainContent: some View {
        ZStack {
            // Background
            Color.black
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissKeyboard()
                }
            
            // Main scroll content
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header view
                    VaultHeaderView(hasRefreshed: $hasRefreshed)
                    
                    // Search fields
                    buildSearchFieldsView()
                    
                    Spacer(minLength: 10)
                    
                    // Apply button
                    buildApplyButtonView()
                }
                .onTapGesture {
                    dismissKeyboard()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showDatePicker) {
            buildDatePickerSheet()
        }
        .onAppear {
            setupOnAppear()
        }
        .onDisappear {
            handleOnDisappear()
        }
        .fullScreenCover(isPresented: $showResults) {
            DocumentResultsView(viewModel: viewModel, isPresented: $showResults)
        }
        // Apply notification handlers
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentAdded"))) { notification in
            handleDocumentAddedNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentUpdated"))) { notification in
            handleDocumentUpdatedNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentTitleUpdated"))) { notification in
            handleDocumentTitleUpdatedNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PauseDocumentNotifications"))) { notification in
            handlePauseDocumentNotificationsNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentLockSetupRequired"))) { notification in
            handleDocumentLockSetupRequiredNotification(notification)
        }
        // Apply alerts
        .alert("Document Lock Setup Required", isPresented: $showDocumentLockSetupPrompt) {
            Button("Cancel", role: .cancel) {
                documentToLock = nil
            }
            Button("Setup Lock") {
                // Navigate to settings
                // You'll need to implement this navigation
            }
        } message: {
            Text("Please set up a document lock password in Settings before locking documents.")
        }
        .alert("Incorrect Password", isPresented: $showLockError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(lockErrorMessage)
        }
        .sheet(isPresented: $showPasswordVerification) {
            buildPasswordVerificationSheet()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Builder Methods
    
    @ViewBuilder
    private func buildSearchFieldsView() -> some View {
        VaultSearchFieldsView(
            viewModel: viewModel,
            showDateRangeOptions: $showDateRangeOptions,
            showTagsOptions: $showTagsOptions,
            showFolderOptions: $showFolderOptions,
            cornerRadius: cornerRadius
        )
    }
    
    @ViewBuilder
    private func buildApplyButtonView() -> some View {
        ApplyButtonView(
            viewModel: viewModel,
            showResults: $showResults
        )
    }
    
    @ViewBuilder
    private func buildDatePickerSheet() -> some View {
        DatePickerSheet(
            date: viewModel.isSelectingFromDate ? $viewModel.fromDate : $viewModel.toDate,
            isPresented: $viewModel.showDatePicker,
            title: viewModel.isSelectingFromDate ? "Select From Date" : "Select To Date",
            onComplete: { }
        )
    }
    
    @ViewBuilder
    private func buildDocumentDetailSheet() -> some View {
        if let document = selectedDocument, let documentId = document.id ?? document.entityId {
            DocumentDetailView(viewModel: DocumentViewModel(document: document), documentId: documentId)
        }
    }
    
    @ViewBuilder
    private func buildDocumentOpenSheet() -> some View {
        if let document = documentToOpen, let documentId = document.id ?? document.entityId {
            NavigationView {
                DocumentDetailView(
                    viewModel: DocumentViewModel(document: document),
                    documentId: documentId
                )
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            documentToOpen = nil
                            showDocumentOpenSheet = false
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Search Results")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    // MARK: - Helper Methods
    
    // Setup method executed when view appears
    private func setupOnAppear() {
        // First make sure loading state is reset
        viewModel.isLoading = false
        hasRefreshed = false
        
        // Then force immediate refresh of tags and folders
        refreshData()
        
        // Set up notification observer
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshVaultDocuments"),
            object: nil,
            queue: .main
        ) { _ in
            print("📣 Notification received - refreshing data")
            self.refreshData()
        }
    }
    
    // Cleanup when view disappears
    private func handleOnDisappear() {
        // Remove observer when view disappears
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("RefreshVaultDocuments"),
            object: nil
        )
        
        // Reset appeared state to ensure refresh happens next time
        hasAppeared = false
    }
    
    // Handle document added notification
    private func handleDocumentAddedNotification(_ notification: Notification) {
        if let documentId = notification.userInfo?["documentId"] as? UUID {
            print("VaultView: Document added notification received for ID: \(documentId)")
            
            // Reset all search criteria to ensure the document is visible
            viewModel.clearFilters()
            
            // Force a search with fresh context
            viewModel.searchDocumentsWithFreshContext()
            
            // Show the results view if not already showing
            if !showResults {
                showResults = true
            }
            
            // For extra insurance, do one more search after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                print("🔄 VaultView: Performing delayed follow-up search")
                self.viewModel.searchDocumentsWithFreshContext()
            }
        }
    }
    
    // Handle document updated notification
    private func handleDocumentUpdatedNotification(_ notification: Notification) {
        // If notifications are paused, don't process this notification
        if areNotificationsPaused {
            print("⏸️ Document update notification received but ignored (notifications paused)")
            return
        }

        // Check for flags
        let isSilentUpdate = notification.userInfo?["silentUpdate"] as? Bool ?? false
        let preventNavigation = notification.userInfo?["preventNavigation"] as? Bool ?? false
        
        if let documentId = notification.userInfo?["documentId"] as? UUID {
            print("📝 Document updated notification received for ID: \(documentId)")
            
            // Don't navigate if preventNavigation flag is set
            if !isSilentUpdate && !preventNavigation {
                // Show the results view if not already showing
                if !showResults {
                    showResults = true
                }
                
                // Refresh the data
                refreshData()
            } else {
                // For silent updates, just refresh data without changing navigation
                viewModel.refreshDataWithoutNavigation()
            }
        }
    }
    
    // Refresh data method
    private func refreshData() {
        print("🔄 VaultView: Starting full data refresh")
        
        // First clear the state to ensure clean refresh
        viewModel.isLoading = false
        hasRefreshed = false
        
        // Use the new powerful refresh method
        viewModel.forceShowLatestDocuments()
        
        // Then refresh metadata
        viewModel.forceRefreshAllMetadata()
        
        // Always set hasRefreshed to true after a delay to ensure loading indicator disappears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hasRefreshed = true
        }
    }
    
    // Check if document lock is set up
    private func hasDocumentLock() -> Bool {
        return viewModel.hasDocumentLock()
    }

    // Handle document locking
    private func toggleDocumentLock(for documentId: UUID) {
        viewModel.toggleDocumentLock(documentId)
    }

    // Verify document lock password
    private func verifyDocumentLockPassword() {
        if let document = selectedDocument,
           viewModel.verifyDocumentLockPassword(documentLockPassword, for: document.id) {
            showPasswordVerification = false
            documentLockPassword = ""
        } else {
            showLockError = true
            lockErrorMessage = "Incorrect password. Please try again."
            documentLockPassword = ""
        }
    }

    // Helper to get folder name for a document
    private func getFolderName(for document: DocumentItem) -> String? {
        guard let folderId = document.folderId else { return nil }
        return viewModel.allFolders.first(where: { $0.id == folderId })?.name
    }

    // Helper to get tags text for a document
    private func getTagsText(for document: DocumentItem) -> String {
        return document.tagIds.compactMap { tagId in
            viewModel.allTags.first(where: { $0.id == tagId })?.name
        }.joined(separator: ", ")
    }

    // Handle document tap
    private func handleDocumentTap(_ documentId: UUID) {
        if let document = viewModel.fetchDocument(documentId) {
            if viewModel.isDocumentLocked(documentId) {
                showPasswordPrompt(for: documentId)
            } else {
                selectedDocument = document
                showDocumentDetailSheet = true
            }
        }
    }

    // Handle password submit
    private func handlePasswordSubmit() {
        guard let documentId = selectedDocumentId else {
            return
        }
        
        if viewModel.verifyDocumentLockPassword(passwordInput, for: documentId) {
            showingPasswordPrompt = false
            passwordInput = ""
            if let document = viewModel.fetchDocument(documentId) {
                selectedDocument = document
                showDocumentDetailSheet = true
            }
        } else {
            // Show error alert
            showingPasswordPrompt = false
            passwordInput = ""
            passwordError = true
        }
    }

    // Show password prompt
    private func showPasswordPrompt(for documentId: UUID) {
        selectedDocumentId = documentId
        showingPasswordPrompt = true
    }

    // Delete document
    private func deleteDocument(_ document: DocumentItem) {
        viewModel.deleteDocument(document.id)
    }

    // Handle document lock notification
    private func handleDocumentLockNotification(_ notification: Notification) {
        lockSuccessMessage = "Document has been locked successfully"
        showLockSuccessAlert = true
    }

    // Handle document unlock notification
    private func handleDocumentUnlockNotification(_ notification: Notification) {
        lockSuccessMessage = "Document has been unlocked successfully"
        showLockSuccessAlert = true
    }
    
    // Dismiss keyboard
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handleDocumentLockSetupRequiredNotification(_ notification: Notification) {
        if let documentId = notification.userInfo?["documentId"] as? UUID {
            showDocumentLockSetupPrompt = true
            // Create a temporary DocumentItem for the UI
            let documentTitle = viewModel.documents.first(where: { $0.id == documentId })?.title ?? ""
            documentToLock = DocumentItem(
                id: documentId,
                title: documentTitle,
                createdAt: Date(),
                folderId: nil,
                tagIds: [],
                thumbnail: nil,
                aiModelUsed: nil
            )
        }
    }
    
    @ViewBuilder
    private func buildPasswordVerificationSheet() -> some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Enter Document Lock Password", text: $documentLockPassword)
                        .textContentType(.password)
                }
                
                Section {
                    Button("Unlock Document") {
                        verifyDocumentLockPassword()
                    }
                    .disabled(documentLockPassword.isEmpty)
                }
            }
            .navigationTitle("Unlock Document")
            .navigationBarItems(trailing: Button("Cancel") {
                showPasswordVerification = false
                documentLockPassword = ""
            })
        }
    }
    
    // Additional notification handlers
    private func handleDocumentTitleUpdatedNotification(_ notification: Notification) {
        if let documentId = notification.userInfo?["documentId"] as? UUID,
           let newTitle = notification.userInfo?["newTitle"] as? String {
            print("📄 Title update notification received for document \(documentId): \(newTitle)")
            
            // Don't navigate if preventNavigation flag is set
            let preventNavigation = notification.userInfo?["preventNavigation"] as? Bool ?? false
            
            // Force a complete refresh of the documents list, but don't show results unless requested
            if !preventNavigation {
                // Only refresh documents but don't navigate
                viewModel.forceShowLatestDocuments()
            } else {
                // Use a simpler approach that doesn't require a new method
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Just update the document list without changing navigation
                    print("🔄 Performing delayed refresh after title update")
                    viewModel.refreshDataWithoutNavigation()
                }
            }
        }
    }
    
    private func handlePauseDocumentNotificationsNotification(_ notification: Notification) {
        if let pauseDuration = notification.userInfo?["pauseDuration"] as? Double {
            // Set the pause state
            areNotificationsPaused = true
            
            // After the duration, re-enable notifications
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                areNotificationsPaused = false
                print("✅ Document notifications resumed")
            }
        }
    }
} 
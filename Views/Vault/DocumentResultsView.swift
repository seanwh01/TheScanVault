import SwiftUI
import CoreData
import PDFKit

// MARK: - Document Results View
struct DocumentResultsView: View {
    @ObservedObject var viewModel: VaultViewModel
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var showLoadingTimeout = false
    @State private var hasLoadedOnce = false
    @State private var expandedFolders: Set<String> = Set()
    @State private var refreshObserver: NSObjectProtocol? = nil
    @State private var showDocumentLockSetupPrompt = false
    @State private var showPasswordVerification = false
    @State private var documentLockPassword = ""
    @State private var selectedDocument: DocumentListItem?
    @State private var documentToLock: DocumentListItem?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var lockSuccessMessage = ""
    @State private var showLockSuccessAlert = false
    @State private var showLockError = false
    @State private var lockErrorMessage = ""
    @State private var documentToOpen: Document? = nil
    @State private var showDocumentOpenSheet = false
    @State private var forceRefreshTrigger = UUID()
    @State private var documentViewModels: [UUID: DocumentViewModel] = [:]
    
    // Add the missing variables for pagination
    @State private var showDebugOptions = false
    @State private var isLoadingMoreDocuments = false
    @State private var currentPage = 0
    @State private var allDocumentsLoaded = false
    
    let persistenceController: PersistenceController // Add property
    
    private let cornerRadius: CGFloat = 12
    private let maxLoadingTime: Double = 5.0
    private let documentsPerPage = 10  // Number of documents to load at a time
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading && !hasLoadedOnce {
                    loadingView
                } else if showLoadingTimeout {
                    timeoutView
                } else if viewModel.documents.isEmpty {
                    emptyResultsView
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        // Document count now appears here
                        Text("\(viewModel.documents.count) documents")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        
                        documentListView
                    }
                }
            }
            .navigationBarItems(
                leading: backButton,
                trailing: HStack {
                    // Removed document count from here
                    Button(action: {
                        // Refresh the search
                        currentPage = 0
                        allDocumentsLoaded = false
                        viewModel.searchDocumentsWithFreshContext()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
            )
            .navigationBarTitle("Search Results", displayMode: .inline)
            .alert(isPresented: $showLockError) {
                Alert(
                    title: Text("Document Lock Error"),
                    message: Text(lockErrorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showLockSuccessAlert) {
                Alert(
                    title: Text("Success"),
                    message: Text(lockSuccessMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showPasswordVerification) {
                passwordVerificationSheet
            }
            .sheet(isPresented: $showDocumentOpenSheet) {
                documentDetailSheet
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - View Components
    
    // Loading view
    private var loadingView: some View {
        VStack {
            ProgressView("Searching documents...")
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .padding()
                .onAppear {
                    // Set a timeout to stop showing loading indicator
                    DispatchQueue.main.asyncAfter(deadline: .now() + maxLoadingTime) {
                        if viewModel.isLoading {
                            viewModel.isLoading = false
                            showLoadingTimeout = true
                        }
                    }
                }
        }
    }
    
    // Timeout view
    private var timeoutView: some View {
        VStack {
            Text("Search is taking longer than expected.")
                .foregroundColor(.white)
            Text("You can continue waiting or try a different search.")
                .foregroundColor(.gray)
                .padding(.top, 4)
            
            Button("Cancel Search") {
                isPresented = false
            }
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.top, 16)
        }
        .padding()
    }
    
    // Empty results view
    private var emptyResultsView: some View {
        VStack {
            Text("No Documents Found")
                .font(.title2)
                .foregroundColor(.white)
            Text("Try adjusting your search criteria.")
                .foregroundColor(.gray)
                .padding(.top, 4)
                
            Button("Back to Search") {
                isPresented = false
            }
            .padding()
            .background(Color.blue.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.top, 16)
        }
        .padding()
    }
    
    // Document list view
    private var documentListView: some View {
        List {
            ForEach(sortedFolderNames, id: \.self) { folderName in
                Section(header: folderHeaderView(folderName)) {
                    if expandedFolders.contains(folderName) {
                        ForEach(documentsByFolder[folderName] ?? []) { document in
                            DocumentRow(
                                document: document,
                                folderName: document.folderName,
                                onDelete: {
                                    deleteDocument(document)
                                },
                                onLock: {
                                    handleLockDocument(document)
                                },
                                onTap: {
                                    handleDocumentTap(document)
                                }
                            )
                        }
                    }
                }
            }
            
            // Add load more button if not all documents are loaded
            if !allDocumentsLoaded && !viewModel.documents.isEmpty {
                loadMoreButtonSection
            }
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            // By default, all folders are expanded
            expandedFolders = Set(sortedFolderNames)
            hasLoadedOnce = true
            
            // Set up notification observer
            refreshObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshVaultDocuments"),
                object: nil,
                queue: .main
            ) { _ in
                print("📣 DocumentResultsView: Notification received - refreshing data")
                // Reset pagination state
                currentPage = 0
                allDocumentsLoaded = false
                // Perform a fresh search
                viewModel.searchDocumentsWithFreshContext()
            }
        }
        .onDisappear {
            // Clean up observer when view disappears
            if let observer = refreshObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    // Folder header view
    private func folderHeaderView(_ folderName: String) -> some View {
        Button(action: {
            toggleFolderExpansion(folderName)
        }) {
            HStack {
                Text(folderName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: expandedFolders.contains(folderName) ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Load more button section
    private var loadMoreButtonSection: some View {
        Section {
            Button(action: loadMoreDocuments) {
                HStack {
                    Spacer()
                    if isLoadingMoreDocuments {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else {
                        Text("Load More Documents")
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
            }
            .disabled(isLoadingMoreDocuments)
        }
    }
    
    // Back button
    private var backButton: some View {
        Button(action: {
            isPresented = false
        }) {
            Text("Back")
                .foregroundColor(.blue)
        }
    }
    
    // Password verification sheet
    private var passwordVerificationSheet: some View {
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
    
    // Document detail sheet
    private var documentDetailSheet: some View {
        Group {
            if let document = documentToOpen, let documentId = document.id {
                NavigationView {
                    ZStack {
                        DocumentDetailView(
                            viewModel: createAndPreloadViewModel(document: document),
                            documentId: documentId
                        )
                        .navigationBarBackButtonHidden(true)
                        
                        // Add a loading overlay that shows only during initial loading
                        if let viewModel = documentViewModels[documentId], viewModel.isLoading {
                            Color.black.opacity(0.1)
                                .ignoresSafeArea()
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        }
                    }
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
    }
    
    // MARK: - Helper Methods
    
    // Add this function to verify document lock password
    private func verifyDocumentLockPassword() {
        if let document = selectedDocument,
           viewModel.verifyDocumentLockPassword(documentLockPassword, for: document.id) {
            showPasswordVerification = false
            documentLockPassword = ""
            
            // Open the document after successful verification
            if let coreDataDocument = viewModel.fetchDocument(document.id) {
                documentToOpen = coreDataDocument
                showDocumentOpenSheet = true
            }
        } else {
            showLockError = true
            lockErrorMessage = "Incorrect password. Please try again."
            documentLockPassword = ""
        }
    }
    
    // Add computed property for documents grouped by folder
    private var documentsByFolder: [String: [DocumentListItem]] {
        var result: [String: [DocumentListItem]] = [:]
        
        for document in viewModel.documents {
            let folderName = document.folderName ?? "No Folder Assigned"
            if result[folderName] == nil {
                result[folderName] = []
            }
            result[folderName]?.append(document)
        }
        
        // Sort documents within each folder (newest first)
        for (folderName, documents) in result {
            result[folderName] = documents.sorted(by: { $0.createdAt > $1.createdAt })
        }
        
        return result
    }
    
    // Add computed property for sorted folder names
    private var sortedFolderNames: [String] {
        let folderNames = Array(documentsByFolder.keys)
        return folderNames.sorted()
    }
    
    private func toggleFolderExpansion(_ folderName: String) {
        if expandedFolders.contains(folderName) {
            expandedFolders.remove(folderName)
        } else {
            expandedFolders.insert(folderName)
        }
    }
    
    private func deleteDocument(_ document: DocumentListItem) {
        // Execute the document deletion in the view model
        viewModel.deleteDocument(document.id)
        
        // Immediately update local UI by removing the document from our list
        DispatchQueue.main.async {
            // Remove from the viewModel's documents array
            self.viewModel.documents.removeAll(where: { $0.id == document.id })
            
            // Force view refresh
            self.forceRefreshTrigger = UUID()
            
            // Trigger document list view update animations
            withAnimation {
                // Refresh the folders if they might become empty
                if let folder = document.folderName, 
                   let docs = self.documentsByFolder[folder], 
                   docs.count <= 1 {
                    // If this was the last document in a folder, we need to refresh folder list
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.viewModel.searchDocumentsWithFreshContext()
                    }
                }
            }
        }
    }
    
    private func handleLockDocument(_ document: DocumentListItem) {
        // Check if document lock is set up before locking
        if !viewModel.hasDocumentLock() && !document.isLocked {
            // Document lock is not set up and trying to lock a document
            showDocumentLockSetupPrompt = true
            documentToLock = document
            return
        }
        
        viewModel.toggleDocumentLock(document.id)
    }
    
    private func handleDocumentTap(_ document: DocumentListItem) {
        if viewModel.isDocumentLocked(document.id) {
            // Show password prompt for locked document
            selectedDocument = document
            showPasswordVerification = true
        } else {
            // Open unlocked document directly
            if let coreDataDocument = viewModel.fetchDocument(document.id) {
                documentToOpen = coreDataDocument
                showDocumentOpenSheet = true
            }
        }
    }
    
    private func loadMoreDocuments() {
        guard !isLoadingMoreDocuments else { return }
        
        isLoadingMoreDocuments = true
        currentPage += 1
        
        // Load next page
        viewModel.searchDocumentsWithFreshContext(page: currentPage, perPage: documentsPerPage) { _, isLastPage in
            isLoadingMoreDocuments = false
            allDocumentsLoaded = isLastPage
        }
    }
    
    private func createAndPreloadViewModel(document: Document) -> DocumentViewModel {
        // Create view model
        let viewModel = DocumentViewModel(document: document, persistenceController: self.persistenceController)
        
        // Store the view model in our cache
        if let documentId = document.id {
            documentViewModels[documentId] = viewModel
        }
        
        return viewModel
    }
} 
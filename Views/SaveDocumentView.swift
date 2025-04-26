import SwiftUI
import CoreData
import Combine

// Remove the problematic type aliases
// typealias Document = NSManagedObject
// typealias Folder = NSManagedObject
// typealias Tag = NSManagedObject

// View for saving document details after scanning
struct SaveDocumentView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
    @State private var documentTitle = ""
    @State private var tagsText = ""
    @State private var comments = ""
    @State private var showFolderPicker = false
    @State private var showTagPicker = false
    @State private var newFolderName = ""
    @State private var showNewFolderAlert = false
    @State private var selectedFolder: UUID? = nil
    @State private var selectedFolderName: String = ""
    @State private var showTagConfirmation = false
    @State private var showFolderConfirmation = false
    @State private var showMetadataDebug = false
    @State private var aiPromptText = ""
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var isShowingFolderPicker = false 
    @State private var showingCreateFolderAlert = false 
    @State private var isShowingMetadataDebug = false 
    @State private var isShowingSuccessView = false
    @State private var isDismissingView = false
    @State private var showTitleConfirmation = false
    @State private var showingAddTagAlert = false
    @State private var newTagName = "" 
    @EnvironmentObject private var appServices: AppServices
    @State private var showFolderEditSheet = false 
    @State private var showTagEditSheet = false 
    @State private var showFolderEditSheet2 = false
    @State private var aiClassificationEnabled = UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled")
    
    // Computed property to access the AI error state from the ViewModel
    private var showAIError: Bool {
        viewModel.showAIError 
    }
    
    var isFormValid: Bool {
        !documentTitle.isEmpty
    }
    
    var body: some View {
        // Wrap NavigationView in a ZStack
        ZStack {
            NavigationView {
                // Restore Form structure, keep sections commented
                Form {
                    documentTitleSection
                    
                    folderSection
                    
                    tagsSection
                    
                    commentsSection
                    
                    settingsSection
                    
                    aiAnalysisSection 
                    
                    .onAppear { 
                        print("➡️ Form content appeared.") // Modified print
                    }
                    // Remove toolbar from Form
                } // <<< End Form
                
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Document Details")
                .navigationViewStyle(StackNavigationViewStyle())
                // Restore the toolbar
                .toolbar { 
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            viewModel.cancelScanProcess()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // Use the computed property
                        trailingToolbarItem
                    }
                }
            } // End NavigationView
            
            // Progress Views remain attached to ZStack
            if viewModel.isPerformingOCR {
                ocrProgressView
            }
            
            if viewModel.isSaving && !viewModel.isPerformingOCR {
                savingProgressView
            }
            
        } // End ZStack
        // Attach sheets to the outer ZStack
        .sheet(isPresented: $showTagEditSheet) { 
            // Restore sheet content
            SaveTagsEditView(viewModel: viewModel)
               .environmentObject(viewModel.metadataManager)
               .environmentObject(appServices)
               .onDisappear {
                   // Explicitly synchronize tags when the sheet is dismissed
                   syncTagsWithViewModel()
               }
        }
        .sheet(isPresented: $viewModel.showDocumentImportSuccess) { 
            // Restore original sheet content
            if let docId = viewModel.lastSavedDocumentId {
                DocumentImportSuccessView(
                    documentName: viewModel.lastSavedDocumentTitle,
                    documentId: docId.uuidString,
                    thumbnailImage: viewModel.lastSavedDocumentThumbnail
                )
                // Restore environment object injection
                .environmentObject(NavigationManager())
                // Restore onDisappear
                .onDisappear {
                    isDismissingView = true
                }
            }
        }
        .sheet(isPresented: $showFolderEditSheet) {
            SaveFolderEditView(viewModel: viewModel)
            .environmentObject(appServices)
            .onDisappear(perform: syncWithViewModel)
        }
        // Add onChange to handle dismissal after success sheet closes
        .onChange(of: isDismissingView) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
        
    }
    
    // MARK: - Toolbar Content
    
    // Restore definition
    @ViewBuilder
    private var trailingToolbarItem: some View {
        if viewModel.isSaving { 
            ProgressView()
        } else {
            Button("Save") {
                Task { [viewModel] in
                    await viewModel.saveDocument() 
                }
            }
            .disabled(!isFormValid || viewModel.isSaving || viewModel.isPerformingOCR)
        }
    }
    
    // Break the main content into its own property
    private var mainContent: some View {
        ZStack {
            // Main form content
            Form {
                // Title section
                Section {
                    TextField("Document Title", text: $documentTitle)
                        .onChange(of: documentTitle) { _, newValue in
                            viewModel.documentTitle = newValue
                        }
                        .onChange(of: viewModel.documentTitle) { _, newValue in
                            if documentTitle != newValue {
                                documentTitle = newValue
                            }
                        }
                    if subscriptionManager.isPremium && UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                        titleSuggestionView(suggestions: viewModel.aiSuggestions)
                    }
                } header: {
                    Text("Title")
                }
                
                folderSection
                
                tagsSection
                
                commentsSection
                
                settingsSection
                
                aiAnalysisSection 
                
            }
            .navigationBarTitleDisplayMode(.inline)
            
            /* // Temporarily comment out progress views
            if viewModel.isPerformingOCR {
                ocrProgressView
            }
            
            if viewModel.isSaving && !viewModel.isPerformingOCR {
                savingProgressView
            }
            */
            
            if showFolderConfirmation {
                folderConfirmationView
            }
            
            if showTagConfirmation {
                tagConfirmationView
            }
            
            if showTitleConfirmation {
                titleConfirmationView
            }
        }
    }
    
    // Section for Document Title Input
    private var documentTitleSection: some View {
        Section {
            TextField("Document Title", text: $documentTitle)
                .onChange(of: documentTitle) { _, newValue in
                    viewModel.documentTitle = newValue
                }
                .onChange(of: viewModel.documentTitle) { _, newValue in
                    if documentTitle != newValue {
                        documentTitle = newValue
                    }
                }
            if subscriptionManager.isPremium && UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                titleSuggestionView(suggestions: viewModel.aiSuggestions)
            }
        } header: { 
            Text("Title")
        }
    }
    
    // Folder section
    private var folderSection: some View {
        Section {
            HStack {
                // Look up the folder name from the folders array
                Text(viewModel.metadataManager.folders.first(where: { $0.id == viewModel.selectedFolderId })?.name ?? "No Folder Assigned")
                Spacer()
                Button("Change") {
                    showFolderEditSheet = true
                }
            }
            
            if subscriptionManager.isPremium && UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                folderSuggestionView(suggestions: viewModel.aiSuggestions)
            }
        } header: {
            Text("FOLDER")
        }
    }
    
    // Tags section
    private var tagsSection: some View {
        Section {
            VStack(alignment: .leading) {
                // Use improved TagListView with blue tag capsules
                TagListView(
                    selectedTagIds: viewModel.metadataManager.selectedTagIds,
                    pendingTagNames: Array(viewModel.metadataManager.pendingTagNamesById.values),
                    allTags: viewModel.metadataManager.tags,
                    onRemoveTagId: { tagId in
                        // Log before removal
                        print("⚠️ [SaveDocumentView] Removing tag ID: \(tagId)")
                        print("⚠️ Before removal: selected tags = \(viewModel.metadataManager.selectedTagIds.count)")
                        
                        // Use the metadata manager as the single source of truth
                        viewModel.metadataManager.toggleTagSelection(tagId)
                        
                        // Force UI updates on main thread
                        DispatchQueue.main.async {
                            // Critical: Update view model from metadata manager
                            viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
                            
                            // Log after operation 
                            print("✅ After removal: selected tags = \(viewModel.metadataManager.selectedTagIds.count)")
                            
                            // Force view to update
                            viewModel.objectWillChange.send()
                        }
                    },
                    onRemovePendingTag: { tagName in
                        // Find the tag ID for this pending tag name
                        if let tagId = viewModel.metadataManager.pendingTagNamesById.first(where: { $0.value == tagName })?.key {
                            print("⚠️ [SaveDocumentView] Removing pending tag: \(tagName) with ID: \(tagId)")
                            viewModel.metadataManager.removePendingTag(byId: tagId)
                            
                            // Force UI updates on main thread
                            DispatchQueue.main.async {
                                viewModel.objectWillChange.send()
                            }
                        }
                    }
                )
                
                HStack {
                    Spacer()
                    Button(action: {
                        showTagEditSheet = true
                    }) {
                        Text("Edit")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 4)
                
                // Add back the AI suggestions for tags
                if subscriptionManager.isPremium && UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                    Text("AI Suggestions:")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    
                    ForEach(viewModel.suggestedTagNames ?? [], id: \.self) { suggestion in
                        HStack {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Spacer()
                            Button("Use Tag") {
                                viewModel.createAndSelectTag(name: suggestion)
                            }
                            .font(.subheadline)
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        } header: {
            Text("TAGS")
        }
    }

    // Comments section
    private var commentsSection: some View {
        // Inside the commentsSection computed property
        Section(header: Text("COMMENTS")) {
            TextEditor(text: $comments) // Binds to the @State var comments
                .frame(height: 100)
                 // Observe the local @State var 'comments'
                .onChange(of: comments) { _, newValue in
                    // Assign the new value directly to the viewModel's property
                    viewModel.comments = newValue
                }
                 // Observe the viewModel's @Published property 'comments'
                .onChange(of: viewModel.comments) { _, newValue in
                    // Update the local @State var 'comments' if it differs
                    if comments != newValue {
                        comments = newValue
                    }
                }
        }
    }

    // Settings section
    private var settingsSection: some View {
        Section {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(subscriptionManager.isPremium ? .blue : .gray)
                
                VStack(alignment: .leading) {
                    Text("AI Document Classification")
                    
                    if !subscriptionManager.isPremium {
                        Text("Premium Only")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if !UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                        Text("Disabled in Settings")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Enabled")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                if subscriptionManager.isPremium && UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 4)
            
            if !subscriptionManager.isPremium {
                Text("In order to activate, become a premium subscriber by going to Settings page.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, -4)
                    .padding(.bottom, 8)
            }
        } header: {
            Text("SETTINGS")
        }
    }
    
    // Section for AI Analysis Display
    private var aiAnalysisSection: some View {
        Section(header: Text("AI ANALYSIS")) {
            if !subscriptionManager.isPremium {
                Text("AI Analysis requires Premium.")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else if !UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                Toggle("Enable AI Document Classification", isOn: $aiClassificationEnabled)
                    .onChange(of: aiClassificationEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "AIDocumentClassificationEnabled")
                    }
            } else {
                // Enabled and premium, show token counts if available
                if let suggestions = viewModel.aiSuggestions, 
                   let tokenUsage = suggestions.tokenUsage {
                    VStack(alignment: .leading, spacing: 4) {
                        // First display model name
                        if let modelName = tokenUsage.model {
                            Text("Model: \(modelName)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Text("Token Usage:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Input: \(tokenUsage.promptTokens) · Output: \(tokenUsage.completionTokens) · Total: \(tokenUsage.totalTokens)")
                            .font(.caption)
                        
                        // Add cost estimate
                        Text("Estimated Cost: $\(String(format: "%.5f", calculateCost(promptTokens: tokenUsage.promptTokens, completionTokens: tokenUsage.completionTokens)))")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                    }
                } else {
                    Text("AI Analysis enabled. Token usage details will appear after analysis.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // AI Analysis summary (Restored)
    @ViewBuilder
    private func aiAnalysisSummary(suggestions: DocumentClassifierService.DocumentSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Model: \(self.getSelectedModelName())")
                .font(.caption)
            
            Group {
                if let tokenUsage = suggestions.tokenUsage {
                    Text("Total tokens: \(tokenUsage.totalTokens)")
                        .font(.caption)
                    
                    Text("Prompt: \(tokenUsage.promptTokens) | Completion: \(tokenUsage.completionTokens)")
                        .font(.caption)
                    
                    if let cost = tokenUsage.estimatedCost {
                        Text("Est. cost: $\(String(format: "%.5f", cost))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Token usage information not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - AI Suggestion Views
    
    @ViewBuilder
    private func titleSuggestionView(suggestions: DocumentClassifierService.DocumentSuggestions?) -> some View {
        if let suggestedTitle = suggestions?.suggestedTitle, !suggestedTitle.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Suggestion:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Text(suggestedTitle)
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                    Button("Use Title") {
                        documentTitle = suggestedTitle
                        viewModel.documentTitle = suggestedTitle
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func folderSuggestionView(suggestions: DocumentClassifierService.DocumentSuggestions?) -> some View {
        if let suggestedFolderName = suggestions?.suggestedFolderName, !suggestedFolderName.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Suggestion:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Text(suggestedFolderName)
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                    Button("Use Folder") {
                        viewModel.createAndSelectFolder(name: suggestedFolderName)
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func tagsSuggestionView(suggestions: DocumentClassifierService.DocumentSuggestions?) -> some View {
        if let tags = suggestions?.suggestedTags, !tags.isEmpty {
            VStack(alignment: .leading) {
                Text("Suggestions:")
                    .font(.caption) 
                    .foregroundColor(.green) 
                    .italic() 
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            Button(action: { selectSuggestedTag(tag) }) {
                                Text(tag)
                                    .font(.caption) 
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.blue) 
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.trailing, 4)
                        }
                    }
                }
                HStack {
                   Spacer()
                   Button("Apply All Tags") {
                       self.applyAllSuggestedTags()
                   }
                   .font(.caption) 
                   .buttonStyle(BorderlessButtonStyle())
                   .foregroundColor(.blue)
                }
            }
        }
    }
    
    // OCR progress view overlay
    private var ocrProgressView: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Recognizing Text...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Page \(viewModel.ocrProgress) of \(viewModel.totalPages)")
                    .foregroundColor(.white)
                
                ProgressView(value: Double(viewModel.ocrProgress), total: Double(viewModel.totalPages))
                    .frame(width: 200)
                    .tint(.blue)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.8))
            )
        }
    }
    
    // Regular saving overlay (after OCR is complete)
    private var savingProgressView: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Saving Document...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.8))
            )
        }
    }
    
    // Folder confirmation view
    private var folderConfirmationView: some View {
        VStack {
            Text("Folder selected")
                .font(.subheadline)
                .padding(8)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: self.showFolderConfirmation)
        .position(x: UIScreen.main.bounds.width / 2, y: 100)
    }
    
    // Tag confirmation view
    private var tagConfirmationView: some View {
        VStack {
            Text("Tag added")
                .font(.subheadline)
                .padding(8)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: self.showTagConfirmation)
        .position(x: UIScreen.main.bounds.width / 2, y: 100)
    }
    
    // Title confirmation view
    private var titleConfirmationView: some View {
        VStack {
            Text("Title updated")
                .font(.subheadline)
                .padding(8)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: self.showTitleConfirmation)
        .position(x: UIScreen.main.bounds.width / 2, y: 100)
    }
    
    // Setup function for onAppear
    private func onAppearSetup() {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("📄 [SaveDocumentView ON APPEAR - \(timestamp)] ViewModel state: Images=\(viewModel.scannedImages.count), PDF=\(viewModel.importedPDFData != nil)")
        
        if let folderId = viewModel.selectedFolderId {
            print("🔍 Document details appeared - checking folder name for ID: \(folderId)")
            
            if let folder = viewModel.folders.first(where: { $0.id == folderId }) { 
                selectedFolderName = folder.name
                print("📁 Updated folder selection to: \(selectedFolderName) (from viewModel)")
            } else {
                let context = PersistenceController.shared.container.viewContext
                let request = NSFetchRequest<Folder>(entityName: "Folder")
                request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                
                if let folders = try? context.fetch(request), let folder = folders.first {
                    selectedFolderName = folder.name ?? ""
                    print("📁 Updated folder selection to: \(selectedFolderName) (from Core Data)")
                } else {
                    print("⚠️ Could not find folder name for ID: \(folderId)")
                }
            }
        }
    
        let shouldRunAIAnalysis = self.subscriptionManager.isPremium && 
                                  UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") &&
                                  self.viewModel.aiSuggestions == nil &&
                                  self.viewModel.extractedOCRText != nil && 
                                  !self.viewModel.extractedOCRText!.isEmpty
        
        if shouldRunAIAnalysis {
            print("📊 No AI suggestions yet - requesting analysis")
            self.viewModel.ensureAIAnalysisWithMetadataContext()
        } else {
            if self.viewModel.aiSuggestions != nil {
                print("📊 AI suggestions already exist - skipping duplicate analysis")
            } else {
                print("⚠️ Skipping AI analysis on appear: isPremium=\(self.subscriptionManager.isPremium), AIEnabled=\(UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled"))")
            }
        }
        
        print("🔄 SaveDocumentView appeared - syncing with ViewModel state")
        
        self.viewModel.debugDocumentState()
        
        self.documentTitle = self.viewModel.documentTitle
        self.selectedFolder = self.viewModel.selectedFolderId
        
        if !self.viewModel.metadataManager.selectedTagIds.isEmpty {
            self.tagsText = self.viewModel.getTagsTextFromSelectedIds()
        }
    }
    
    private func saveDocument() {
        print("🅿️ [SaveDocumentView] saveDocument() called.")
        self.viewModel.documentTitle = self.documentTitle
        self.viewModel.selectedFolderId = self.selectedFolder
        
        if let folderId = self.selectedFolder {
            print("📁 SAVE: Selected folder ID: \(folderId), Name: \(self.selectedFolderName)")
        } else {
            print("📂 SAVE: No folder selected")
        }
        
        viewModel.saveDocument()
        
        NotificationCenter.default.post(name: NSNotification.Name("RefreshVaultDocuments"), object: nil)
        
        print("🅿️ [SaveDocumentView] saveDocument() finished calling viewModel.saveDocument() and posting notification.")
        isDismissingView = true
    }
    
    // Update the syncWithViewModel method with better debugging and forced updates
    func syncWithViewModel() {
        if !self.viewModel.documentTitle.isEmpty && self.documentTitle != self.viewModel.documentTitle {
            self.documentTitle = self.viewModel.documentTitle
            print("📝 Updated title to: \(self.documentTitle)")
        }
        
        let oldFolderId = self.selectedFolder
        if self.viewModel.selectedFolderId != nil && self.selectedFolder != self.viewModel.selectedFolderId {
            self.selectedFolder = self.viewModel.selectedFolderId
            print("🔄 Folder ID updated from UI sync: \(oldFolderId?.uuidString ?? "nil") -> \(self.viewModel.selectedFolderId?.uuidString ?? "nil")")
            
            updateFolderNameFromId()
        } else if let folderId = self.viewModel.selectedFolderId, self.selectedFolderName.isEmpty {
            updateFolderNameFromId()
        }
        
        print("‼️ [View] syncWithViewModel - Checking tags. VM has \(self.viewModel.metadataManager.selectedTagIds.count) selected IDs: [\(self.viewModel.metadataManager.selectedTagIds.map { $0.uuidString }.joined(separator: ", "))]")
        if !self.viewModel.metadataManager.selectedTagIds.isEmpty { 
            print("🏷️ Syncing \(self.viewModel.metadataManager.selectedTagIds.count) tag IDs from ViewModel")
            
            let newTagsText = self.viewModel.getTagsTextFromSelectedIds()
            
            let shouldUpdate = self.tagsText != newTagsText || self.tagsText.isEmpty
            
            if shouldUpdate {
                print("🏷️ Updating tags text from: '\(self.tagsText)' to: '\(newTagsText)'")
                self.tagsText = newTagsText
            } else {
                print("⏩ No tag text update needed (already matches)")
            }
        } else if !self.tagsText.isEmpty && self.viewModel.metadataManager.selectedTagIds.isEmpty {
            self.tagsText = ""
        }
        
        if self.comments != self.viewModel.comments {
             self.comments = self.viewModel.comments
        }
    }
    
    // Helper to update folder name from ID
    private func updateFolderNameFromId() {
        if let folderId = self.selectedFolder {
            if let folder = self.viewModel.folders.first(where: { $0.id == folderId }) { 
                self.selectedFolderName = folder.name
                print("📁 Updated folder selection to: \(self.selectedFolderName) (from viewModel)")
            } else {
                let context = PersistenceController.shared.container.viewContext
                let request = NSFetchRequest<Folder>(entityName: "Folder")
                request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                
                if let folders = try? context.fetch(request), let folder = folders.first {
                    self.selectedFolderName = folder.name ?? ""
                    print("📁 Updated folder selection to: \(self.selectedFolderName) (from Core Data)")
                } else {
                    print("⚠️ Warning: Could not find folder name for ID: \(folderId)")
                }
            }
        } else {
            self.selectedFolderName = ""
            print("📂 Cleared folder selection")
        }
    }
    
    // In your tag selection handler for individual "Use" buttons
    func selectSuggestedTag(_ tag: String) {
        let tagItem = viewModel.metadataManager.addTag(name: tag)
        
        viewModel.addTagById(tagItem.id)
        print("✅ Called ViewModel.addTagById for: \(tag) (ID: \(tagItem.id))")
        self.showTagConfirmationAction()
    }
    
    // For the "Apply All" button
    func applyAllSuggestedTags() {
        print("🏷️ Attempting to apply all suggested tags")
        
        guard let suggestedTags = self.viewModel.aiSuggestions?.suggestedTags, !suggestedTags.isEmpty else {
            print("⚠️ No suggested tags available or list is empty")
            return
        }
        
        var tagsAdded = false
        for tag in suggestedTags {
            let tagItem = viewModel.metadataManager.addTag(name: tag)
            viewModel.addTagById(tagItem.id)
            print("✅ Called ViewModel.addTagById for suggested tag: \(tag) (ID: \(tagItem.id))")
            tagsAdded = true 
        }
        
        if tagsAdded {
            self.showTagConfirmationAction()
        }
    }
    
    private func generateMetadataDebugText() -> String {
        var result = ""
        
        if let ocrText = self.viewModel.extractedOCRText {
            result = "OCR Text Preview (first 100 chars): \n\(ocrText.prefix(100))...\n\n"
            result += "METADATA BEING SENT TO AI:\n\n"
            
            let context = PersistenceController.shared.container.viewContext
            
            var existingTitles: [String] = []
            let documentRequest = NSFetchRequest<Document>(entityName: "Document")
            documentRequest.propertiesToFetch = ["title"]
            documentRequest.fetchLimit = 10
            
            if let documents = try? context.fetch(documentRequest) {
                existingTitles = documents.compactMap { $0.title }
            }
            
            var existingTags: [String] = []
            let tagRequest = NSFetchRequest<Tag>(entityName: "Tag")
            tagRequest.fetchLimit = 10
            
            if let tags = try? context.fetch(tagRequest) {
                existingTags = tags.compactMap { $0.name }
            }
            
            var existingFolders: [String] = []
            let folderRequest = NSFetchRequest<Folder>(entityName: "Folder")
            folderRequest.fetchLimit = 10
            
            if let folders = try? context.fetch(folderRequest) {
                existingFolders = folders.compactMap { $0.name }
            }
            
            if !existingTitles.isEmpty {
                result += "DOCUMENT TITLES: \(existingTitles.joined(separator: ", "))\n\n"
            } else {
                result += "DOCUMENT TITLES: None found\n\n"
            }
            
            if !existingTags.isEmpty {
                result += "TAGS: \(existingTags.joined(separator: ", "))\n\n"
            } else {
                result += "TAGS: None found\n\n"
            }
            
            if !existingFolders.isEmpty {
                result += "FOLDERS: \(existingFolders.joined(separator: ", "))\n\n"
            } else {
                result += "FOLDERS: None found\n\n"
            }
            
            result += "Total items found: \(existingTitles.count) titles, \(existingTags.count) tags, \(existingFolders.count) folders"
        } else {
            result = "No OCR text available to enrich"
        }
        
        return result
    }
    
    // Add a method to reset local view state completely
    private func resetLocalViewState() {
        print("🔄 Resetting SaveDocumentView local state")
        self.documentTitle = ""
        self.tagsText = ""
        self.comments = ""
        self.selectedFolder = nil
        self.selectedFolderName = ""
        self.showTagConfirmation = false
        self.showFolderConfirmation = false
        self.showTitleConfirmation = false
    }
    
    // Helper function to get model name from preferences instead of suggestions
    private func getSelectedModelName() -> String {
        let modelKey = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
        return self.modelDisplayName(for: modelKey)
    }
    
    // Helper function to get display name for model
    private func modelDisplayName(for modelName: String) -> String {
        switch modelName {
        case "gpt-4o":
            return "GPT-4o"
        case "gpt-4-turbo":
            return "GPT-4 Turbo"
        default:
            return "GPT-3.5 Turbo"
        }
    }
    
    // Helper to show folder confirmation
    private func showFolderConfirmationAction() {
        guard self.selectedFolder != nil else { return } 
        withAnimation {
            self.showFolderConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.showFolderConfirmation = false
            }
        }
    }
    
    // Helper to show tag confirmation
    private func showTagConfirmationAction() {
        withAnimation {
            self.showTagConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.showTagConfirmation = false
            }
        }
    }
    
    // Helper to show title confirmation
    private func showTitleConfirmationAction() {
        withAnimation {
            self.showTitleConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.showTitleConfirmation = false
            }
        }
    }
    
    // Helper computed property to get TagItems for selected IDs
    private var selectedTagItems: [TagItem] {
        let existingTags = viewModel.metadataManager.tags.filter { viewModel.metadataManager.selectedTagIds.contains($0.id) }
        let pendingTags = viewModel.metadataManager.pendingTagNamesById
            .filter { viewModel.metadataManager.selectedTagIds.contains($0.key) }
            .map { TagItem(id: $0.key, name: $0.value) }
        
        let combined = existingTags + pendingTags.filter { pendingTag in
            !existingTags.contains { $0.id == pendingTag.id }
        }
        // print("‼️ [View] selectedTagItems computed. Returning \(combined.count) items.")
        return combined.sorted { $0.name < $1.name }
    }
    
    // Metadata debug sheet
    private var metadataDebugSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Prompt Metadata Context")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    // Regenerate the text when the sheet appears
                    Text(generateMetadataDebugText())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationBarTitle("AI Context Debug", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                showMetadataDebug = false
            })
        }
    }
    
    private func calculateCost(promptTokens: Int, completionTokens: Int) -> Double {
        // Cost rates per million tokens (typical GPT-3.5 pricing)
        let inputCostPerMillion = 0.50  // $0.50 per million input tokens
        let outputCostPerMillion = 1.50 // $1.50 per million output tokens
        
        let inputCost = Double(promptTokens) * (inputCostPerMillion / 1_000_000)
        let outputCost = Double(completionTokens) * (outputCostPerMillion / 1_000_000)
        
        return inputCost + outputCost
    }
}

// Helper view for tag entry
struct TagEntryView: View {
    @Binding var tagsText: String
    @State private var newTagName = ""
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTags: [String] = []
    @State private var allTags: [TagItem] = []
    
    var body: some View {
        List {
            Section(header: Text("CURRENT TAGS")) {
                if selectedTags.isEmpty {
                    Text("No tags")
                        .italic()
                        .foregroundColor(.gray)
                } else {
                    ForEach(selectedTags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button(action: {
                                selectedTags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("ADD NEW TAG")) {
                HStack {
                    TextField("Tag Name", text: $newTagName)
                    
                    Button(action: {
                        if !newTagName.isEmpty {
                            if !selectedTags.contains(newTagName) {
                                selectedTags.append(newTagName)
                            }
                            newTagName = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newTagName.isEmpty)
                }
            }
            
            Section(header: Text("EXISTING TAGS")) {
                ForEach(allTags) { tag in
                    Button(action: {
                        if !selectedTags.contains(tag.name) {
                            selectedTags.append(tag.name)
                        }
                    }) {
                        HStack {
                            Text(tag.name)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    tagsText = selectedTags.joined(separator: ", ")
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            selectedTags = tagsText.isEmpty ? [] : tagsText.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            loadExistingTags()
        }
    }
    
    private func loadExistingTags() {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let tags = try context.fetch(fetchRequest)
            
            allTags = tags.compactMap { tag -> TagItem? in
                guard let id = tag.id, let name = tag.name else { return nil }
                if !selectedTags.contains(name) {
                    return TagItem(id: id, name: name)
                }
                return nil
            }
        } catch {
            print("Error loading tags: \(error)")
        }
    }
}

// Add a dedicated method to sync tags with the ViewModel
extension SaveDocumentView {
    private func syncTagsWithViewModel() {
        print("💫 Synchronizing tags with ViewModel...")
        print("Tags before sync: VM has \(viewModel.selectedTagIds.count) tags, Manager has \(viewModel.metadataManager.selectedTagIds.count) tags")
        
        // Always update the viewModel from the metadataManager (source of truth)
        viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
        
        // Force a UI refresh
        DispatchQueue.main.async {
            self.viewModel.objectWillChange.send()
        }
        
        print("Tags after sync: VM has \(viewModel.selectedTagIds.count) tags, Manager has \(viewModel.metadataManager.selectedTagIds.count) tags")
    }
}

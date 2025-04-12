import SwiftUI
import Foundation
import CoreData
import Combine

// View for saving document details after scanning
struct SaveDocumentView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ScanViewModel
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
    @State private var isShowingMetadataDebug = false
    @State private var isShowingSuccessView = false
    @State private var isDismissingView = false
    
    var isFormValid: Bool {
        !documentTitle.isEmpty
    }
    
    var body: some View {
        // Break up the complex content into smaller components
        NavigationView {
            mainContent
                .toolbar {
                    toolbarContent
                }
                .sheet(isPresented: $showFolderPicker) {
                    NavigationView {
                        FolderPickerView(
                            selectedFolder: $selectedFolder,
                            folderName: $selectedFolderName,
                            onSave: {
                                if selectedFolder != nil && !selectedFolderName.isEmpty {
                                    viewModel.selectedFolderId = selectedFolder
                                    showFolderConfirmation = true
                                    
                                    // Hide confirmation after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showFolderConfirmation = false
                                    }
                                }
                            }
                        )
                    }
                }
                .sheet(isPresented: $showTagPicker) {
                    NavigationView {
                        TagEntryView(tagsText: $tagsText)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                }
                .alert("New Folder", isPresented: $showNewFolderAlert) {
                    TextField("Folder Name", text: $newFolderName)
                    Button("Cancel", role: .cancel) {
                        newFolderName = ""
                    }
                    Button("Create") {
                        if !newFolderName.isEmpty {
                            let newFolder = viewModel.addFolder(name: newFolderName)
                            selectedFolder = newFolder.id
                            selectedFolderName = newFolder.name
                            newFolderName = ""
                        }
                    }
                } message: {
                    Text("Enter a name for the new folder")
                }
                .onAppear {
                    // Reset local state first before setting up
                    resetLocalViewState()
                    onAppearSetup()
                    
                    // Debug folder display
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("📋 FOLDER DISPLAY CHECK - ID: \(selectedFolder?.uuidString ?? "nil"), Name: '\(selectedFolderName)'")
                        if let folderId = selectedFolder, selectedFolderName.isEmpty {
                            // Force update folder name
                            updateFolderNameFromId()
                            print("📋 FOLDER NAME UPDATED - Now: '\(selectedFolderName)'")
                        }
                    }
                }
                .onReceive(viewModel.$aiSuggestions) { _ in
                    print("🔄 AI suggestions updated - syncing UI")
                    syncWithViewModel()
                }
                .onReceive(viewModel.$selectedFolderId) { _ in
                    print("🔄 Folder ID updated in ViewModel - syncing UI")
                    syncWithViewModel()
                }
                .onReceive(viewModel.$selectedTagIds) { _ in 
                    print("🔄 Tag IDs updated in ViewModel - syncing UI")
                    syncWithViewModel()
                }
                .interactiveDismissDisabled()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .sheet(isPresented: $showMetadataDebug) {
                    metadataDebugSheet
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $viewModel.showDocumentImportSuccess) {
            // Only dismiss the main view after the success view is dismissed
            if isDismissingView {
                presentationMode.wrappedValue.dismiss()
            }
        } content: {
            if let docId = viewModel.lastSavedDocumentId {
                DocumentImportSuccessView(
                    documentName: viewModel.lastSavedDocumentTitle,
                    documentId: docId.uuidString,
                    thumbnailImage: viewModel.lastSavedDocumentThumbnail
                )
                .environmentObject(NavigationManager())
                .onDisappear {
                    // Set flag to dismiss the main view once the success view is closed
                    isDismissingView = true
                }
            }
        }
    }
    
    // Break the main content into its own property
    private var mainContent: some View {
        ZStack {
            // Main form content
            Form {
                // Title section
                Section(header: Text("Title")) {
                    TextField("Document Title", text: $documentTitle)
                        .onChange(of: documentTitle) { _, newValue in
                            // Update viewModel when user types
                            viewModel.documentTitle = newValue
                        }
                        .onChange(of: viewModel.documentTitle) { _, newValue in
                            // Update local state when AI suggestions apply
                            if documentTitle != newValue {
                                documentTitle = newValue
                            }
                        }
                }
                
                folderSection
                tagsSection
                commentsSection
                settingsSection
                
                if subscriptionManager.isPremium && UserDefaults.isAIDocumentClassificationEnabled {
                    aiSuggestionsSection
                }
            }
            .navigationTitle("Document Details")
            .navigationBarTitleDisplayMode(.inline)
            
            // OCR Processing overlay
            if viewModel.isPerformingOCR {
                ocrProgressView
            }
            
            // Regular saving overlay
            if viewModel.isSaving && !viewModel.isPerformingOCR {
                savingProgressView
            }
            
            if showFolderConfirmation {
                folderConfirmationView
            }
            
            if showTagConfirmation {
                tagConfirmationView
            }
        }
    }
    
    // Toolbar content
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    // Clean up all AI suggestions before dismissing
                    viewModel.cleanupAllAISuggestions()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveDocument()
                }
                .disabled(!isFormValid || viewModel.isSaving || viewModel.isPerformingOCR)
            }
        }
    }
    
    // Metadata debug sheet
    private var metadataDebugSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Prompt Metadata Context")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    Text(aiPromptText)
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
    
    // Folder section
    private var folderSection: some View {
        Section(header: Text("FOLDER")) {
            HStack {
                // Display the folder name with better visibility
                if let _ = selectedFolder, !selectedFolderName.isEmpty {
                    Text(selectedFolderName)
                        .foregroundColor(.white) // Ensure text is visible
                } else {
                    Text("No Folder Assigned")
                        .foregroundColor(.gray)
                }
                Spacer()
                Button("Change") {
                    self.showFolderPicker = true
                }
            }
            .onAppear {
                // Ensure folder name is displayed on appear
                if let folderId = selectedFolder, selectedFolderName.isEmpty {
                    print("🔎 Folder section appeared with ID but empty name: \(folderId)")
                    if let folderName = viewModel.pendingFolderName(for: folderId) {
                        selectedFolderName = folderName
                        print("📁 Updated folder name from pending data: \(folderName)")
                    } else {
                        // Try to find the folder name in the viewModel's folder list
                        if let folder = viewModel.folders.first(where: { $0.id == folderId }) {
                            selectedFolderName = folder.name
                            print("📁 Updated folder name from view model: \(folder.name)")
                        }
                    }
                }
            }
        }
    }
    
    // Tags section
    private var tagsSection: some View {
        Section(header: Text("Tags")) {
            if tagsText.isEmpty {
                Text("No tags")
                    .italic()
                    .foregroundColor(.gray)
            } else {
                let tagsList = tagsText.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                ForEach(tagsList, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        Button(action: {
                            // Remove this tag
                            let tagToRemove = tag
                            let currentTags = tagsText.split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            let newTags = currentTags.filter { $0 != tagToRemove }
                            tagsText = newTags.joined(separator: ", ")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Button("Add Tags") {
                showTagPicker = true
            }
        }
    }
    
    // Comments section
    private var commentsSection: some View {
        Section(header: Text("Comments")) {
            TextEditor(text: $comments)
                .frame(minHeight: 100)
        }
    }
    
    // Settings section
    private var settingsSection: some View {
        Section(header: Text("Settings")) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(subscriptionManager.isPremium ? .blue : .gray)
                
                VStack(alignment: .leading) {
                    Text("AI Document Classification")
                    
                    if !subscriptionManager.isPremium {
                        Text("Premium Only")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if !UserDefaults.isAIDocumentClassificationEnabled {
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
                
                // Only show a non-editable indicator based on status
                if subscriptionManager.isPremium && UserDefaults.isAIDocumentClassificationEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 4)
            
            // Add this informational text below
            if !subscriptionManager.isPremium {
                Text("In order to activate, become a premium subscriber by going to Settings page.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, -4)
                    .padding(.bottom, 8)
            }
        }
    }
    
    // AI Suggestions section
    private var aiSuggestionsSection: some View {
        Section(header: Text("AI Suggestions")) {
            Group {
                if viewModel.isAnalyzingDocument {
                    HStack {
                        ProgressView()
                        Text("Analyzing document content...")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
                else if let suggestions = viewModel.aiSuggestions {
                    suggestionsContentView(suggestions: suggestions)
                } else {
                    Text("No suggestions available")
                        .italic()
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    viewModel.ensureAIAnalysisWithMetadataContext()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh AI Suggestions")
                    }
                }
                .disabled(viewModel.isAnalyzingDocument)
                
                Button(action: {
                    showMetadataDebug = true
                    aiPromptText = generateMetadataDebugText()
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("View Metadata Context")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // Break out the suggestions content to avoid generic parameter inference issues
    private func suggestionsContentView(suggestions: DocumentClassifierService.DocumentSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Note when values differ from already applied suggestions
            if !documentTitle.isEmpty && documentTitle != suggestions.suggestedTitle {
                Text("Note: Document already has different metadata applied")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.bottom, 4)
            }
            
            // Title suggestion
            HStack {
                Text("Title: \(suggestions.suggestedTitle)")
                    .font(.body)
                
                Spacer()
                
                Button("Use") {
                    viewModel.documentTitle = suggestions.suggestedTitle
                }
                .disabled(viewModel.documentTitle == suggestions.suggestedTitle)
            }
            
            // Folder suggestion - only show if we have one
            if let folderName = suggestions.suggestedFolderName {
                HStack {
                    Text("Folder: \(folderName)")
                        .font(.body)
                    
                    Spacer()
                    
                    Button("Use") {
                        // First update the viewModel
                        viewModel.createAndSelectFolder(name: folderName)
                        
                        // Then immediately update the local state to reflect the change
                        if let folderId = viewModel.selectedFolderId {
                            selectedFolder = folderId
                            selectedFolderName = folderName
                            
                            // Show folder confirmation
                            showFolderConfirmation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showFolderConfirmation = false
                            }
                        }
                    }
                }
            }
            
            // Tags suggestions
            Text("Tags:")
                .font(.body)
            
            ForEach(suggestions.suggestedTags, id: \.self) { tag in
                HStack {
                    Text(tag)
                        .font(.body)
                    
                    Spacer()
                    
                    Button("Add") {
                        selectSuggestedTag(tag)
                    }
                }
            }
            
            // Confidence and Apply All
            HStack {
                // Handle NaN and infinite values directly
                let confidenceValue = suggestions.confidence * 100
                let confidencePercent = confidenceValue.isFinite ? Int(confidenceValue) : 0
                Text("Confidence: \(confidencePercent)%")
                    .font(.body)
                    .foregroundColor(suggestions.confidence > 0.7 ? .green : .orange)
                
                Spacer()
                
                Button("Apply All") {
                    // Apply title (already handled by the binding)
                    viewModel.documentTitle = suggestions.suggestedTitle
                    
                    // Apply folder if available
                    if let folderName = suggestions.suggestedFolderName {
                        viewModel.createAndSelectFolder(name: folderName)
                        
                        // Update local state
                        if let folderId = viewModel.selectedFolderId {
                            selectedFolder = folderId
                            selectedFolderName = folderName
                        }
                    }
                    
                    // Apply tags (existing implementation)
                    applyAllSuggestedTags()
                }
                .foregroundColor(.blue)
            }
            
            // Token usage section - always create the view but only show content if available
            Divider()
            
            aiAnalysisSummary(suggestions: suggestions)
        }
    }
    
    // AI Analysis summary
    @ViewBuilder
    private func aiAnalysisSummary(suggestions: DocumentClassifierService.DocumentSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI Analysis")
                .font(.headline)
            
            // Model name
            Text("Model: \(getSelectedModelName())")
                .font(.caption)
            
            // Overall confidence
            HStack {
                Text("Overall confidence: ")
                    .font(.caption)
                
                // Confidence percentage with color coding
                let confidencePercentage = Int(suggestions.confidence * 100)
                Text("\(confidencePercentage)%")
                    .font(.caption.bold())
                    .foregroundColor(getConfidenceColor(confidence: suggestions.confidence))
            }
            
            // Folder confidences if available
            if let folderConfidences = suggestions.folderConfidences, !folderConfidences.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Folder confidence scores:")
                        .font(.caption)
                        .padding(.top, 2)
                    
                    // Sort by confidence score (highest first)
                    ForEach(folderConfidences.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { folder, score in
                        HStack {
                            Text(folder)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Format score as percentage
                            let percentScore = Int(score * 100)
                            Text("\(percentScore)%")
                                .font(.caption.bold())
                                .foregroundColor(getConfidenceColor(confidence: score))
                        }
                        .padding(.vertical, 1)
                    }
                    
                    // If there are more folders than we're showing
                    if folderConfidences.count > 5 {
                        Text("+ \(folderConfidences.count - 5) more folders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            } else {
                // Show message when no folder confidences are available
                VStack(alignment: .leading) {
                    Text("Folder confidence scores: Not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    
                    if let suggestedFolder = suggestions.suggestedFolderName {
                        Text("Suggested folder: \(suggestedFolder) (using overall confidence)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            
            // Token usage info
            Group {
                // Show pricing based on model
                let modelName = getSelectedModelName()
                if modelName.contains("GPT-4o") {
                    Text("Rate: $2.50/million input, $10.00/million output tokens")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if modelName.contains("GPT-4") {
                    Text("Rate: $10.00/million input, $30.00/million output tokens")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("Rate: $0.50/million input, $1.50/million output tokens")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
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
    
    // Helper function to get color based on confidence score
    private func getConfidenceColor(confidence: Double) -> Color {
        let percentageScore = confidence * 100
        if percentageScore >= 70 {
            return .green
        } else if percentageScore >= 50 {
            return .orange
        } else {
            return .red
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
                
                Text("Page \(viewModel.ocrProgress) of \(viewModel.totalOCRPages)")
                    .foregroundColor(.white)
                
                // Add a progress bar
                ProgressView(value: Double(viewModel.ocrProgress), total: Double(viewModel.totalOCRPages))
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
        .animation(.easeInOut, value: showFolderConfirmation)
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
        .animation(.easeInOut, value: showTagConfirmation)
        .position(x: UIScreen.main.bounds.width / 2, y: 100)
    }
    
    // Setup function for onAppear
    private func onAppearSetup() {
        // Force a complete sync of the folder name first
        if let folderId = viewModel.selectedFolderId {
            print("🔍 Document details appeared - checking folder name for ID: \(folderId)")
            
            // Check multiple sources for the folder name
            if let folderName = viewModel.pendingFolderName(for: folderId) {
                selectedFolderName = folderName
                print("📁 Using pending folder name: \(folderName)")
            } else if let folder = viewModel.folders.first(where: { $0.id == folderId }) {
                selectedFolderName = folder.name
                print("📁 Using folder name from viewModel collection: \(folder.name)")
            } else {
                // Last resort: fetch from Core Data
                let context = PersistenceController.shared.container.viewContext
                let request = NSFetchRequest<Folder>(entityName: "Folder")
                request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                
                if let folders = try? context.fetch(request), let folder = folders.first {
                    selectedFolderName = folder.name ?? ""
                    print("📁 Using folder name from Core Data: \(selectedFolderName)")
                } else {
                    print("⚠️ Could not find folder name for ID: \(folderId)")
                }
            }
        }
    
        // Only trigger AI analysis if:
        // 1. Premium and AI is enabled
        // 2. We don't already have AI suggestions
        // 3. We have OCR text to analyze
        let shouldRunAIAnalysis = subscriptionManager.isPremium && 
                                  UserDefaults.isAIDocumentClassificationEnabled &&
                                  viewModel.aiSuggestions == nil &&
                                  viewModel.extractedOCRText != nil && 
                                  !viewModel.extractedOCRText!.isEmpty
        
        if shouldRunAIAnalysis {
            print("📊 No AI suggestions yet - requesting analysis")
            viewModel.ensureAIAnalysisWithMetadataContext()
        } else {
            if viewModel.aiSuggestions != nil {
                print("📊 AI suggestions already exist - skipping duplicate analysis")
            } else {
                print("⚠️ Skipping AI analysis on appear: isPremium=\(subscriptionManager.isPremium), AIEnabled=\(UserDefaults.isAIDocumentClassificationEnabled)")
            }
        }
        
        print("🔄 SaveDocumentView appeared - syncing with ViewModel state")
        
        // Call the debug method to see what's happening
        viewModel.debugDocumentState()
        
        // Force a complete sync (not conditional)
        documentTitle = viewModel.documentTitle
        selectedFolder = viewModel.selectedFolderId
        
        // Force sync tags
        if !viewModel.selectedTagIds.isEmpty {
            tagsText = viewModel.getTagsTextFromSelectedIds()
        }
    }
    
    private func saveDocument() {
        // Before saving, update the viewModel with all our local state
        viewModel.documentTitle = documentTitle
        viewModel.selectedFolderId = selectedFolder
        
        // Double check folder status before saving
        if let folderId = selectedFolder {
            print("📁 SAVE: Selected folder ID: \(folderId), Name: \(selectedFolderName)")
        } else {
            print("📂 SAVE: No folder selected")
        }
        
        // Process tags from comma-separated string
        let tagNames = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Create any new tags and get their IDs
        let tagIds = tagNames.map { tagName -> UUID in
            if let existingTag = viewModel.tags.first(where: { $0.name.lowercased() == tagName.lowercased() }) {
                return existingTag.id
            } else {
                let newTag = viewModel.addTag(name: tagName)
                return newTag.id
            }
        }
        
        // Update selectedTagIds in the viewModel
        viewModel.selectedTagIds = Set(tagIds)
        
        // Set any comments if needed (add this property to viewModel if missing)
        // viewModel.comments = comments
        
        // Now call the no-argument saveDocument method
        viewModel.saveDocument()
        
        // Post notification to refresh the Vault view
        NotificationCenter.default.post(name: NSNotification.Name("RefreshVaultDocuments"), object: nil)
        
        // No longer dismiss here - the success screen will handle it
        // The view will be dismissed after the success view is closed
    }
    
    // Update the syncWithViewModel method with better debugging and forced updates
    func syncWithViewModel() {
        // Always update title if viewModel has one
        if !viewModel.documentTitle.isEmpty && documentTitle != viewModel.documentTitle {
            documentTitle = viewModel.documentTitle
            print("📝 Updated title to: \(documentTitle)")
        }
        
        // Always update folder if viewModel has a selection
        let oldFolderId = selectedFolder
        if viewModel.selectedFolderId != nil && selectedFolder != viewModel.selectedFolderId {
            selectedFolder = viewModel.selectedFolderId
            print("🔄 Folder ID updated from UI sync: \(oldFolderId?.uuidString ?? "nil") -> \(viewModel.selectedFolderId?.uuidString ?? "nil")")
            
            // Always ensure we have a folder name
            updateFolderNameFromId()
        } else if let folderId = viewModel.selectedFolderId, selectedFolderName.isEmpty {
            // Force folder name update if we have an ID but no name
            print("📁 Folder ID exists but name is empty - forcing update")
            updateFolderNameFromId()
        }
        
        // Always update tags if viewModel has tags selected
        if !viewModel.selectedTagIds.isEmpty {
            print("🏷️ Syncing \(viewModel.selectedTagIds.count) tag IDs from ViewModel")
            
            // Get the new tags text directly from the view model
            let newTagsText = viewModel.getTagsTextFromSelectedIds()
            
            // Force update if tags were added or tagsText is empty (to catch initial load)
            let shouldUpdate = tagsText != newTagsText || tagsText.isEmpty
            
            if shouldUpdate {
                print("🏷️ Updating tags text from: '\(tagsText)' to: '\(newTagsText)'")
                tagsText = newTagsText
            } else {
                print("⏩ No tag text update needed (already matches)")
            }
        } else if !tagsText.isEmpty && viewModel.selectedTagIds.isEmpty {
            // Clear tags text if view model has no tags
            print("🧹 Clearing tags text as ViewModel has no tags")
            tagsText = ""
        }
    }
    
    // Helper to update folder name from ID
    private func updateFolderNameFromId() {
        if let folderId = selectedFolder {
            // First check the view model's folders collection (faster)
            if let folder = viewModel.folders.first(where: { $0.id == folderId }) {
                selectedFolderName = folder.name
                print("📁 Updated folder selection to: \(selectedFolderName) (from viewModel)")
            } else {
                // Check if it's a pending folder
                if let pendingFolder = viewModel.pendingFolderName(for: folderId) {
                    selectedFolderName = pendingFolder
                    print("📁 Using pending folder name: \(pendingFolder)")
                } else {
                    // Fallback to Core Data lookup
                    let context = PersistenceController.shared.container.viewContext
                    let request = NSFetchRequest<Folder>(entityName: "Folder")
                    request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                    request.fetchLimit = 1
                    
                    if let folders = try? context.fetch(request), let folder = folders.first {
                        selectedFolderName = folder.name ?? ""
                        print("📁 Updated folder selection to: \(selectedFolderName) (from Core Data)")
                    } else {
                        print("⚠️ Warning: Could not find folder with ID \(folderId)")
                    }
                }
            }
        } else {
            selectedFolderName = ""
            print("📂 Cleared folder selection")
        }
    }
    
    // In your tag selection handler for individual "Use" buttons
    func selectSuggestedTag(_ tag: String) {
        print("🏷️ Attempting to apply tag: \(tag)")
        
        // Get existing tags from the text field
        var currentTags = tagsText.isEmpty ? [] : tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Only add the tag if it's not already there
        if !currentTags.contains(tag) {
            currentTags.append(tag)
            
            // Update the tags text field
            tagsText = currentTags.joined(separator: ", ")
            print("✅ Tag added: \(tag)")
            
            // Show confirmation
            showTagConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showTagConfirmation = false
            }
        }
    }
    
    // For the "Apply All" button
    func applyAllSuggestedTags() {
        print("🏷️ Attempting to apply all suggested tags")
        
        // Get suggested tags from the AI suggestions
        guard let suggestedTags = viewModel.aiSuggestions?.suggestedTags else {
            print("⚠️ No suggested tags available")
            return
        }
        
        // Get current tags
        var currentTags = tagsText.isEmpty ? [] : tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Add all suggested tags that aren't already selected
        var tagsAdded = false
        for tag in suggestedTags {
            if !currentTags.contains(tag) {
                currentTags.append(tag)
                print("✅ Added tag from suggestions: \(tag)")
                tagsAdded = true
            }
        }
        
        // Update the tags text field
        if tagsAdded {
            tagsText = currentTags.joined(separator: ", ")
            
            // Show confirmation
            showTagConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showTagConfirmation = false
            }
        }
    }
    
    private func generateMetadataDebugText() -> String {
        // Start with an empty result
        var result = ""
        
        // Check if we have OCR text
        if let ocrText = viewModel.extractedOCRText {
            // Add OCR text preview
            result = "OCR Text Preview (first 100 chars): \n\(ocrText.prefix(100))...\n\n"
            result += "METADATA BEING SENT TO AI:\n\n"
            
            // Fetch metadata from Core Data
            let context = PersistenceController.shared.container.viewContext
            
            // Fetch titles
            var existingTitles: [String] = []
            let documentRequest = NSFetchRequest<Document>(entityName: "Document")
            documentRequest.propertiesToFetch = ["title"]
            documentRequest.fetchLimit = 10
            if let documents = try? context.fetch(documentRequest) {
                existingTitles = documents.compactMap { $0.title }
            }
            
            // Fetch tags
            var existingTags: [String] = []
            let tagRequest = NSFetchRequest<Tag>(entityName: "Tag")
            tagRequest.fetchLimit = 10
            if let tags = try? context.fetch(tagRequest) {
                existingTags = tags.compactMap { $0.name }
            }
            
            // Fetch folders
            var existingFolders: [String] = []
            let folderRequest = NSFetchRequest<Folder>(entityName: "Folder")
            folderRequest.fetchLimit = 10
            if let folders = try? context.fetch(folderRequest) {
                existingFolders = folders.compactMap { $0.name }
            }
            
            // Add metadata to the result
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
            
            // Add summary
            result += "Total items found: \(existingTitles.count) titles, \(existingTags.count) tags, \(existingFolders.count) folders"
        } else {
            result = "No OCR text available to enrich"
        }
        
        return result
    }
    
    // Add a method to reset local view state completely
    private func resetLocalViewState() {
        print("🔄 Resetting SaveDocumentView local state")
        documentTitle = ""
        tagsText = ""
        comments = ""
        selectedFolder = nil
        selectedFolderName = ""
        showTagConfirmation = false
        showFolderConfirmation = false
    }
    
    // Helper function to get model name from preferences instead of suggestions
    private func getSelectedModelName() -> String {
        let modelKey = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
        return modelDisplayName(for: modelKey)
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
}

// Helper view for folder selection
struct FolderPickerView: View {
    @Binding var selectedFolder: UUID?
    @Binding var folderName: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var allFolders: [FolderItem] = []
    @State private var newFolderName = ""
    @State private var showNewFolderAlert = false
    @State private var showInvalidNameAlert = false
    @State private var invalidNameMessage = ""
    
    // Reserved folder names that shouldn't be used
    private let reservedFolderNames = ["No Folder", "No Folder Assigned"]
    
    var body: some View {
        List {
            // 1. Current folder section first
            Section(header: Text("CURRENT FOLDER")) {
                HStack {
                    if !folderName.isEmpty {
                        Text(folderName)
                    } else {
                        Text("No Folder Assigned")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 2. Create New Folder button next
            Section {
                Button(action: {
                    showNewFolderAlert = true
                }) {
                    Text("Create New Folder")
                        .foregroundColor(.blue)
                }
            }
            
            // 3. Folder selection without the header
            Section {
                // No folder option
                Button(action: {
                    selectedFolder = nil
                    folderName = ""
                }) {
                    HStack {
                        Text("No Folder Assigned")
                        Spacer()
                        if selectedFolder == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Folder list
                ForEach(allFolders) { folder in
                    Button(action: {
                        // Update selection
                        selectedFolder = folder.id
                        folderName = folder.name
                    }) {
                        HStack {
                            Text(folder.name)
                            Spacer()
                            if selectedFolder == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Folder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    // Notify the parent view that selection is complete
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                if !newFolderName.isEmpty {
                    // Validate folder name
                    if reservedFolderNames.contains(newFolderName) {
                        invalidNameMessage = "'\(newFolderName)' is a reserved name and cannot be used as a folder name."
                        showInvalidNameAlert = true
                        newFolderName = ""
                        return
                    }
                    
                    // Create and add the new folder to the list
                    let newFolder = createFolder(name: newFolderName)
                    selectedFolder = newFolder.id
                    folderName = newFolder.name
                    newFolderName = ""
                }
            }
        } message: {
            Text("Enter a name for the new folder")
        }
        .alert("Invalid Folder Name", isPresented: $showInvalidNameAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(invalidNameMessage)
        }
        .onAppear {
            loadFolders()
        }
    }
    
    private func loadFolders() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let fetchedFolders = try context.fetch(fetchRequest)
            allFolders = fetchedFolders.compactMap { folder in
                guard let id = folder.id, let name = folder.name else { return nil }
                return FolderItem(id: id, name: name)
            }
        } catch {
            print("Error loading folders: \(error)")
        }
    }
    
    private func createFolder(name: String) -> FolderItem {
        let context = PersistenceController.shared.container.viewContext
        let newFolder = Folder(context: context)
        newFolder.id = UUID()
        newFolder.name = name
        
        do {
            try context.save()
            let folderItem = FolderItem(id: newFolder.id!, name: name)
            allFolders.append(folderItem)
            return folderItem
        } catch {
            print("Error creating folder: \(error)")
            // Return a placeholder in case of error
            return FolderItem(id: UUID(), name: name)
        }
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
            // CURRENT TAGS section
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
                                // Remove tag from selection
                                selectedTags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            // ADD NEW TAG section
            Section(header: Text("ADD NEW TAG")) {
                HStack {
                    TextField("Tag Name", text: $newTagName)
                    
                    Button(action: {
                        if !newTagName.isEmpty {
                            // Add to selected tags if not already present
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
            
            // EXISTING TAGS section
            Section(header: Text("EXISTING TAGS")) {
                ForEach(allTags) { tag in
                    Button(action: {
                        // Add to selected tags if not already present
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
                    // Save changes to the tagsText binding
                    tagsText = selectedTags.joined(separator: ", ")
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            // Initialize selected tags from tagsText
            selectedTags = tagsText.isEmpty ? [] : tagsText.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Load existing tags from Core Data
            loadExistingTags()
        }
    }
    
    // Load existing tags from Core Data
    private func loadExistingTags() {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let tags = try context.fetch(fetchRequest)
            
            // Convert to TagItem array and exclude already selected tags
            allTags = tags.compactMap { tag -> TagItem? in
                guard let id = tag.id, let name = tag.name else { return nil }
                // Only include tags that aren't already selected
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


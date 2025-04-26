import SwiftUI
import Combine
import CoreData

extension ViewModels_Scan {

    @MainActor
    public class ScanViewModel: ObservableObject {
        
        // MARK: - Services
        let appServices: AppServices
        let metadataManager: ScanMetadataManager
        let aiAnalysisService: AIDocumentAnalysisService
        let persistenceService: ScanPersistenceService
        let processingService: DocumentProcessingService
        let scanCoordinator: ScanCoordinator // To be implemented
        
        // MARK: - Published State (Exposed to View)
        
        // --- Document Metadata (Managed by MetadataManager, but published here for SaveDocumentView)
        @Published var documentTitle: String = ""
        @Published var selectedFolderId: UUID? = nil
        @Published var selectedTagIds: Set<UUID> = []
        @Published var comments: String = "" // Added for SaveDocumentView
        
        // --- Scan/Import Input State ---
        @Published var scannedImages: [UIImage] = [] // From Coordinator
        @Published var importedPDFData: Data? = nil   // From document picker
        @Published var extractedOCRText: String? = nil // From ProcessingService
        @Published var processedDocumentData: Data? = nil // Store final data from processor
        
        // --- Processing State (From ProcessingService) ---
        @Published var isProcessing: Bool = false
        @Published var isPerformingOCR: Bool = false // Added, mirrors isProcessing for now?
        @Published var processingProgress: Double = 0.0
        @Published var ocrProgress: Double = 0.0 // Changed to Double
        @Published var totalPages: Int = 0 // RENAMED from totalOCRPages
        @Published var processingProgressText: String = "Processing..."
        @Published var showProcessingErrorAlert: Bool = false
        @Published var processingErrorMessage: String = ""
        
        // --- AI Analysis State (From AIService) ---
        @Published var isAnalyzingDocument: Bool = false
        @Published var aiSuggestions: DocumentClassifierService.DocumentSuggestions? = nil
        @Published var suggestedFolderName: String? = nil // ADDED: Store raw suggested folder name
        @Published var suggestedTagNames: [String]? = nil // ADDED: Store raw suggested tag names
        @Published var showAIError: Bool = false
        @Published var aiErrorMessage: String = "" // Added, synced from AIService
        @Published var showPremiumUpgradePrompt: Bool = false
        
        // --- Saving State (Managed internally, calls PersistenceService) ---
        @Published var isSaving: Bool = false
        @Published var showDocumentImportSuccess: Bool = false // Renamed from showSaveSuccess
        @Published var lastSavedDocumentId: UUID? = nil // Added for success view
        @Published var lastSavedDocumentTitle: String = "" 
        @Published var lastSavedDocumentThumbnailData: Data? = nil 
        @Published var lastSavedDocumentThumbnail: UIImage? = nil // Added for success view
        @Published var showSaveErrorAlert: Bool = false
        @Published var saveErrorMessage: String = ""
        
        // --- View Control State ---
        @Published var showDocumentScanner = false
        @Published var showFolderSelector = false
        @Published var showTagSelector = false
        @Published var showCancelConfirmation = false
        @Published var showingDocumentPicker = false
        @Published var showDocumentCreationSheet = false
        @Published var showUnsupportedFileAlert = false
        
        @Published var recentScans: [DocumentItem] = [] 

        // MARK: - Private State & Cancellables
        private var cancellables = Set<AnyCancellable>()
        private let viewContext: NSManagedObjectContext
        private let subscriptionManager: SubscriptionManager // Passed in
        
        // MARK: - Initialization
        
        init(appServices: AppServices, subscriptionManager: SubscriptionManager) {
            self.appServices = appServices
            self.subscriptionManager = subscriptionManager
            
            // Initialize Services
            self.viewContext = appServices.persistenceController.viewContext
            
            // Initialize AI service first, as it might be needed by MetadataManager
            self.aiAnalysisService = AIDocumentAnalysisService(subscriptionManager: subscriptionManager, persistenceController: appServices.persistenceController, documentAIService: appServices.documentAIService)
            // Now initialize MetadataManager with PersistenceController and the AI Service instance
            self.metadataManager = ScanMetadataManager(persistenceController: appServices.persistenceController, aiService: self.aiAnalysisService)
            self.persistenceService = ScanPersistenceService(context: viewContext, adaptiveClassifier: appServices.adaptiveLearningClassifier)
            // --- UPDATED INITIALIZER CALL --- 
            self.processingService = DocumentProcessingService(appServices: appServices, subscriptionManager: subscriptionManager)
            self.scanCoordinator = ScanCoordinator() // Initialize BEFORE using self
            self.processingService.delegate = self // NOW it's safe to assign self
            
            print("🚀 ScanViewModel Initialized")
            
            // Sync initial state from metadataManager to published properties
            self.documentTitle = metadataManager.documentTitle
            self.selectedFolderId = metadataManager.selectedFolderId
            self.selectedTagIds = metadataManager.selectedTagIds
            
            // Setup Bindings between services and the main ViewModel
            setupObservers()
            
            // Initial data fetch
            metadataManager.fetchFolders()
            metadataManager.fetchTags()
        }
        
        // MARK: - Bindings Setup
        
        private func setupObservers() {
            print("🔗 Setting up ViewModel bindings...")
            
            // ---- MetadataManager Bindings ----
            metadataManager.$selectedFolderId
                .sink { [weak self] newFolderId in
                    print("🔄 ScanViewModel observed folder change: \(newFolderId?.uuidString ?? "None")")
                    // Potentially trigger related logic if needed
                    // Sync with our published property if different
                    if self?.selectedFolderId != newFolderId {
                        self?.selectedFolderId = newFolderId
                    }
                }
                .store(in: &cancellables)

            // Sink for changes FROM manager TO viewModel (Manual toggle calls this anyway)
            metadataManager.$selectedTagIds
                .sink { [weak self] newTagIds in
                    print("🔄 ScanViewModel observed tags change: \(newTagIds.count) tags selected")
                    // Sync with our published property if different
                    if self?.selectedTagIds != newTagIds {
                        self?.selectedTagIds = newTagIds
                    }
                }
                .store(in: &cancellables)

            // Sink for changes FROM viewModel TO manager (Manual toggle calls this anyway)
            // This seems redundant IF the primary mutation happens via viewModel.toggleTagSelection -> manager.toggleTagSelection
            /*
            $selectedTagIds // The ViewModel's published property
                .sink { [weak self] vmTagIds in
                    // Sync back to the manager IF DIFFERENT (to avoid loops)
                    if self?.metadataManager.selectedTagIds != vmTagIds {
                        print("🔄 Syncing ViewModel tags back to MetadataManager: \(vmTagIds.count) tags")
                        self?.metadataManager.selectedTagIds = vmTagIds // <-- Updates Manager's property
                    }
                }
                .store(in: &cancellables)
            */
            
            // ---- ProcessingService Bindings ----
            processingService.$isProcessing
                .receive(on: DispatchQueue.main)
                .sink { [weak self] processing in
                    self?.isProcessing = processing
                    self?.isPerformingOCR = processing // Mirror state for now
                }
                .store(in: &cancellables)
            
            // --- UPDATED BINDING --- 
            processingService.$ocrProgress // Use correct property name
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newProgress in // Use correct property name in closure
                    self?.ocrProgress = newProgress // Assign to ScanViewModel's property
                }
                .store(in: &cancellables)
                
            processingService.$showProcessingErrorAlert
                 .receive(on: DispatchQueue.main)
                 .assign(to: &$showProcessingErrorAlert)
                 
             processingService.$processingError
                 .receive(on: DispatchQueue.main)
                 .map { $0?.localizedDescription ?? "" }
                 .assign(to: &$processingErrorMessage)
                 
            // Capture extracted text
            processingService.$processedText
                .receive(on: DispatchQueue.main)
                .assign(to: &$extractedOCRText)
                  
                          
            // When processing finishes, trigger AI analysis
            processingService.$processedText
                .dropFirst()
                .compactMap { $0 } // Only proceed if text is non-nil
                .receive(on: DispatchQueue.main)
                .sink { [weak self] ocrText in
                     guard let self = self else { return }
                    
                    // Check premium status and AI setting before analyzing
                    guard self.subscriptionManager.isPremium else {
                        print("🚫 AI Analysis skipped: User is not premium.")
                        // Optionally clear any old suggestions if needed
                        // self.aiAnalysisService.clearSuggestions()
                        return
                    }
                    guard UserDefaults.isAIDocumentClassificationEnabled else {
                        print("🚫 AI Analysis skipped: AI toggle is disabled.")
                        // Optionally clear any old suggestions if needed
                        // self.aiAnalysisService.clearSuggestions()
                        return
                    }
                    
                    print("✅ Processing finished, triggering AI analysis (Premium & Enabled).")
                     self.aiAnalysisService.analyzeDocument(
                         ocrText: ocrText, 
                         folderNames: self.metadataManager.folders.map { $0.name }, // Pass existing names
                         tagNames: self.metadataManager.tags.map { $0.name } // Pass existing names
                     )
                }
                .store(in: &cancellables)

            // ---- AIAnalysisService Bindings ----
            aiAnalysisService.$isLoading
                .receive(on: DispatchQueue.main)
                .assign(to: &$isAnalyzingDocument)
                
            aiAnalysisService.$analysisResult
                .receive(on: DispatchQueue.main)
                .sink { [weak self] (suggestions: DocumentClassifierService.DocumentSuggestions?) in
                     print("📬 Received AI Suggestions in ScanViewModel")
                     guard let suggestions = suggestions else { return }
                     self?.metadataManager.applyAISuggestions(suggestions)
                     self?.aiSuggestions = suggestions // Also publish them directly
                     // Sync title/folder/tags if applied by metadataManager
                     self?.documentTitle = self?.metadataManager.documentTitle ?? ""
                     self?.selectedFolderId = self?.metadataManager.selectedFolderId
                     self?.selectedTagIds = self?.metadataManager.selectedTagIds ?? []
                }
                .store(in: &cancellables)

            aiAnalysisService.$error
                 .receive(on: DispatchQueue.main)
                 .map { $0 != nil } // Map error presence to a Bool
                 .assign(to: &$showAIError)
                 
             aiAnalysisService.$error
                 .receive(on: DispatchQueue.main)
                 .map { $0?.localizedDescription ?? "An unknown AI error occurred." }
                 .sink { [weak self] errorMessage in // Use .sink to assign manually
                     self?.aiErrorMessage = errorMessage
                 }
                 .store(in: &cancellables) // Store the cancellable from .sink
                 
            // ---- PersistenceService Bindings ----
            persistenceService.$lastSavedDocumentTitle
                .receive(on: DispatchQueue.main)
                .sink { [weak self] title in 
                    self?.lastSavedDocumentTitle = title
                }
                
            // ---- ScanCoordinator Bindings ----
            #if canImport(VisionKit)
            scanCoordinator.didFinishScanning
                .receive(on: DispatchQueue.main)
                .sink { [weak self] images in
                    self?.handleScannedImages(images: images)
                }
                .store(in: &cancellables)
                
            scanCoordinator.didFailScanning
                .receive(on: DispatchQueue.main)
                .sink { [weak self] error in
                    self?.handleScanError(error)
                }
                .store(in: &cancellables)
                
            scanCoordinator.didCancelScanning
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in
                    print("🔗 ScanCoordinator reported cancellation.")
                    // User explicitly cancelled the scanner UI
                    self?.showDocumentScanner = false
                    // If no images were processed yet, reset. Otherwise, user might want to proceed with existing data.
                    if self?.scannedImages.isEmpty == true && self?.importedPDFData == nil {
                         self?.resetScanState()
                    }
                }
                .store(in: &cancellables)
            #endif
            
            print("🔗 ViewModel bindings established.")
        }
        
        // MARK: - User Actions (Called from View)
        
        func startScan() {
            print("📸 User Action: Start Scan")
            #if canImport(VisionKit)
            // Reset previous state if needed
            resetScanState()
            showDocumentScanner = true
            // The View will use showDocumentScanner to present the sheet with scanCoordinator.makeScannerViewController()
            #else
            // On platforms without VisionKit (e.g., macOS), maybe trigger file import?
            print("⚠️ VisionKit not available, attempting file import fallback.")
            // Or show an alert indicating scanning is not supported
            // For now, let's just log it.
            handleScanError(ScanCoordinatorError.visionKitUnavailable) 
            #endif
        }
        
        // Called when document picker provides PDF data
        func handleImportedPDF(pdfData: Data) {
             print("📄 User Action: Handle Imported PDF")
             resetScanState()
             self.importedPDFData = pdfData
             self.scannedImages = [] // Clear any previous images
             processingService.startProcessing(input: .pdf(pdfData))
        }

        // Called by ScanCoordinator when scanning is complete
        func handleScannedImages(images: [UIImage]) {
            print("🖼️ Handling \(images.count) scanned images from Coordinator")
            self.scannedImages = images
            self.importedPDFData = nil // Clear any previous PDF
            showDocumentScanner = false // Close scanner UI
            processingService.startProcessing(input: .images(images))
        }
        
        // Called by ScanCoordinator if scanning fails
        func handleScanError(_ error: Error) {
             print("🚨 Scan failed: \(error.localizedDescription)")
             // TODO: Show error to user more formally (e.g., dedicated alert property)
             processingErrorMessage = "Scanning failed: \(error.localizedDescription)" // Use processing error for now
             showProcessingErrorAlert = true
             showDocumentScanner = false
             resetScanState()
        }
        
        func cancelScan() {
            print("🗑️ User Action: Cancel Scan")
            if isProcessing || scannedImages.count > 0 || importedPDFData != nil {
                showCancelConfirmation = true
            } else {
                // Nothing to cancel, potentially dismiss the view
                resetScanState()
                // Add dismissal logic if needed
            }
        }
        
        func confirmCancel() {
             print("🗑️ Confirmed Cancel")
             processingService.cancelProcessing()
             aiAnalysisService.resetAIState()
             metadataManager.clearForm()
             resetScanState()
             showCancelConfirmation = false
             // Add dismissal logic if needed
        }
        
        func dismissCancelConfirmation() {
             showCancelConfirmation = false
        }
        
        // MARK: - View Navigation Triggers
        
        func presentFolderSelector() {
            showFolderSelector = true
        }
        
        func presentTagSelector() {
            showTagSelector = true
        }
        
        func dismissFolderSelector() {
             showFolderSelector = false
        }
        
        func dismissTagSelector() {
             showTagSelector = false
        }
        
        // MARK: - New User Actions
        
        func triggerDocumentPicker() {
            print("User Action: Trigger Document Picker")
            showingDocumentPicker = true
        }
        
        func handleSelectedDocument(_ result: Result<URL, Error>) {
             showingDocumentPicker = false
             switch result {
             case .success(let url):
                 print("Document selected: \(url)")
                 // TODO: Add proper handling for PDF/Image import 
                 // Check file type, start processing etc.
                 // For now, just log and potentially show save sheet if needed
                 Task {
                     await processImportedDocument(url: url)
                 }
             case .failure(let error):
                 // Handle error, e.g., user cancelled picker
                 if (error as? URLError)?.code != .cancelled {
                     print("Error selecting document: \(error.localizedDescription)")
                     // Optionally show an error alert to the user
                     processingErrorMessage = "Failed to import document: \(error.localizedDescription)"
                     showProcessingErrorAlert = true
                 }
             }
         }
        
        // MARK: - Internal Logic & Processing
        
        // Add placeholder processing for imported documents
        private func processImportedDocument(url: URL) async {
            print("🚀 Attempting to process imported document: \(url)")
 
            do {
                // Ensure the URL is accessible before reading
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
 
                // Read the data
                let data = try Data(contentsOf: url)
 
                // Check if it's a PDF
                if url.pathExtension.lowercased() == "pdf" {
                    print("📄 Detected PDF (\(data.count) bytes). Passing to processing service.")
                    // Pass PDF data to the processing service
                    // This call is synchronous; processing happens via delegate
                    processingService.startProcessing(input: .pdf(data))
                } else {
                    // Handle non-PDF files (Placeholder for now)
                    print("⚠️ Imported file is not a PDF (\(url.pathExtension.lowercased())). Processing for this type not yet implemented.")
                    // Optionally set an error state or show an alert
                    // Example:
                    // await MainActor.run {
                    //     self.processingErrorMessage = "Only PDF imports are currently supported."
                    //     self.showProcessingErrorAlert = true
                    // }
                    // Or potentially handle as images if that's intended later
                    // processingService.startProcessing(input: .images([/* load image from url */]))
                }
            } catch {
                // Handle file reading errors
                print("❌ Error reading imported file: \(error.localizedDescription)")
                await MainActor.run {
                    self.processingErrorMessage = "Failed to read the imported file: \(error.localizedDescription)"
                    self.showProcessingErrorAlert = true
                }
            }
 
             // Note: showDocumentCreationSheet should now be triggered by state changes 
             // from the processingService or aiAnalysisService via observers, not directly here.
        }
        
        // MARK: - Document Saving
        
        // Called from SaveDocumentView
        func saveDocument() {
            print("ViewModel: saveDocument called")
            // Log input data state immediately
            print("💾 Checking input state: processedDocumentData isNil = \(processedDocumentData == nil)")
            // Use the processed document data directly
            guard let dataToSave = processedDocumentData else {
                print("❌ Cannot save: No processed document data found.")
                self.saveErrorMessage = "Cannot save document: No processed data available after scanning or import."
                self.showSaveErrorAlert = true
                return
            }
            
            // Ensure folder exists if selected
            var actualFolderId = selectedFolderId
            
            // Prepare context for saving
            // TODO: Implement proper thumbnail generation from processedDocumentData (PDF)
            let thumbnailData: Data? = nil // Placeholder
            
            let saveContext = ScanPersistenceService.SaveContext(
                title: documentTitle,
                selectedFolderId: actualFolderId, 
                selectedTagIds: selectedTagIds,
                ocrText: extractedOCRText, // Use extracted text
                documentData: dataToSave, // Use processed data
                thumbnailData: thumbnailData, // Pass generated thumbnail (nil for now)
                pendingFolder: metadataManager.pendingFolderToCreate.map { (name: $0.name, id: $0.id) },
                pendingTags: metadataManager.pendingTagsToCreate.map { (name: $0.name, id: $0.id) },
                originalAISuggestions: aiAnalysisService.analysisResult, // Pass suggestions for learning
                inputDataType: .pdf // Assume always PDF now after processing
            )
            
            // Call the persistence service with the context object
            let saveResult = persistenceService.saveDocument(context: saveContext)

            isSaving = false // Reset saving flag regardless of outcome
            
            // Handle the result
            switch saveResult {
            case .success(let savedId):
                print("✅ Document saved successfully! ID: \(savedId)")
                self.lastSavedDocumentId = savedId
                self.lastSavedDocumentTitle = saveContext.title // Use title from context
                // Create UIImage from thumbnail data if available
                // Use the thumbnail data from the context we created
                if let thumbData = saveContext.thumbnailData {
                    self.lastSavedDocumentThumbnail = UIImage(data: thumbData)
                } else {
                    self.lastSavedDocumentThumbnail = nil // Or a placeholder image
                }
                self.showDocumentImportSuccess = true
                // Reset state after successful save
                resetScanState(clearInput: true) // Clear images/pdf too

            case .failure(let error):
                print("❌ Error saving document: \(error)")
                self.saveErrorMessage = "Failed to save document: \(error.localizedDescription)"
                self.showSaveErrorAlert = true
                // Don't reset state on failure, allow user to retry/correct
            }
        }
        
        // MARK: - State Reset
        
        // Resets the state, optionally clearing the input images/PDF data
        func resetScanState(clearInput: Bool = false) {
            let timestamp = Date().formatted(date: .omitted, time: .standard)
            print("🔄 [\(timestamp)] Resetting Scan State... Clear Input: \(clearInput)")
            
            // Clear core metadata
            documentTitle = "Untitled Scan"
            selectedFolderId = nil
            selectedTagIds = []
            comments = ""
            extractedOCRText = nil
            processedDocumentData = nil // Clear processed data
            aiSuggestions = nil
            aiErrorMessage = ""
            suggestedFolderName = nil
            suggestedTagNames = []
            
            metadataManager.clearForm() // Resets title, selections, pending items
            processingService.cancelProcessing() // Ensure any background processing stops
           // Don't need to reset processingService state here, startProcessing does that.
            aiAnalysisService.resetAIState()
            
            isSaving = false
            showSaveErrorAlert = false
            saveErrorMessage = ""
            showCancelConfirmation = false
            lastSavedDocumentThumbnailData = nil
            
            persistenceService.fetchRecentScans() // Refresh recents list
        }
        
        // MARK: - Computed Properties for UI Binding
        
        var availableFolders: [FolderItem] { 
             metadataManager.folders
        }
        
        var availableTags: [TagItem] { 
             metadataManager.tags
        }
        
        var pendingFolderToCreateName: String? { 
             metadataManager.pendingFolderToCreate?.name
        }
        
        var pendingTagsToCreateNames: [String] { 
             metadataManager.pendingTagsToCreate.map { $0.name }
        }
        
        func toggleTagSelection(_ tagId: UUID) {
            metadataManager.toggleTagSelection(tagId)
        }
        
        // Centralized function to ADD a tag by ID (ensures manager is updated)
        func addTagById(_ tagId: UUID) {
            print("▶️ ViewModel.addTagById called for ID: \(tagId)")
            // Call the manager's toggle function. If the tag isn't already selected,
            // this will perform the insertion.
            metadataManager.toggleTagSelection(tagId)
        }
        
        // MARK: - Tag Creation & Selection
        
        /// Creates a new tag with the given name via the MetadataManager and then selects it.
        /// - Parameter name: The name for the new tag.
        func createAndSelectTag(name: String) {
            // Ensure the name is not empty after trimming
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                print("🚫 Attempted to create a tag with an empty name.")
                // Optionally show an error to the user
                // self.saveErrorMessage = "Tag name cannot be empty."
                // self.showSaveErrorAlert = true
                return
            }
            
            print("🏷️ ViewModel attempting to create tag: \(trimmedName)")
            // Call the manager to create the tag
            if let newTagId = metadataManager.createTag(name: trimmedName) {
                print("✅ Tag created successfully by manager with ID: \(newTagId)")
                // If creation was successful, toggle its selection state (which will select it)
                metadataManager.toggleTagSelection(newTagId)
                print("🏷️ Automatically selected new tag: \(trimmedName)")
            } else {
                print("❌ Failed to create tag (likely a duplicate or save error). Manager handled logging.")
                // Optionally handle the failure, e.g., show an error message
                // self.saveErrorMessage = "Failed to create tag. It might already exist."
                // self.showSaveErrorAlert = true
            }
        }
        
        // MARK: - Folder Creation & Selection
        
        func createAndSelectFolder(name: String) {
            // Call the method in the metadata manager to handle selection/pending creation
            print("ViewModel: Requesting folder selection/creation for '\(name)' via MetadataManager")
            metadataManager.selectOrRequestCreateFolder(name: name)
            // The metadataManager will update its @Published selectedFolderId,
            // which ScanViewModel observes and will update its own selectedFolderId.
        }

        // MARK: - Computed Properties for View
        var folders: [FolderItem] { // Expose folders from metadataManager
            metadataManager.folders
        }
        
        var tags: [TagItem] { // Expose tags from metadataManager
            metadataManager.tags
        }
        
        var pendingFolderName: String? { // Expose pending folder name
            metadataManager.pendingFolderToCreate?.name
        }
        
        // MARK: - View Actions (Called from SaveDocumentView)
        
        func addFolder(name: String) -> FolderItem { 
            print("ViewModel: addFolder called with name: \(name)")
            // Call the metadataManager's method and return its result
            let newFolder = metadataManager.addFolder(name: name)
            return newFolder
        }

        func addTag(name: String) -> TagItem { 
             print("ViewModel: addTag called with name: \(name)")
             let newTag = metadataManager.addTag(name: name)
             return newTag
         }

        func getTagsTextFromSelectedIds() -> String { 
            // Create a combined dictionary of ID -> Name for both existing and pending tags
            var allTagNamesById = metadataManager.pendingTagNamesById
            for tag in metadataManager.tags {
                // Prioritize pending tags if an ID collision somehow occurs (shouldn't happen)
                if allTagNamesById[tag.id] == nil {
                    allTagNamesById[tag.id] = tag.name
                }
            }

            // Filter the combined dictionary by selected IDs, get the names, and sort
            let selectedTagNames = selectedTagIds
                .compactMap { allTagNamesById[$0] } // Look up name in combined dictionary
                .sorted()
            
            if selectedTagNames.isEmpty {
                 print("ViewModel: No matching tags found for selected IDs.")
                return "" // Return empty string if no tags are selected
            } else {
                let result = selectedTagNames.joined(separator: ", ")
                 print("ViewModel: Constructed tags string: '\(result)'")
                return result
            }
        }

        func cleanupAllAISuggestions() {
            print("ViewModel: cleanupAllAISuggestions called - STUB")
            // metadataManager.cleanupAllAISuggestions() // Method likely belongs here
            // Also clear local state if necessary
            aiSuggestions = nil
            aiErrorMessage = ""
        }

        func ensureAIAnalysisWithMetadataContext() {
            guard let ocrText = extractedOCRText, !ocrText.isEmpty else {
                print("⏭️ Skipping AI analysis: No OCR text available.")
                return
            }
            
            print("🔍 Ensuring AI analysis is triggered with current context.")
            aiAnalysisService.analyzeDocument(
                ocrText: ocrText,
                folderNames: metadataManager.folders.map { $0.name }, // Pass only names
                tagNames: metadataManager.tags.map { $0.name } // Pass only names
            )
        }

        func debugDocumentState() {
            // TODO: Implement detailed state debugging output
            print("--- DEBUG DOCUMENT STATE ---")
            print("Title: \(documentTitle)")
            print("Folder ID: \(selectedFolderId?.uuidString ?? "None")")
            print("Tag IDs: \(selectedTagIds.map { $0.uuidString }.joined(separator: ", "))")
            print("Comments: \(comments)")
            print("Scanned Images: \(scannedImages.count)")
            print("Imported PDF: \(importedPDFData != nil)")
            print("OCR Text: \(extractedOCRText?.prefix(100) ?? "None")...")
            print("AI Suggestions: \(aiSuggestions != nil ? "Present" : "None")") // Check for presence, not .suggestions
            print("--------------------------")
        }
        
        // MARK: - Private Helper Functions
        
        // --- REMOVED generatePdfFromImages --- 
        
        func cancelScanProcess() {
            print("🛑 ScanViewModel: User initiated cancellation.")
            // TODO: Implement actual cancellation logic
            // - Tell ScanCoordinator to dismiss if active
            // - Stop any ongoing processing (OCR, AI)
            // - Reset relevant state?
            
            // For now, just reset some state maybe?
            scannedImages = []
            importedPDFData = nil
            isProcessing = false
            isPerformingOCR = false
            isAnalyzingDocument = false
            showDocumentCreationSheet = false // Assuming this hides the SaveDocumentView
        }

    } // End of ScanViewModel class

} // End of ViewModels_Scan extension

// MARK: - Document Processing Service Delegate Conformance (Moved to top level)
extension ViewModels_Scan.ScanViewModel: DocumentProcessingServiceDelegate {

    @MainActor
    func documentProcessingServiceDidStartProcessing() {
        print("📄 Delegate: Processing began.")
        self.isProcessing = true
        self.isPerformingOCR = true // Assume OCR starts immediately
        self.processingProgress = 0.0
        self.processingProgressText = "Starting..."
        self.ocrProgress = 0.0
        self.totalPages = 0 // Reset page count
    }

    @MainActor
    func documentProcessingServiceDidUpdateOCRProgress(completedPages: Int, totalPages: Int) {
        print("📊 Delegate: OCR progress: \(completedPages)/\(totalPages) pages completed")
        self.totalPages = totalPages
        // Calculate overall progress based on completed pages
        let overallProgress = totalPages > 0 ? Double(completedPages) / Double(totalPages) : 0.0
        self.ocrProgress = overallProgress // Assign the calculated progress
        self.processingProgress = overallProgress // Keep processingProgress synced? Or remove it?
        self.processingProgressText = String(format: "Processing... %.0f%%", overallProgress * 100)
    }

    @MainActor
    func documentProcessingServiceDidCompleteOCR(fullText: String) {
        print("📄 Delegate: All OCR completed. Full text length: \(fullText.count)")
        self.extractedOCRText = fullText // Store the final OCR text
        self.isPerformingOCR = false
        self.processingProgress = 0.8 // OCR part is done
        self.processingProgressText = "OCR Complete. Starting AI..."
    }
    
    @MainActor
    func documentProcessingServiceDidStartAIAnalysis() {
        print("🤖 Delegate: AI Analysis Started.")
        self.isAnalyzingDocument = true
         self.processingProgress = 0.85 // AI analysis starts
         self.processingProgressText = "Analyzing Document..."
    }

    @MainActor
    func documentProcessingServiceDidReceiveAISuggestions(suggestions: DocumentClassifierService.DocumentSuggestions) {
        print("🧠 Delegate: Received AI suggestions: Title='\(suggestions.suggestedTitle)', Folder='\(suggestions.suggestedFolderName ?? "None")', Tags='\(suggestions.suggestedTags.joined(separator: ", "))'")
        
        // Store raw suggestions
        self.suggestedFolderName = suggestions.suggestedFolderName
        self.suggestedTagNames = suggestions.suggestedTags
        self.aiSuggestions = suggestions // Keep the full suggestion object
        
        // DO NOT automatically apply title suggestion - only store it
        // self.documentTitle = suggestions.suggestedTitle
        
        // Validate folder suggestion but don't apply it automatically
        if let folderName = suggestions.suggestedFolderName, !folderName.isEmpty {
            // Only validate, don't set the selectedFolderId
            if let validFolderId = self.metadataManager.validateSuggestedFolder(name: folderName) {
                print("✅ Valid suggested folder: \(folderName) (ID: \(validFolderId))")
                // Do not auto-apply: self.selectedFolderId = validFolderId
            } else {
                print("❌ Suggested folder '\(folderName)' is invalid or does not exist.")
            }
        }

        // Validate tag suggestions but don't apply them automatically
        if !suggestions.suggestedTags.isEmpty {
            // Use the validation method but don't apply tags automatically
            let validTagIds = self.metadataManager.validateSuggestedTags(names: suggestions.suggestedTags)
            // Do not auto-apply: self.selectedTagIds = validTagIds
            print("✅ Found \(validTagIds.count) valid suggested tags.")
            if validTagIds.count < suggestions.suggestedTags.count {
                print("❌ Some suggested tags were invalid or do not exist.")
            }
        }
        
        self.isAnalyzingDocument = false // AI analysis part is done
        // Notify UI about potential changes
        print("🔄 AI suggestions updated - syncing UI")
        objectWillChange.send() // Force UI update if needed
    }

    @MainActor
    func documentProcessingServiceDidFinishProcessing(error: Error?, finalDocumentData: Data?) {
        self.isProcessing = false
        self.isPerformingOCR = false
        self.isAnalyzingDocument = false
        
        if let error = error {
            print("❌ Delegate: Processing finished with error: \(error.localizedDescription)")
            // Map the specific error if it's a ProcessingError
            if let procError = error as? ProcessingError {
                 self.processingErrorMessage = procError.localizedDescription
            } else {
                 self.processingErrorMessage = error.localizedDescription
            }
            self.showProcessingErrorAlert = true
            self.processingProgress = 0.0
            self.processingProgressText = "Error"
        } else if let finalDocumentData = finalDocumentData { // Use 'let' binding
             print("✅ Delegate: Processing finished successfully.")
             self.processedDocumentData = finalDocumentData // Store processed data
             self.processingProgress = 1.0
             self.processingProgressText = "Complete"
             // --- THIS IS THE NEW TRIGGER ---
             self.showDocumentCreationSheet = true
             print("✅ Triggering document creation sheet.")
             // ------------------------------
        } else {
             // Success case but no data? Should not happen with current flow.
             print("⚠️ Delegate: Processing finished successfully but with no document data.")
             self.processingErrorMessage = "Processing completed but no document data was generated."
             self.showProcessingErrorAlert = true
             self.processingProgress = 0.0
             self.processingProgressText = "Error"
        }
    }

    @MainActor
    func documentProcessingServiceDidEncounterError(error: ProcessingError) {
        print("❌ Delegate: Encountered processing error: \(error.localizedDescription)")
        // Update UI state for error
        self.processingErrorMessage = error.localizedDescription
        self.showProcessingErrorAlert = true
        self.isProcessing = false
        self.isPerformingOCR = false
        self.isAnalyzingDocument = false
        self.processingProgress = 0.0
        self.processingProgressText = "Error"
    }
    
    @MainActor
    func documentProcessingServiceRequiresPremium() {
        print("⚠️ Delegate: Premium required for AI Features.")
        self.showPremiumUpgradePrompt = true
        // Optionally stop further processing or reset state if needed
        self.isProcessing = false
        self.isPerformingOCR = false
        self.isAnalyzingDocument = false
    }
} // End of delegate extension

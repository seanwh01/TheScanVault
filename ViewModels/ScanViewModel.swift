import SwiftUI
import CoreData
import Combine
import Vision
import Foundation

// Forward declare needed types from AppServices instead of importing the module
// This avoids module import issues when the files are compiled together
// The actual definitions come from the AppServices directory

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import AppKit
typealias UIImage = NSImage
typealias UIColor = NSColor
typealias UIBezierPath = NSBezierPath

// Add macOS-compatible extensions for image conversion
extension NSImage {
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        if let cgImage = self.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cgImage
        }
        return nil
    }
    
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: Float(compressionQuality))])
    }
    
    convenience init?(data: Data) {
        self.init(data: data)
    }
}

// Create a cross-platform image renderer
struct ImageRenderer {
    let size: CGSize
    
    func image(actions: @escaping (CGContext) -> Void) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        if let context = NSGraphicsContext.current?.cgContext {
            actions(context)
        }
        
        image.unlockFocus()
        return image
    }
}

// Add macOS extensions for UIBezierPath compatibility
extension NSBezierPath {
    static func fill(_ rect: CGRect) {
        let path = NSBezierPath(rect: rect)
        path.fill()
    }
    
    static func stroke(_ rect: CGRect) {
        let path = NSBezierPath(rect: rect)
        path.stroke()
    }
}

#endif

// Add at the top of your file, after the imports
// Extension removed to avoid redeclaration with Extensions/UserDefaultsExtensions.swift

// Models for UI representation
struct DocumentItem: Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let folderId: UUID?
    let tagIds: [UUID]
    let thumbnail: UIImage?
    let aiModelUsed: String?
    
    var isLocked: Bool {
        DocumentLockManager.shared.isDocumentLocked(id)
    }
}

struct FolderItem: Identifiable {
    let id: UUID
    let name: String
}

struct TagItem: Identifiable {
    let id: UUID
    let name: String
}

// Files in the AppServices directory are compiled as part of the same module
// So explicit imports aren't needed - removing import statement

class ScanViewModel: ObservableObject, DocumentProcessorDelegate {
    @Published var scannedImages: [UIImage] = []
    @Published var isSaving = false
    @Published var recentScans: [DocumentItem] = []
    @Published var folders: [FolderItem] = []
    @Published var tags: [TagItem] = []
    @Published var selectedTagIds: Set<UUID> = []
    
    // Add these new properties for OCR progress tracking
    @Published var isPerformingOCR = false
    @Published var ocrProgress = 0
    @Published var totalOCRPages = 0
    @Published var completedOCRPages = 0
    
    // Add these properties near the top of your ScanViewModel class
    @Published var extractedOCRText: String?
    
    @Published var showingDocumentPicker = false
    @Published var isProcessingUpload = false
    @Published var uploadedImage: UIImage?
    
    // Add these new properties to ScanViewModel
    @Published var pdfPageImages: [UIImage] = []
    @Published var currentPDFPage = 0
    @Published var totalPDFPages = 0
    
    // Add these properties to ScanViewModel
    @Published var showingDocumentCreation = false
    @Published var processedImage: UIImage?
    
    // Add these new properties to ScanViewModel
    @Published var showUnsupportedFileAlert = false
    
    // Add these properties to ScanViewModel
    @Published var aiSuggestions: DocumentClassifierService.DocumentSuggestions?
    @Published var isAnalyzingDocument: Bool = false
    @Published var useAISuggestions: Bool = true
    
    // Add these properties
    @Published var documentTitle: String = ""
    @Published var selectedFolderId: UUID? = nil
    
    // Add these new properties to ScanViewModel
    @Published var showPremiumUpgradePrompt = false
    @Published var showAIError = false
    @Published var aiErrorMessage = ""
    
    // Add a property to store the AI model used
    @Published var aiModelUsed: String = ""
    
    // Add a property to store the original AI suggestions
    var originalAISuggestions: DocumentClassifierService.DocumentSuggestions?
    
    // Add these properties to track AI-created items
    @Published private var aiCreatedFolderIds: [UUID] = []
    @Published private var aiCreatedTagIds: [UUID] = []
    
    // Add these properties to track temporary items (not yet saved to Core Data)
    private(set) var pendingFolderToCreate: (name: String, id: UUID)?
    private var pendingTagsToCreate: [(name: String, id: UUID)] = []
    private var usesPendingCreation: Bool = false
    
    // Add this near the top of your file
    private let adaptiveClassifier = AdaptiveLearningClassifier.shared
    
    private let viewContext = PersistenceController.shared.viewContext
    private var cancellables = Set<AnyCancellable>()
    
    private var persistentContainer: NSPersistentContainer {
        return PersistenceController.shared.container
    }
    
    private var useOpenAI: Bool {
        return UserDefaults.standard.string(forKey: "OpenAIAPIKey") != nil
    }
    
    // Add this property as public instead of private
    public let subscriptionManager: SubscriptionManager
    
    // Add this new property to ScanViewModel
    private var canUseAI: Bool
    
    // Reference to the document processor
    private let documentProcessor: DocumentProcessor
    
    // Properties to track the last saved document for the success screen
    @Published var lastSavedDocumentId: UUID?
    @Published var lastSavedDocumentTitle: String = ""
    @Published var lastSavedDocumentThumbnail: UIImage?
    @Published var showDocumentImportSuccess: Bool = false
    
    init(subscriptionManager: SubscriptionManager = SubscriptionManager()) {
        self.subscriptionManager = subscriptionManager
        
        // Set initial value based on subscription status
        canUseAI = subscriptionManager.isPremium && UserDefaults.isAIDocumentClassificationEnabled
        
        // Initialize the document processor first
        self.documentProcessor = DocumentProcessor.shared
        
        print("🔄 ScanViewModel initialized")
        
        // Setup document processor delegate
        documentProcessor.delegate = self
        
        // Register for subscription change notifications after initializing documentProcessor
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionChange),
            name: NSNotification.Name("SubscriptionStatusChanged"),
            object: nil
        )
        
        fetchFolders()
        fetchTags()
        fetchRecentDocuments()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleSubscriptionChange() {
        // Update canUseAI based on current subscription
        DispatchQueue.main.async {
            self.canUseAI = self.subscriptionManager.isPremium && UserDefaults.isAIDocumentClassificationEnabled
            print("🔄 Forcing document reanalysis after subscription change")
            
            // Re-run AI analysis if we have a document loaded
            if let text = self.extractedOCRText, !text.isEmpty {
                self.ensureAIAnalysisWithMetadataContext(forceNewAnalysis: true)
            }
        }
    }
    
    // MARK: - Document Processing
    
    func processScannedImages(_ images: [UIImage]) {
        // First, completely reset all state from previous documents
        resetStateForNewDocument()
        
        // Reset AI tracking at the start of a new document
        resetAITrackingArrays()
        
        // Store the images
        scannedImages = images
        
        // Use the document processor instead of direct OCR
        documentProcessor.processDocument(images: images)
    }
    
    // MARK: - DocumentProcessorDelegate Methods
    
    func processorDidBeginDocument(_ processor: DocumentProcessor) {
        DispatchQueue.main.async {
            print("📄 Document processing started")
            self.isPerformingOCR = true
            self.ocrProgress = 0
            self.totalOCRPages = self.scannedImages.count
        }
    }
    
    func processor(_ processor: DocumentProcessor, didCompleteOCRForPage pageIndex: Int, withText text: String) {
        DispatchQueue.main.async {
            print("✅ OCR completed for page \(pageIndex + 1)")
            self.completedOCRPages += 1
            
            // Use safe conversion to prevent crashes with infinite or NaN values
            let progressPercentage = (Float(self.completedOCRPages) / Float(self.totalOCRPages)) * 100
            self.ocrProgress = progressPercentage.safeIntValue
        }
    }
    
    func processor(_ processor: DocumentProcessor, didCompleteAllOCRWithText text: String) {
        DispatchQueue.main.async {
            print("✅ OCR completed for all pages")
            self.extractedOCRText = text
            self.isPerformingOCR = false
            self.ocrProgress = 100
            self.isAnalyzingDocument = true
        }
    }
    
    func processor(_ processor: DocumentProcessor, didReceiveAISuggestions suggestions: DocumentClassifierService.DocumentSuggestions) {
        DispatchQueue.main.async {
            print("✅ Received AI suggestions: \(suggestions.suggestedTitle)")
            print("📊 Token usage: \(suggestions.tokenUsage?.totalTokens ?? 0) tokens")
            
            // Store the AI suggestions
            self.aiSuggestions = suggestions
            self.isAnalyzingDocument = false
            
            // Use the model from the actual API call's tokenUsage when available,
            // otherwise fall back to the UserDefaults setting
            if let actualModel = suggestions.tokenUsage?.model {
                self.aiModelUsed = actualModel
                print("🤖 AI model used for document processing: \(actualModel) (from API response)")
            } else {
                // Fallback to UserDefaults only if the API didn't return the model
                self.aiModelUsed = UserDefaults.selectedAIModel
                print("🤖 AI model used for document processing: \(self.aiModelUsed) (from UserDefaults)")
            }
            
            // Print expected folder
            if let folderName = suggestions.suggestedFolderName {
                print("📁 AI suggested folder: \(folderName)")
            }
            
            // Only apply AI suggestions automatically if the document has empty metadata
            // (meaning it's a brand new document, not one being re-analyzed)
            let isNewDocument = self.documentTitle.isEmpty && self.selectedFolderId == nil && self.selectedTagIds.isEmpty
            
            if self.useAISuggestions && isNewDocument {
                print("🔄 Automatically applying AI suggestions to form fields")
                self.applyAISuggestions(suggestions)
                
                // Ensure folder selection is properly updated in UI
                if let folderName = suggestions.suggestedFolderName, 
                   let folderId = self.selectedFolderId {
                    print("📁 Verifying folder selection for UI: \(folderName), ID: \(folderId)")
                    
                    // Double check folder is in local collection
                    if !self.folders.contains(where: { $0.id == folderId }) {
                        let folderItem = FolderItem(id: folderId, name: folderName)
                        self.folders.append(folderItem)
                        print("📁 Added missing folder to local collection: \(folderName)")
                    }
                }
            } else if !isNewDocument {
                print("ℹ️ Document already has metadata - not auto-applying AI suggestions")
                print("  Title: \(self.documentTitle)")
                print("  Folder: \(self.selectedFolderId != nil ? "Selected" : "None")")
                print("  Tags: \(self.selectedTagIds.count)")
            }
        }
    }
    
    func processor(_ processor: DocumentProcessor, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("❌ Document processing error: \(error.localizedDescription)")
            self.isPerformingOCR = false
            self.isAnalyzingDocument = false
            self.showAIError = true
            self.aiErrorMessage = error.localizedDescription
        }
    }
    
    func processorDidFinishProcessing(_ processor: DocumentProcessor) {
        DispatchQueue.main.async {
            print("📋 Document processing complete")
            self.isPerformingOCR = false
            self.isAnalyzingDocument = false
            
            // Make sure any pending folder is properly registered
            self.refreshDocumentDetailsUI()
            
            // Show the document creation view
            if !self.showingDocumentCreation {
                self.showingDocumentCreation = true
            }
        }
    }
    
    // Implement required delegate method for AI enablement
    func isAIEnabledForProcessor(_ processor: DocumentProcessor) -> Bool {
        // Check if premium is active and AI is enabled in settings
        let isEnabled = subscriptionManager.isPremium && UserDefaults.isAIDocumentClassificationEnabled
        print("🔍 AI enabled check for processor: isPremium=\(subscriptionManager.isPremium), AIEnabled=\(UserDefaults.isAIDocumentClassificationEnabled), Result=\(isEnabled)")
        return isEnabled
    }
    
    // MARK: - AI Suggestions
    
    func applyAISuggestions(_ suggestions: DocumentClassifierService.DocumentSuggestions) {
        print("Applying AI suggestions: \(suggestions.suggestedTitle)")
        
        // Apply suggested title
        documentTitle = suggestions.suggestedTitle
        print("📄 Set document title to: \(documentTitle)")
        
        // Apply suggested folder with additional logic
        if let folderName = suggestions.suggestedFolderName {
            print("📁 Creating/selecting folder: \(folderName)")
            
            // Check if folder exists in the list
            if let existingFolder = folders.first(where: { $0.name.lowercased() == folderName.lowercased() }) {
                // Use existing folder
                selectedFolderId = existingFolder.id
                print("✅ Selected existing folder: \(existingFolder.name) with ID: \(existingFolder.id)")
            } else {
                // Create pending folder
                let newFolderId = UUID()
                pendingFolderToCreate = (id: newFolderId, name: folderName)
                print("📁 Created new pending folder: \(folderName) with ID: \(newFolderId)")
                
                // Add to in-memory list
                folders.append(FolderItem(id: newFolderId, name: folderName))
                
                // Set selection
                selectedFolderId = newFolderId
                
                // Add to AI-created tracking
                aiCreatedFolderIds.append(newFolderId)
            }
            
            // Verify folder selection for UI
            print("📁 Verifying folder selection for UI: \(folderName), ID: \(selectedFolderId?.uuidString ?? "nil")")
        } else {
            print("⚠️ No folder suggestion from AI")
        }
        
        // Log folder confidence scores if available
        if let folderConfidences = suggestions.folderConfidences, !folderConfidences.isEmpty {
            print("📊 AI Folder confidence scores:")
            
            // Sort by confidence score (highest first)
            let sortedConfidences = folderConfidences.sorted { $0.value > $1.value }
            
            for (folderName, score) in sortedConfidences {
                // Format score as percentage for readability
                let percentScore = Int(score * 100)
                let isSynthetic = sortedConfidences.count == 1 && folderName == suggestions.suggestedFolderName
                print("   - \(folderName): \(percentScore)%\(isSynthetic ? " (synthetic)" : "")")
            }
            
            // Log the selected folder with its confidence score
            if let selectedFolder = suggestions.suggestedFolderName,
               let selectedFolderScore = folderConfidences[selectedFolder] {
                let percentScore = Int(selectedFolderScore * 100)
                print("📁 Selected folder \"\(selectedFolder)\" with confidence: \(percentScore)%")
                
                // If confidence is particularly low, log a warning
                if percentScore < 30 {
                    print("⚠️ Warning: Selected folder has low confidence score (\(percentScore)%)")
                }
                
                // If this is not the highest confidence folder, log that too
                if let highestConfidenceFolder = sortedConfidences.first?.key,
                   highestConfidenceFolder != selectedFolder {
                    let highestScore = Int(sortedConfidences.first!.value * 100)
                    print("⚠️ Note: \"\(highestConfidenceFolder)\" has higher confidence (\(highestScore)%) than selected folder")
                }
            }
        } else {
            print("⚠️ No folder confidence scores provided by AI")
        }
        
        // Apply suggested tags
        print("🏷️ Clearing existing tag selections")
        selectedTagIds.removeAll()
        
        // Add each suggested tag
        for tagName in suggestions.suggestedTags {
            print("🏷️ Adding/selecting tag: \(tagName)")
            
            // Normalize tag name
            let normalizedTagName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty tags
            if normalizedTagName.isEmpty {
                continue
            }
            
            // Check if tag exists in the list
            if let existingTag = tags.first(where: { $0.name.lowercased() == normalizedTagName.lowercased() }) {
                // Use existing tag
                selectedTagIds.insert(existingTag.id)
                print("✅ Selected existing tag: \(existingTag.name) with ID: \(existingTag.id)")
            } else {
                // Create pending tag
                let newTagId = UUID()
                let newTag = (id: newTagId, name: normalizedTagName)
                pendingTagsToCreate.append(newTag)
                print("📝 Created PENDING tag: \(normalizedTagName) with ID: \(newTagId)")
                
                // Add to in-memory list
                tags.append(TagItem(id: newTagId, name: normalizedTagName))
                
                // Set selection
                selectedTagIds.insert(newTagId)
                
                // Add to AI-created tracking
                aiCreatedTagIds.append(newTagId)
            }
            
            // Log current selection state
            print("🏷️ Current tag selections: \(selectedTagIds.count) tags selected")
        }
        
        print("🏷️ After applying AI tags: \(selectedTagIds.count) tags selected")
        
        // Store original AI suggestions for learning
        originalAISuggestions = suggestions
        
        // Mark that we've applied AI suggestions
        print("✅ AI suggestions fully applied")
        
        // Mark as using pending creation
        usesPendingCreation = true
        
        // For debugging - check the selected folder
        print("📁 Applied folder from AI suggestions: \(suggestions.suggestedFolderName ?? "None")")
        
        // Log the current UI state
        print("📊 UI state after applying AI suggestions:")
        print("   Title: \(documentTitle)")
        print("   Selected Folder ID: \(selectedFolderId?.uuidString ?? "nil")")
        print("   Selected Tags Count: \(selectedTagIds.count)")
        
        // Print folder name if selected
        if let folderId = selectedFolderId {
            if let folder = folders.first(where: { $0.id == folderId }) {
                print("   Selected Folder Name: \(folder.name)")
            } else if let pendingFolder = pendingFolderToCreate, pendingFolder.id == folderId {
                print("   Selected Folder Name: \(pendingFolder.name)")
            }
        }
        
        // Force UI update
        objectWillChange.send()
    }
    
    // MARK: - Folder and Tag Management
    
    private func createOrSelectFolder(_ folderName: String) {
        print("📁 Creating/selecting folder: \(folderName)")
        
        // First check if folder already exists
        if let existingFolder = findFolder(byName: folderName) {
            selectedFolderId = existingFolder.id
            print("📁 Selected existing folder: \(folderName) with ID: \(existingFolder.id)")
            pendingFolderToCreate = nil
        } else if usesPendingCreation {
            // Create a pending folder (will be created on save)
            let newFolderId = UUID()
            selectedFolderId = newFolderId
            pendingFolderToCreate = (name: folderName, id: newFolderId)
            print("📝 Created PENDING folder: \(folderName) with ID: \(newFolderId)")
            
            // Create a temporary FolderItem for UI
            let tempFolder = FolderItem(id: newFolderId, name: folderName)
            folders.append(tempFolder)
            
            // Force UI update to ensure folder selection is visible
            DispatchQueue.main.async {
                print("📁 Updated folder selection to: \(folderName)")
                self.objectWillChange.send()
            }
        } else {
            // Create the folder immediately in Core Data (old approach)
            let newFolder = Folder(context: viewContext)
            newFolder.id = UUID()
            newFolder.name = folderName
            newFolder.createdAt = Date()
            
            do {
                try viewContext.save()
                selectedFolderId = newFolder.id
                aiCreatedFolderIds.append(newFolder.id!)
                print("✅ Created new folder: \(folderName) with ID: \(String(describing: newFolder.id?.uuidString))")
                
                // Refresh folders list
                fetchFolders()
            } catch {
                print("❌ Failed to create folder: \(error.localizedDescription)")
            }
        }
    }
    
    private func addOrSelectTag(_ tagName: String) {
        print("🏷️ Adding/selecting tag: \(tagName)")
        
        // First check if tag already exists
        if let existingTag = findTag(byName: tagName) {
            let tagId = existingTag.id
            selectedTagIds.insert(tagId)
            print("✅ Selected existing tag: \(tagName) with ID: \(tagId)")
        } else if usesPendingCreation {
            // Create a pending tag (will be created on save)
            let newTagId = UUID()
            selectedTagIds.insert(newTagId)
            pendingTagsToCreate.append((name: tagName, id: newTagId))
            print("📝 Created PENDING tag: \(tagName) with ID: \(newTagId)")
            
            // Create a temporary TagItem for UI
            let tempTag = TagItem(id: newTagId, name: tagName)
            tags.append(tempTag)
        } else {
            // Create the tag immediately in Core Data (old approach)
            let newTag = Tag(context: viewContext)
            newTag.id = UUID()
            newTag.name = tagName
            newTag.createdAt = Date()
            
            do {
                try viewContext.save()
                let tagId = newTag.id!
                selectedTagIds.insert(tagId)
                aiCreatedTagIds.append(tagId)
                print("✅ Created and selected new tag: \(tagName) with ID: \(tagId)")
                
                // Refresh tags list
                fetchTags()
            } catch {
                print("❌ Failed to create tag: \(error.localizedDescription)")
            }
        }
        
        // Log current selections for debugging
        print("🏷️ Current tag selections: \(selectedTagIds.count) tags selected")
    }
    
    private func findFolder(byName name: String) -> FolderItem? {
        return folders.first { $0.name.lowercased() == name.lowercased() }
    }
    
    private func findTag(byName name: String) -> TagItem? {
        return tags.first { $0.name.lowercased() == name.lowercased() }
    }
    
    // MARK: - Data Fetching
    
    func fetchFolders() {
        let request = NSFetchRequest<Folder>(entityName: "Folder")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let fetchedFolders = try viewContext.fetch(request)
            folders = fetchedFolders.compactMap { folder in
                guard let id = folder.id, let name = folder.name else { return nil }
                return FolderItem(id: id, name: name)
            }
        } catch {
            print("Error fetching folders: \(error.localizedDescription)")
        }
    }
    
    func fetchTags() {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let fetchedTags = try viewContext.fetch(request)
            tags = fetchedTags.compactMap { tag in
                guard let id = tag.id, let name = tag.name else { return nil }
                return TagItem(id: id, name: name)
            }
        } catch {
            print("Error fetching tags: \(error.localizedDescription)")
        }
    }
    
    func fetchRecentDocuments() {
        let request = NSFetchRequest<Document>(entityName: "Document")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
        request.fetchLimit = 10
        
        do {
            let fetchedDocuments = try viewContext.fetch(request)
            
            // First filter out documents with missing required properties
            let validDocuments = fetchedDocuments.filter { document in
                return document.id != nil && document.title != nil && document.createdAt != nil
            }
            
            // Then map to DocumentItem
            recentScans = validDocuments.map { document in
                // Create thumbnail from document data
                var thumbnail: UIImage? = nil
                if let thumbnailData = document.thumbnail {
                    thumbnail = UIImage(data: thumbnailData)
                }
                
                // Get the AI model if available - safely with try/catch
                var aiModel: String? = nil
                // Try to get the value only if the property exists
                if let _ = document.entity.propertiesByName["aiModelUsed"] {
                    aiModel = document.value(forKey: "aiModelUsed") as? String
                }
                
                return DocumentItem(
                    id: document.id!,
                    title: document.title!,
                    createdAt: document.createdAt!,
                    folderId: document.folderId,
                    tagIds: document.tags?.compactMap { ($0 as? Tag)?.id } ?? [],
                    thumbnail: thumbnail,
                    aiModelUsed: aiModel
                )
            }
        } catch {
            print("Error fetching recent documents: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetAITrackingArrays() {
        aiCreatedFolderIds = []
        aiCreatedTagIds = []
    }
    
    // MARK: - PDF Processing
    
    func handleSelectedDocument(_ url: URL) {
        print("📄 Processing selected document: \(url.path)")
        
        // Reset state before processing new document
        resetStateForNewDocument()
        
        isProcessingUpload = true
        
        // Handle different file types
        let fileExtension = url.pathExtension.lowercased()
        
        print("📄 Document type: \(fileExtension)")
        
        switch fileExtension {
        case "pdf":
            processPDF(url: url)
        case "jpg", "jpeg", "png", "tiff", "heic":
            processImage(url: url)
        default:
            print("❌ Unsupported file type: \(fileExtension)")
            isProcessingUpload = false
            // Show an alert to the user
            DispatchQueue.main.async {
                self.showUnsupportedFileAlert = true
            }
        }
    }
    
    private func processImage(url: URL) {
        // Load the image from the URL
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to load image from URL: \(url.path)")
            isProcessingUpload = false
            return
        }
        
        // Set as the uploaded image
        uploadedImage = image
        
        // Process through document processor
        documentProcessor.processDocument(images: [image])
    }
    
    private func processPDF(url: URL) {
        print("🔄 Processing PDF: \(url.path)")
        
        // Check file existence first
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ PDF file does not exist at path: \(url.path)")
            isProcessingUpload = false
            return
        }
        
        // Try to create CGPDFDocument
        guard let pdfDocument = CGPDFDocument(url as CFURL) else {
            print("❌ Failed to create CGPDFDocument from URL")
            isProcessingUpload = false
            return
        }
        
        print("✅ PDF opened successfully with \(pdfDocument.numberOfPages) pages")
        
        // Count pages
        totalPDFPages = pdfDocument.numberOfPages
        pdfPageImages = []
        
        if totalPDFPages == 0 {
            print("❌ PDF has no pages")
            isProcessingUpload = false
            return
        }
        
        // Create a dispatch group to track page processing
        let group = DispatchGroup()
        
        // Convert each page to an image
        var processedImages = [Int: UIImage]() // Store images with their page numbers
        for pageNum in 1...totalPDFPages {
            group.enter()
            
            guard let page = pdfDocument.page(at: pageNum) else {
                print("⚠️ Could not access page \(pageNum)")
                group.leave()
                continue
            }
            
            let pageRect = page.getBoxRect(.mediaBox)
            print("📄 Processing page \(pageNum): size = \(pageRect.size)")
            
            // Use a background queue for rendering
            DispatchQueue.global(qos: .userInitiated).async {
                #if os(macOS)
                // On macOS, use our custom renderer
                let renderer = ImageRenderer(size: pageRect.size)
                #else
                // On iOS, use UIKit's renderer
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                #endif
                
                let image = renderer.image { ctx in
                    // Fill the background with white
                    UIColor.white.set()
                    #if os(macOS)
                    // On macOS, we're already passing a CGContext directly
                    ctx.fill(CGRect(origin: .zero, size: pageRect.size))
                    
                    // Flip the coordinate system
                    ctx.translateBy(x: 0, y: pageRect.size.height)
                    ctx.scaleBy(x: 1.0, y: -1.0)
                    
                    // Draw the PDF page
                    ctx.drawPDFPage(page)
                    #else
                    // On iOS, we need to access the cgContext property
                    ctx.cgContext.fill(CGRect(origin: .zero, size: pageRect.size))
                    
                    // Flip the coordinate system
                    ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                    
                    // Draw the PDF page
                    ctx.cgContext.drawPDFPage(page)
                    #endif
                }
                
                // Store the image with its page number
                DispatchQueue.main.async {
                    processedImages[pageNum] = image
                    print("✅ Processed page \(pageNum) image")
                    group.leave()
                }
            }
        }
        
        // When all pages are processed
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Sort images by page number and add them to pdfPageImages
            self.pdfPageImages = (1...self.totalPDFPages).compactMap { processedImages[$0] }
            
            print("✅ Extracted \(self.pdfPageImages.count) images from PDF in correct order")
            
            // Check if we have all pages
            if self.pdfPageImages.count != self.totalPDFPages {
                print("⚠️ Warning: Expected \(self.totalPDFPages) pages but processed \(self.pdfPageImages.count)")
            }
            
            // Set the first page as the current image
            self.uploadedImage = self.pdfPageImages.first
            self.currentPDFPage = 1
            
            // Process the PDF pages through the document processor
            self.documentProcessor.processDocument(images: self.pdfPageImages)
        }
    }
    
    // MARK: - Document Saving
    
    func saveDocument() {
        isSaving = true
        
        // Process any pending folder/tag creations before saving document
        processPendingMetadata()
        
        // Update adaptive learning classifier with user changes
        updateAdaptiveClassifier()
        
        // Create new document
        let newDocument = Document(context: viewContext)
        newDocument.entityId = UUID()
        newDocument.title = documentTitle
        newDocument.createdAt = Date()
        newDocument.updatedAt = Date()  // Set the updatedAt time to match createdAt for new documents
        
        // Set folder if one is selected - IMPORTANT: use folderId string instead of folder relationship
        if let folderId = selectedFolderId {
            print("📁 Setting folder ID for document: \(folderId)")
            newDocument.folderId = folderId
            
            // For debugging, verify the folder exists
            if let folder = fetchFolder(byId: folderId) {
                print("✅ Verified folder exists with name: \(folder.name ?? "unknown")")
            } else {
                print("⚠️ Warning: Setting folderId \(folderId) but folder doesn't exist in Core Data yet")
            }
        } else {
            print("📂 No folder selected for document")
        }
        
        // Add tags
        for tagId in selectedTagIds {
            if let tag = fetchTag(byId: tagId) {
                // Add to the relationship
                if newDocument.tags == nil {
                    newDocument.tags = NSSet()
                }
                newDocument.tags = newDocument.tags?.addingObjects(from: [tag]) as NSSet?
            }
        }
        
        // Create a PDF document from scanned images or PDF pages
        var firstImage: UIImage? = nil
        
        if !scannedImages.isEmpty {
            if let pdfData = createPDFFromImages(scannedImages) {
                newDocument.documentData = pdfData
                
                // Save first image for success screen
                firstImage = scannedImages.first
                
                // Create thumbnail from scanned images
                if let firstScanImage = scannedImages.first,
                   let thumbnailData = generateThumbnail(from: firstScanImage) {
                    newDocument.thumbnail = thumbnailData
                }
            }
        } else if !pdfPageImages.isEmpty {
            if let pdfData = createPDFFromImages(pdfPageImages) {
                newDocument.documentData = pdfData
                
                // Save first image for success screen
                firstImage = pdfPageImages.first
                
                // Create thumbnail from PDF pages
                if let firstPdfImage = pdfPageImages.first,
                   let thumbnailData = generateThumbnail(from: firstPdfImage) {
                    newDocument.thumbnail = thumbnailData
                }
            }
        }
        
        // Save OCR text if available
        if let ocrText = extractedOCRText {
            newDocument.text = ocrText
        }
        
        // Add AI model information to document history - only if the property exists
        if !aiModelUsed.isEmpty {
            // Check if the property exists on the entity
            if let _ = newDocument.entity.propertiesByName["aiModelUsed"] {
                newDocument.setValue(aiModelUsed, forKey: "aiModelUsed")
                print("🤖 Saved AI model information: \(aiModelUsed)")
            } else {
                print("⚠️ Note: aiModelUsed property doesn't exist in Core Data model - skipping")
            }
        }
        
        // Save the document
        do {
            try viewContext.save()
            print("✅ Document saved successfully with ID: \(String(describing: newDocument.id?.uuidString))")
            
            // Store information for success screen
            lastSavedDocumentId = newDocument.id
            lastSavedDocumentTitle = documentTitle
            lastSavedDocumentThumbnail = firstImage
            showDocumentImportSuccess = true
            
            // Post notification for document creation with all relevant information
            if let docId = newDocument.id {
                let userInfo: [String: Any] = [
                    "documentId": docId,
                    "title": documentTitle,
                    "hasFolder": selectedFolderId != nil,
                    "tagCount": selectedTagIds.count,
                    "hasOCR": extractedOCRText != nil,
                    "usedAI": aiSuggestions != nil
                ]
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentCreated"),
                    object: nil,
                    userInfo: userInfo
                )
                print("📢 Posted DocumentCreated notification")
            }
            
            isSaving = false
            fetchRecentDocuments()
            
            // Clean up any unused AI-created tags or folders
            cleanupUnusedAICreatedItems()
            
            // Clear the document state
            resetStateForNewDocument()
        } catch {
            print("❌ Error saving document: \(error.localizedDescription)")
            isSaving = false
        }
    }
    
    // Process pending folders and tags created during AI processing
    private func processPendingMetadata() {
        print("📊 Processing pending metadata before saving document")
        
        // Create any pending folder
        if let pendingFolder = pendingFolderToCreate {
            print("📁 Creating pending folder in Core Data: \(pendingFolder.name) with ID: \(pendingFolder.id)")
            
            let newFolder = Folder(context: viewContext)
            newFolder.id = pendingFolder.id
            newFolder.name = pendingFolder.name
            newFolder.createdAt = Date()
            
            do {
                try viewContext.save()
                print("✅ Successfully created folder in Core Data: \(pendingFolder.name)")
                aiCreatedFolderIds.append(pendingFolder.id)
            } catch {
                print("❌ Failed to create pending folder: \(error.localizedDescription)")
            }
        } else {
            print("📂 No pending folders to create")
        }
        
        // Create any pending tags
        if !pendingTagsToCreate.isEmpty {
            print("🏷️ Creating \(pendingTagsToCreate.count) pending tags in Core Data")
            
            for pendingTag in pendingTagsToCreate {
                let newTag = Tag(context: viewContext)
                newTag.id = pendingTag.id
                newTag.name = pendingTag.name
                newTag.createdAt = Date()
                
                // Save each tag individually to avoid one failure affecting others
                do {
                    try viewContext.save()
                    print("✅ Created tag: \(pendingTag.name)")
                    aiCreatedTagIds.append(pendingTag.id)
                } catch {
                    print("❌ Failed to create tag \(pendingTag.name): \(error.localizedDescription)")
                }
            }
            
            print("✅ Completed processing \(pendingTagsToCreate.count) tags")
        } else {
            print("🏷️ No pending tags to create")
        }
        
        // Update actual folders and tags lists after saving
        fetchFolders()
        fetchTags()
        
        // Clear pending lists
        pendingFolderToCreate = nil
        pendingTagsToCreate = []
        usesPendingCreation = false
    }
    
    private func fetchFolder(byId id: UUID) -> Folder? {
        let request = NSFetchRequest<Folder>(entityName: "Folder")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            print("Error fetching folder: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func fetchTag(byId id: UUID) -> Tag? {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            print("Error fetching tag: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func resetState() {
        // First clean up any unused AI-created items
        cleanupUnusedAICreatedItems()
        
        // Also clear any pending metadata
        pendingFolderToCreate = nil
        pendingTagsToCreate = []
        usesPendingCreation = false
        
        scannedImages = []
        pdfPageImages = []
        documentTitle = ""
        selectedFolderId = nil
        selectedTagIds = []
        extractedOCRText = nil
        aiSuggestions = nil
        uploadedImage = nil
        originalAISuggestions = nil
        aiModelUsed = ""
        
        // No need to reset the tracking arrays here as cleanupUnusedAICreatedItems already did that
    }
    
    private func createPDFFromImages(_ images: [UIImage]) -> Data? {
        let pdfData = NSMutableData()
        
        #if os(macOS)
        // Create PDF context for macOS
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!,
                                         mediaBox: nil,
                                         nil) else {
            return nil
        }
        
        for image in images {
            // Calculate page size based on the image
            let imageSize = image.size
            let pdfPageBounds = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            
            pdfContext.beginPage(mediaBox: &CGRect(origin: .zero, size: imageSize))
            
            // Draw the image if we can get the CGImage
            if let cgImage = image.cgImage {
                pdfContext.draw(cgImage, in: pdfPageBounds)
            }
            
            pdfContext.endPage()
        }
        
        pdfContext.closePDF()
        #else
        // iOS PDF creation
        UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
        
        for image in images {
            // Calculate page size based on the image
            let imageSize = image.size
            let pdfPageBounds = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            
            UIGraphicsBeginPDFPageWithInfo(pdfPageBounds, nil)
            
            // Simply draw the image directly
            image.draw(in: pdfPageBounds)
        }
        
        UIGraphicsEndPDFContext()
        #endif
        
        return pdfData as Data
    }
    
    private func generateThumbnail(from image: UIImage) -> Data? {
        // Create a larger thumbnail with better quality
        let size = CGSize(width: 200, height: 250)
        
        #if os(macOS)
        let renderer = ImageRenderer(size: size)
        #else
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        #endif
        
        let thumbnail: UIImage
        
        #if os(macOS)
        thumbnail = renderer.image { ctx in
            // Fill with a light background color for better visibility
            NSColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Calculate aspect ratio to maintain proportions
            let imageAspect = image.size.width / image.size.height
            let thumbnailAspect = size.width / size.height
            
            var drawRect = CGRect(origin: .zero, size: size)
            
            // Adjust rectangle to maintain aspect ratio
            if imageAspect > thumbnailAspect {
                // Image is wider than thumbnail
                let newHeight = size.width / imageAspect
                let yOffset = (size.height - newHeight) / 2
                drawRect = CGRect(x: 0, y: yOffset, width: size.width, height: newHeight)
            } else {
                // Image is taller than thumbnail
                let newWidth = size.height * imageAspect
                let xOffset = (size.width - newWidth) / 2
                drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: size.height)
            }
            
            // Draw the image with proper aspect ratio
            if let cgImage = image.cgImage {
                ctx.draw(cgImage, in: drawRect)
            }
            
            // Add a subtle border
            NSColor.gray.withAlphaComponent(0.3).setStroke()
            ctx.stroke(CGRect(origin: .zero, size: size))
        }
        #else
        // Fill with a light background color for better visibility
        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        
        // Calculate aspect ratio to maintain proportions
        let imageAspect = image.size.width / image.size.height
        let thumbnailAspect = size.width / size.height
        
        var drawRect = CGRect(origin: .zero, size: size)
        
        // Adjust rectangle to maintain aspect ratio
        if imageAspect > thumbnailAspect {
            // Image is wider than thumbnail
            let newHeight = size.width / imageAspect
            let yOffset = (size.height - newHeight) / 2
            drawRect = CGRect(x: 0, y: yOffset, width: size.width, height: newHeight)
        } else {
            // Image is taller than thumbnail
            let newWidth = size.height * imageAspect
            let xOffset = (size.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: size.height)
        }
        
        // Draw the image with proper aspect ratio
        image.draw(in: drawRect)
        
        // Add a subtle border
        UIColor.gray.withAlphaComponent(0.3).setStroke()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).stroke()
        
        thumbnail = UIGraphicsGetImageFromCurrentImageContext()!
        #endif
        
        // Use higher compression quality (0.9 instead of 0.7)
        return thumbnail.jpegData(compressionQuality: 0.9)
    }
    
    // MARK: - Document Picker

    func showDocumentPicker() {
        showingDocumentPicker = true
    }
    
    // MARK: - Subscription Management
    
    func updateSubscriptionManager(_ manager: SubscriptionManager) {
        // No need to actually update since the subscriptionManager is already set in init,
        // but keeping this method for compatibility with views that call it
        print("Subscription manager update called - note that this is a no-op")
        
        // Check if subscription status changed to premium
        if manager.isPremium && UserDefaults.isAIDocumentClassificationEnabled {
            print("🔄 Subscription upgraded to premium with AI enabled - triggering document reanalysis")
            triggerDocumentReanalysis()
        }
    }
    
    // Method to trigger document reanalysis when subscription changes
    func triggerDocumentReanalysis() {
        // Skip if there's no document to analyze
        guard let ocrText = extractedOCRText, !ocrText.isEmpty else {
            print("⚠️ No document text available for reanalysis")
            return
        }
        
        print("🔄 Forcing document reanalysis after subscription change")
        
        // Reset AI state
        aiSuggestions = nil
        originalAISuggestions = nil
        isAnalyzingDocument = false
        
        // Force analyzing the document with special flag for reanalysis
        print("🔄 Document processor state is being reset - forcing reanalysis")
        
        // Force analyzing the document
        ensureAIAnalysisWithMetadataContext(forceNewAnalysis: true)
    }
    
    // Method to add a new tag
    func addTag(name: String) -> TagItem {
        let context = PersistenceController.shared.container.viewContext
        let newTag = Tag(context: context)
        newTag.id = UUID()
        newTag.name = name
        
        do {
            try context.save()
            
            // Create a TagItem for UI
            let tagItem = TagItem(id: newTag.id!, name: name)
            
            // Update the tags list
            self.tags.append(tagItem)
            
            return tagItem
        } catch {
            print("Error saving new tag: \(error)")
            // Return a placeholder in case of error
            return TagItem(id: UUID(), name: name)
        }
    }
    
    // Method to get tags as a comma-separated string
    func getTagsTextFromSelectedIds() -> String {
        // Handle empty case
        if selectedTagIds.isEmpty {
            return ""
        }
        
        print("🔍 Getting tag text for \(selectedTagIds.count) selected tag IDs")
        
        // Create a direct array lookup approach instead of a fetch request
        let selectedTagNames = selectedTagIds.compactMap { tagId -> String? in
            if let tag = tags.first(where: { $0.id == tagId }) {
                print("✅ Found tag: \(tag.name) for ID: \(tagId)")
                return tag.name
            }
            print("⚠️ Could not find tag for ID: \(tagId)")
            return nil
        }
        
        let result = selectedTagNames.joined(separator: ", ")
        print("📝 Returning tag text: \"\(result)\"")
        return result
    }
    
    // Method to start the scanning process
    func startScanning() {
        // Clear previous scanned images
        scannedImages = []
        
        // Any other setup for scanning
        print("Starting document scan...")
    }
    
    // Method to create a new folder
    func addFolder(name: String) -> FolderItem {
        let context = PersistenceController.shared.container.viewContext
        let newFolder = Folder(context: context)
        newFolder.id = UUID()
        newFolder.name = name
        newFolder.createdAt = Date()
        
        do {
            try context.save()
            
            // Create a FolderItem for UI
            let folderItem = FolderItem(id: newFolder.id!, name: name)
            
            // Update the folders list
            self.folders.append(folderItem)
            
            return folderItem
        } catch {
            print("Error saving new folder: \(error)")
            // Return a placeholder in case of error
            return FolderItem(id: UUID(), name: name)
        }
    }
    
    // Method to create and select a folder by name
    func createAndSelectFolder(name: String) {
        // First check if folder already exists
        if let existingFolder = findFolder(byName: name) {
            selectedFolderId = existingFolder.id
            print("📁 Selected existing folder: \(name) with ID: \(existingFolder.id)")
        } else {
            // Create the folder
            let folderItem = addFolder(name: name)
            selectedFolderId = folderItem.id
            print("✅ Created and selected new folder: \(name) with ID: \(folderItem.id)")
        }
    }
    
    // Method to manually apply AI suggestions
    func manuallyApplyAISuggestions() {
        guard let suggestions = self.aiSuggestions else {
            print("⚠️ No AI suggestions available to apply")
            return
        }
        
        print("👤 Manually applying AI suggestions")
        applyAISuggestions(suggestions)
        
        // Force UI update
        objectWillChange.send()
    }
    
    // Add a new method to force-update tag selections
    func forceUpdateTagSelections() {
        // This forces a UI update by triggering objectWillChange
        print("🔄 Forcing update of tag selections in UI")
        let currentSelections = selectedTagIds
        selectedTagIds = []
        objectWillChange.send()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedTagIds = currentSelections
            self.objectWillChange.send()
            print("✅ Tag selections restored with \(self.selectedTagIds.count) tags")
        }
    }
    
    // Method to cleanup AI suggestions to prevent memory leaks
    func cleanupAllAISuggestions() {
        aiSuggestions = nil
        originalAISuggestions = nil
        isAnalyzingDocument = false
        
        // Additional cleanup if needed
        print("🧹 Cleaned up all AI suggestions")
    }
    
    // Method to cleanup unused AI-created items
    func cleanupUnusedAICreatedItems() {
        print("🧹 Starting cleanup of unused AI-created items")
        print("   AI-created folders: \(aiCreatedFolderIds.count)")
        print("   AI-created tags: \(aiCreatedTagIds.count)")
        
        // Skip if nothing to clean up
        if aiCreatedFolderIds.isEmpty && aiCreatedTagIds.isEmpty {
            print("✅ No AI-created items to clean up")
            return
        }
        
        // Get context for database operations
        let context = PersistenceController.shared.container.viewContext
        
        // Clean up unused folders
        var foldersRemoved = 0
        for folderId in aiCreatedFolderIds {
            // If this folder was not selected for the document, delete it
            if selectedFolderId != folderId {
                // Fetch the folder
                let request = NSFetchRequest<Folder>(entityName: "Folder")
                request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                request.fetchLimit = 1
                
                do {
                    if let folder = try context.fetch(request).first {
                        print("🗑️ Removing unused AI-created folder: \(folder.name ?? "unknown")")
                        context.delete(folder)
                        foldersRemoved += 1
                    }
                } catch {
                    print("❌ Error fetching folder to delete: \(error.localizedDescription)")
                }
            } else {
                print("✅ Keeping folder with ID \(folderId) as it was selected for the document")
            }
        }
        
        // Clean up unused tags
        var tagsRemoved = 0
        for tagId in aiCreatedTagIds {
            // If this tag was not selected for the document, delete it
            if !selectedTagIds.contains(tagId) {
                // Fetch the tag
                let request = NSFetchRequest<Tag>(entityName: "Tag")
                request.predicate = NSPredicate(format: "id == %@", tagId as CVarArg)
                request.fetchLimit = 1
                
                do {
                    if let tag = try context.fetch(request).first {
                        print("🗑️ Removing unused AI-created tag: \(tag.name ?? "unknown")")
                        context.delete(tag)
                        tagsRemoved += 1
                    }
                } catch {
                    print("❌ Error fetching tag to delete: \(error.localizedDescription)")
                }
            } else {
                print("✅ Keeping tag with ID \(tagId) as it was selected for the document")
            }
        }
        
        // Save context if we deleted anything
        if foldersRemoved > 0 || tagsRemoved > 0 {
            do {
                try context.save()
                print("✅ Cleanup complete - removed \(foldersRemoved) folders and \(tagsRemoved) tags")
            } catch {
                print("❌ Error saving after cleanup: \(error.localizedDescription)")
            }
        }
        
        // Clear the tracking arrays
        aiCreatedFolderIds.removeAll()
        aiCreatedTagIds.removeAll()
    }
    
    // Debug method to log current document state
    func debugDocumentState() {
        print("📄 Document State:")
        print("  Title: \(documentTitle)")
        print("  Selected Folder ID: \(selectedFolderId?.uuidString ?? "nil")")
        print("  Selected Tag Count: \(selectedTagIds.count)")
        print("  OCR Text Length: \(extractedOCRText?.count ?? 0) characters")
        print("  AI Suggestions Available: \(aiSuggestions != nil)")
    }
    
    // Method to ensure AI analysis happens with metadata context
    func ensureAIAnalysisWithMetadataContext(forceNewAnalysis: Bool = false) {
        // Add logging for subscription and AI status
        print("🔍 Checking AI eligibility: Premium=\(subscriptionManager.isPremium), AIEnabled=\(UserDefaults.isAIDocumentClassificationEnabled)")
        
        // Skip if not premium or AI is disabled
        if !subscriptionManager.isPremium || !UserDefaults.isAIDocumentClassificationEnabled {
            print("⚠️ Skipping AI analysis: isPremium=\(subscriptionManager.isPremium), AIEnabled=\(UserDefaults.isAIDocumentClassificationEnabled)")
            return
        }
        
        // Skip if no OCR text available
        guard let ocrText = extractedOCRText, !ocrText.isEmpty else {
            print("⚠️ No OCR text available for AI analysis")
            return
        }
        
        // Skip if already analyzing
        if isAnalyzingDocument {
            print("⚠️ AI analysis already in progress")
            return
        }
        
        print("🔍 Starting AI analysis with metadata context")
        isAnalyzingDocument = true
        
        // Fetch metadata from Core Data to enrich the context
        let context = PersistenceController.shared.container.viewContext
        
        // Fetch existing document titles (for context)
        var existingTitles: [String] = []
        let documentRequest = NSFetchRequest<Document>(entityName: "Document")
        documentRequest.propertiesToFetch = ["title"]
        documentRequest.fetchLimit = 25 // Increased from 10 to provide more context
        if let documents = try? context.fetch(documentRequest) {
            existingTitles = documents.compactMap { $0.title }
            print("📚 Fetched \(existingTitles.count) document titles for AI context")
        }
        
        // Fetch existing tags
        var existingTags: [String] = []
        let tagRequest = NSFetchRequest<Tag>(entityName: "Tag")
        tagRequest.fetchLimit = 50 // Increased from 20 to provide more context
        if let tags = try? context.fetch(tagRequest) {
            existingTags = tags.compactMap { $0.name }
            print("🏷️ Fetched \(existingTags.count) tags for AI context: \(existingTags.joined(separator: ", "))")
        }
        
        // Fetch existing folders
        var existingFolders: [String] = []
        let folderRequest = NSFetchRequest<Folder>(entityName: "Folder")
        folderRequest.fetchLimit = 25 // Increased from 20 to provide more context
        if let folders = try? context.fetch(folderRequest) {
            existingFolders = folders.compactMap { $0.name }
            print("📁 Fetched \(existingFolders.count) folders for AI context: \(existingFolders.joined(separator: ", "))")
        }
        
        // Build metadata context
        let metadataContext: [String: Any] = [
            "existingTitles": existingTitles,
            "existingTags": existingTags,
            "existingFolders": existingFolders,
            // Add a force flag to ensure analysis happens
            "forceAnalysis": forceNewAnalysis
        ]
        
        print("🔄 Sending metadata context to AI with:")
        print("   - \(existingTitles.count) document titles")
        print("   - \(existingTags.count) tags")
        print("   - \(existingFolders.count) folders")
        print("   - Force analysis flag: \(forceNewAnalysis)")
        
        // Use the document processor to analyze with metadata
        documentProcessor.analyzeDocumentText(ocrText, withMetadata: metadataContext) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzingDocument = false
                
                switch result {
                case .success(let suggestions):
                    print("✅ AI analysis completed successfully")
                    self.aiSuggestions = suggestions
                    self.originalAISuggestions = suggestions
                    
                    // Apply suggestions if enabled and fields are empty
                    if self.useAISuggestions && self.documentTitle.isEmpty {
                        print("🔄 Applying AI suggestions from metadata context analysis")
                        self.applyAISuggestions(suggestions)
                        
                        // Make sure UI is updated properly
                        self.refreshDocumentDetailsUI()
                    }
                case .failure(let error):
                    print("❌ AI analysis failed: \(error.localizedDescription)")
                    self.showAIError = true
                    self.aiErrorMessage = "Failed to analyze document: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Method to refresh tags from Core Data
    func refreshTags() {
        print("🔄 Refreshing tags from Core Data")
        fetchTags()
        
        // After refreshing, force a UI update
        objectWillChange.send()
        
        // Log the state of tag selections
        let tagNames = getTagsTextFromSelectedIds()
        print("📝 Current tag selections after refresh: \(tagNames)")
    }
    
    // Method to cancel document creation
    func cancelDocumentCreation() {
        print("❌ User cancelled document creation")
        
        // Clear pending metadata
        if usesPendingCreation {
            print("🧹 Clearing pending metadata on cancel")
            if let pendingFolder = pendingFolderToCreate {
                print("   Discarded pending folder: \(pendingFolder.name)")
                
                // Remove from UI if this folder ID is selected
                if selectedFolderId == pendingFolder.id {
                    selectedFolderId = nil
                }
                
                // Remove from in-memory array
                folders.removeAll { $0.id == pendingFolder.id }
            }
            
            if !pendingTagsToCreate.isEmpty {
                print("   Discarded pending tags: \(pendingTagsToCreate.map { $0.name }.joined(separator: ", "))")
                
                // Remove pending tag IDs from selection and in-memory array
                let pendingTagIds = pendingTagsToCreate.map { $0.id }
                for tagId in pendingTagIds {
                    selectedTagIds.remove(tagId)
                }
                
                tags.removeAll { tag in pendingTagIds.contains(tag.id) }
            }
            
            // Clear pending lists
            pendingFolderToCreate = nil
            pendingTagsToCreate = []
        }
        
        // For non-pending items, clean up AI-created items properly
        cleanupUnusedAICreatedItems()
        
        // Reset state
        resetState()
        
        // Close document creation view
        showingDocumentCreation = false
        
        // Reset pending creation flag
        usesPendingCreation = false
        
        print("✅ Document creation cancelled and resources cleaned up")
    }
    
    // Helper method to verify cleanup
    private func verifyCleanup() {
        // Additional verification can be added here if needed
        if !aiCreatedFolderIds.isEmpty || !aiCreatedTagIds.isEmpty {
            print("⚠️ WARNING: Some AI-created items were not cleaned up:")
            print("   Folders: \(aiCreatedFolderIds.count), Tags: \(aiCreatedTagIds.count)")
            // Force a final cleanup attempt
            cleanupUnusedAICreatedItems()
        } else {
            print("✅ Verification complete - all AI-created items were properly cleaned up")
        }
    }
    
    // Method to manually trigger AI analysis
    func manuallyTriggerAIAnalysis() {
        print("👤 User manually triggered AI analysis")
        
        // Check if premium and AI is enabled
        if !subscriptionManager.isPremium {
            print("⚠️ Premium subscription required for AI analysis")
            showPremiumUpgradePrompt = true
            return
        }
        
        if !UserDefaults.isAIDocumentClassificationEnabled {
            print("⚠️ AI document classification is disabled in settings")
            return
        }
        
        // Reset AI state to force a new analysis
        aiSuggestions = nil
        originalAISuggestions = nil
        isAnalyzingDocument = false
        
        // Signal intent to force reanalysis
        print("🔄 Manual AI analysis triggered - forcing document processor to reanalyze")
        
        // Force a new analysis
        ensureAIAnalysisWithMetadataContext(forceNewAnalysis: true)
    }
    
    // Method to refresh document details UI
    func refreshDocumentDetailsUI() {
        print("🔄 Refreshing document details UI")
        
        // Force UI update
        DispatchQueue.main.async {
            // Log the current state
            print("📄 Current document state for UI refresh:")
            print("  Title: \(self.documentTitle)")
            print("  Selected Folder ID: \(self.selectedFolderId?.uuidString ?? "nil")")
            
            // Check if the folder exists in the list
            if let folderId = self.selectedFolderId {
                if let folder = self.folders.first(where: { $0.id == folderId }) {
                    print("  Selected Folder: \(folder.name)")
                } else {
                    print("⚠️ Warning: Selected folder ID \(folderId) not found in folders list!")
                    
                    // Check if this is a pending folder and make sure it's in the list
                    if let pendingFolder = self.pendingFolderToCreate, pendingFolder.id == folderId {
                        print("  Adding pending folder to list: \(pendingFolder.name)")
                        self.folders.append(FolderItem(id: pendingFolder.id, name: pendingFolder.name))
                    }
                }
            }
            
            // Check tags
            print("  Selected Tag Count: \(self.selectedTagIds.count)")
            print("  Tags: \(self.getTagsTextFromSelectedIds())")
            
            // Force UI to refresh
            self.objectWillChange.send()
        }
    }
    
    // Enhance reset method to be more thorough
    private func resetStateForNewDocument() {
        print("🔄 Completely resetting state for new document")
        
        // Reset document metadata
        documentTitle = ""
        selectedFolderId = nil
        selectedTagIds.removeAll()
        extractedOCRText = nil
        
        // Reset AI suggestions
        aiSuggestions = nil
        originalAISuggestions = nil
        
        // Reset pending items
        pendingFolderToCreate = nil
        pendingTagsToCreate = []
        usesPendingCreation = false
        
        // Reset image data
        scannedImages = []
        pdfPageImages = []
        uploadedImage = nil
        
        // Reset processing flags
        isAnalyzingDocument = false
        
        // Force a UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
            print("🔄 State reset complete - UI notified")
        }
    }
    
    // Helper method to get pending folder name by ID
    func pendingFolderName(for folderId: UUID) -> String? {
        if let pending = pendingFolderToCreate, pending.id == folderId {
            return pending.name
        }
        return nil
    }
    
    // Add a cross-platform keyboard dismissal function
    private func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    // Replace the updateAdaptiveClassifier method
    private func updateAdaptiveClassifier() {
        // This is a deliberate learning opportunity - original AI suggestion vs final form
        guard let originalSuggestions = originalAISuggestions,
              let ocrText = extractedOCRText else {
            return
        }
        
        // Create current user selection 
        let userSelection = DocumentClassifierService.DocumentSuggestions(
            suggestedTitle: documentTitle,
            suggestedFolderName: getFolderName(for: selectedFolderId),
            suggestedTags: selectedTagIds.compactMap { tagId in 
                tags.first(where: { $0.id == tagId })?.name 
            },
            confidence: 1.0,
            tokenUsage: nil
        )
        
        // Use the adaptiveClassifier directly instead of DocumentLearningService
        // This avoids the dependency on DocumentLearningService that's causing issues
        adaptiveClassifier.recordUserCorrection(
            originalText: ocrText,
            aiSuggestion: originalSuggestions,
            finalUserChoice: userSelection
        )
        
        // Track if any significant changes were made
        let originalTitle = originalSuggestions.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let titleChanged = originalTitle.lowercased() != finalTitle.lowercased()
        
        // Track folder changes - normalize and handle nil values
        let originalFolder = originalSuggestions.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalFolder = getFolderName(for: selectedFolderId)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let folderChanged = originalFolder?.lowercased() != finalFolder?.lowercased()
        
        // Track tag changes - normalize for better comparison
        let originalTags = Set(originalSuggestions.suggestedTags.map { 
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() 
        })
        
        let finalTags = Set(selectedTagIds.compactMap { tagId -> String? in
            return tags.first(where: { $0.id == tagId })?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        
        let tagsChanged = originalTags != finalTags
        
        // Record user corrections if there were significant changes
        if titleChanged || folderChanged || tagsChanged {
            // Print a summary of changes for debugging
            if titleChanged {
                print("  - Title: '\(originalTitle)' → '\(finalTitle)'")
            }
            if folderChanged {
                print("  - Folder: '\(originalFolder ?? "none")' → '\(finalFolder ?? "none")'")
            }
            if tagsChanged {
                print("  - Tags changed from \(originalTags.count) to \(finalTags.count) tags")
            }
        } else {
            print("ℹ️ No significant changes detected between AI suggestions and final metadata")
        }
    }
    
    // Add helper method to get folder name from ID
    private func getFolderName(for folderId: UUID?) -> String? {
        guard let id = folderId else { return nil }
        
        // First check pending folder
        if let pending = pendingFolderToCreate, pending.id == id {
            return pending.name
        }
        
        // Then check existing folders
        return folders.first(where: { $0.id == id })?.name
    }
    
    // Add this method to record significant learning examples
    private func recordAsLearningExampleIfChanged() {
        // This is a deliberate learning opportunity - original AI suggestion vs final saved document
        guard let originalSuggestions = originalAISuggestions,
              let ocrText = extractedOCRText, !ocrText.isEmpty else {
            return
        }
        
        // Check if there were significant changes
        let titleChanged = documentTitle.lowercased() != originalSuggestions.suggestedTitle.lowercased()
        
        let originalFolder = originalSuggestions.suggestedFolderName?.lowercased() ?? ""
        let finalFolder = getFolderName(for: selectedFolderId)?.lowercased() ?? ""
        let folderChanged = originalFolder != finalFolder
        
        let originalTags = Set(originalSuggestions.suggestedTags.map { $0.lowercased() })
        let finalTags = Set(selectedTagIds.compactMap { tagId -> String? in
            return tags.first(where: { $0.id == tagId })?.name.lowercased()
        })
        let tagsChanged = originalTags != finalTags
        
        // Only record if significant changes were made
        if titleChanged || folderChanged || tagsChanged {
            let userSelection = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: documentTitle,
                suggestedFolderName: getFolderName(for: selectedFolderId),
                suggestedTags: selectedTagIds.compactMap { tagId in 
                    tags.first(where: { $0.id == tagId })?.name
                },
                confidence: 1.0,
                tokenUsage: nil
            )
            
            print("📋 Recording document as learning example")
            // Use the adaptiveClassifier directly
            adaptiveClassifier.recordUserCorrection(
                originalText: ocrText,
                aiSuggestion: originalSuggestions,
                finalUserChoice: userSelection
            )
            
            // Print a summary of changes for debugging
            print("🧠 Learning Example Summary:")
            if titleChanged {
                print("  - Title: '\(originalSuggestions.suggestedTitle)' → '\(documentTitle)'")
            }
            if folderChanged {
                print("  - Folder: '\(originalSuggestions.suggestedFolderName ?? "none")' → '\(getFolderName(for: selectedFolderId) ?? "none")'")
            }
            if tagsChanged {
                let addedTags = finalTags.subtracting(originalTags)
                let removedTags = originalTags.subtracting(finalTags)
                if !addedTags.isEmpty {
                    print("  - Added tags: \(Array(addedTags).joined(separator: ", "))")
                }
                if !removedTags.isEmpty {
                    print("  - Removed tags: \(Array(removedTags).joined(separator: ", "))")
                }
            }
        } else {
            print("ℹ️ No significant changes to record as learning example")
        }
    }
}

// Add extensions to access and modify entityId via id property
// This is compatible with NSManagedObject's Identifiable conformance
// because we're extending specific subclasses with a uniqueId property
extension Folder {
    var id: UUID? {
        get { return entityId }
        set { entityId = newValue }
    }
}

extension Tag {
    var id: UUID? {
        get { return entityId }
        set { entityId = newValue }
    }
}

extension Document {
    var id: UUID? {
        get { return entityId }
        set { entityId = newValue }
    }
}

// Test timestamp: Sun Mar 23 11:13:36 EDT 2025

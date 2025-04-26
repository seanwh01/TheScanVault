import SwiftUI
import CoreData
import Combine
import Foundation
import PDFKit

class DocumentViewModel: ObservableObject {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext
    
    @Published var document: Document?
    @Published var isLoading = true
    @Published var documentPages: [UIImage] = []
    @Published var previewImage: UIImage?
    @Published var documentPDFData: Data?
    @Published var hasChanges = false
    @Published var folderName: String?
    @Published var titleEdit: String = ""
    @Published var comments: String = ""
    @Published var availableTags: [TagItem] = []
    @Published var allFolders: [FolderItem] = []
    
    // Add document type enum and property
    enum DocumentType {
        case nativePDF
        case scannedPDF
        case image
        case unknown
    }
    
    @Published var documentType: DocumentType = .unknown
    
    private var pdfDocument: PDFDocument?
    @Published var pageCount: Int = 0
    
    // Add this property to track current page
    private var currentPageIndex: Int?
    
    // Add this property to track current view
    private var currentView: ViewState = .document
    private var pdfDocumentReleased = false
    
    // Add a cancellables set to store subscriptions
    var cancellables = Set<AnyCancellable>()
    
    // Define view states
    enum ViewState {
        case document
        case edit
        case share
    }
    
    init(document: Document, persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        self.viewContext = persistenceController.container.viewContext
        self.document = document
        self.hasChanges = false
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async {
            // Load the document content immediately
            self.loadDocumentContent()
            
            // Set initial values for editing
            self.titleEdit = document.title ?? ""
            self.comments = document.comments ?? ""
            
            // Load metadata
            self.loadMetadata()
        }
        
        // Set up notifications
        setupNotifications()
        
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // Add initializer that takes a document ID
    init(documentId: UUID, persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        self.viewContext = persistenceController.container.viewContext
        self.hasChanges = false
        
        // Fetch document from Core Data
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let fetchedDocument = results.first {
                self.document = fetchedDocument
                
                // Ensure we're on the main thread for UI updates
                DispatchQueue.main.async {
                    // Load the document content immediately
                    self.loadDocumentContent()
                    
                    // Set initial values for editing
                    self.titleEdit = fetchedDocument.title ?? ""
                    self.comments = fetchedDocument.comments ?? ""
                    
                    // Load metadata
                    self.loadMetadata()
                }
            } else {
                print("⚠️ Could not find document with ID: \(documentId)")
                // Set isLoading to false since we don't have a document
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ Error fetching document: \(error)")
            // Set isLoading to false on error
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        // Set up notifications
        setupNotifications()
        
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    private func loadMetadata() {
        // Load folder name if available
        if let folderId = document?.folderId {
            let folderRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            folderRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
            
            do {
                if let folder = try viewContext.fetch(folderRequest).first {
                    self.folderName = folder.name
                }
            } catch {
                print("Error loading folder: \(error)")
            }
        }
        
        // Load available tags
        fetchAvailableTags()
        
        // Load all folders
        fetchAllFolders()
    }
    
    private func loadDocumentContent() {
        guard let document = document, let documentData = document.documentData else {
            print("⚠️ No document or document data available")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        // Process document data on background thread with high priority
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // Check if it's a PDF
            if let pdfDocument = PDFDocument(data: documentData) {
                print("📄 Initializing PDF document with \(pdfDocument.pageCount) pages")
                
                // Validate PDF document
                guard pdfDocument.pageCount > 0 else {
                    print("⚠️ PDF document has no pages")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.documentType = .unknown
                    }
                    return
                }
                
                // Store PDF data for lazy loading
                let pdfData = documentData
                let pageCount = pdfDocument.pageCount
                
                // Check if this is a native PDF with text content
                var isNativePDF = false
                if let firstPage = pdfDocument.page(at: 0),
                   let pageText = firstPage.string,
                   !pageText.isEmpty {
                    isNativePDF = true
                    print("📄 Detected native PDF with text content")
                }
                
                // Pre-render first page with high quality BEFORE updating UI state
                // This ensures the first page is ready immediately
                var firstPageImage: UIImage? = nil
                if let firstPage = pdfDocument.page(at: 0) {
                    print("🔄 Pre-rendering first page at high quality")
                    firstPageImage = self.renderPDFPage(firstPage, scale: 2.0) // Use higher quality for first page
                }
                
                // Initialize document pages with placeholder images
                var initialPages = Array(repeating: UIImage(), count: pageCount)
                
                // If we successfully rendered the first page, insert it at index 0
                if let firstImage = firstPageImage {
                    if pageCount > 0 {
                        initialPages[0] = firstImage
                    }
                }
                
                // Update UI on main thread with initial state
                DispatchQueue.main.async {
                    self.documentPDFData = pdfData
                    self.pdfDocument = pdfDocument
                    self.pageCount = pageCount
                    self.documentType = isNativePDF ? .nativePDF : .scannedPDF
                    
                    // Set all pages at once, with first page already rendered
                    self.documentPages = initialPages
                    self.previewImage = firstPageImage ?? UIImage()
                    self.isLoading = false
                    
                    print("📊 Document identified as: \(isNativePDF ? "Native PDF" : "Scanned PDF")")
                    
                    // Make sure we update the current page index
                    self.currentPageIndex = 0
                    
                    // Notify that the document is ready for display
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DocumentReadyForDisplay"),
                        object: nil,
                        userInfo: ["documentId": document.id ?? UUID()]
                    )
                }
                
                // After UI is updated, pre-load next few pages for better scrolling experience
                DispatchQueue.global(qos: .userInitiated).async {
                    // Start from page 1 (second page) since page 0 is already loaded
                    let initialPageCount = min(4, pageCount)
                    for i in 1..<initialPageCount {
                        if let page = pdfDocument.page(at: i) {
                            if let pageImage = self.renderPDFPage(page, scale: 1.8) {
                                DispatchQueue.main.async {
                                    if self.documentPages.count > i {
                                        self.documentPages[i] = pageImage
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // It's an image
                if let image = UIImage(data: documentData) {
                    print("🖼️ Successfully loaded image document")
                    DispatchQueue.main.async {
                        self.previewImage = image
                        self.documentPages = [image]
                        self.pageCount = 1
                        self.documentType = .image
                        self.isLoading = false
                    }
                } else {
                    print("⚠️ Failed to create image from document data")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.documentType = .unknown
                    }
                }
            }
        }
    }
    
    // Improve memory management with autorelease pools and better thread safety
    private func renderPDFPage(_ page: PDFPage, scale: CGFloat = 1.0) -> UIImage? {
        // Use autoreleasepool to ensure memory is freed immediately
        return autoreleasepool { () -> UIImage? in
            let pageRect = page.bounds(for: .mediaBox)
            
            // Reduce the scale for initial page loads to prevent memory issues
            // High res is only needed for zooming
            let renderScale: CGFloat = min(2.0, scale) // Limit scale to prevent memory issues
            
            let width = pageRect.width * renderScale
            let height = pageRect.height * renderScale
            
            // Cap dimensions to reasonable values to prevent memory issues
            let maxDimension: CGFloat = 4000 // Prevent excessively large images
            let scaledWidth = min(width, maxDimension)
            let scaledHeight = min(height, maxDimension)
            let finalScale = min(scaledWidth / pageRect.width, scaledHeight / pageRect.height)
            
            UIGraphicsBeginImageContextWithOptions(
                CGSize(width: pageRect.width * finalScale, height: pageRect.height * finalScale),
                true, // Use opaque context for better performance
                0
            )
            
            guard let context = UIGraphicsGetCurrentContext() else {
                return nil
            }
            
            // White background
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: pageRect.width * finalScale, height: pageRect.height * finalScale))
            
            // Save context state
            context.saveGState()
            
            // Flip the context so that the PDF page is rendered right side up
            context.translateBy(x: 0, y: pageRect.height * finalScale)
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Scale the context to draw the PDF page at the higher resolution
            context.scaleBy(x: finalScale, y: finalScale)
            
            // Draw the PDF page into the context - try safer approaches
            if let cgPdfPage = page.pageRef {
                // Use the Core Graphics API if available
                context.drawPDFPage(cgPdfPage)
            } else {
                // Fall back to PDFKit's drawing capability
                page.draw(with: .mediaBox, to: context)
            }
            
            // Restore context state
            context.restoreGState()
            
            // Get the image and cleanup properly
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return image
        }
    }

    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning received - purging cached pages")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Keep only the current page in memory
            if let currentIndex = self.currentPageIndex, currentIndex < self.documentPages.count {
                let currentPage = self.documentPages[currentIndex]
                // Replace all pages except current with empty images
                self.documentPages = self.documentPages.enumerated().map { index, _ in
                    return index == currentIndex ? currentPage : UIImage()
                }
            }
            
            // Release PDF document data if we're not viewing it
            if self.currentView != .document {
                self.pdfDocument = nil
                // Keep a record that we've released the document
                self.pdfDocumentReleased = true
            }
        }
    }

    // MARK: - Document Metadata Methods
    
    // Add required methods for handling document operations
    func deleteDocument(completion: @escaping (Bool) -> Void) {
        guard let document = document else {
            completion(false)
            return
        }
        
        // Use VaultViewModel to handle the deletion
        let vaultViewModel = VaultViewModel(persistenceController: self.persistenceController)
        vaultViewModel.deleteDocument(document.id!)
        completion(true)
    }
    
    // MARK: - Document Title and Comments
    
    func updateTitle(_ newTitle: String) {
        if document?.title != newTitle {
            document?.title = newTitle
            hasChanges = true
        }
    }
    
    func updateDocument(title: String, folderId: UUID?, comments: String, tagIds: [UUID]) {
        // Mark that changes are being made
        hasChanges = true
        
        // Update document properties
        document?.title = title
        document?.folderId = folderId
        document?.comments = comments
        
        // Update tags
        if let existingTags = document?.tags as? Set<Tag>, !existingTags.isEmpty {
            document?.removeFromTags(existingTags as NSSet)
        }
        
        // Add selected tags
        for tagId in tagIds {
            if let tag = fetchTag(withId: tagId) {
                document?.addToTags(tag)
            }
        }
        
        do {
            try viewContext.save()
            
            // Add notification after successful save
            NotificationCenter.default.post(
                name: NSNotification.Name("DocumentUpdated"),
                object: nil,
                userInfo: ["documentId": document?.id ?? UUID()]
            )
            
            // Reset the hasChanges flag after successful save
            hasChanges = false
            
            print("✅ Document updated and notification sent")
        } catch {
            print("Error updating document: \(error)")
        }
    }
    
    func saveChanges() {
        do {
            try viewContext.save()
            hasChanges = false
        } catch {
            print("Error saving changes: \(error)")
        }
    }
    
    // MARK: - Tag Management
    
    private func fetchTag(withId id: UUID) -> Tag? {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching tag: \(error)")
            return nil
        }
    }
    
    // MARK: - Folder Management
    
    func removeFolder() {
        document?.folderId = nil
        hasChanges = true
    }
    
    func setFolder(_ folder: FolderItem) {
        document?.folderId = folder.id
        folderName = folder.name
        hasChanges = true
    }
    
    func createAndSetFolder(name: String) {
        // Check for reserved names
        let reservedNames = ["No Folder", "No Folder Assigned"]
        if reservedNames.contains(name) {
            print("⚠️ Attempted to create folder with reserved name: \(name)")
            return
        }
        
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = name
        
        do {
            try viewContext.save()
            document?.folderId = newFolder.id
            folderName = name
            hasChanges = true
        } catch {
            print("Error creating folder: \(error)")
        }
    }
    
    // MARK: - Tag Operations
    
    func removeTag(_ tag: Tag) {
        document?.removeFromTags(tag)
        hasChanges = true
    }
    
    func addTag(_ tag: TagItem) {
        if let existingTag = fetchTag(withId: tag.id) {
            document?.addToTags(existingTag)
            hasChanges = true
        }
    }
    
    func createAndAddTag(name: String) {
        let newTag = Tag(context: viewContext)
        newTag.id = UUID()
        newTag.name = name
        
        do {
            try viewContext.save()
            document?.addToTags(newTag)
            hasChanges = true
        } catch {
            print("Error creating tag: \(error)")
        }
    }
    
    // MARK: - Save Operations
    
    func saveTitle(forceSave: Bool = false) {
        if let document = document {
            document.title = titleEdit
            document.updatedAt = Date() // Update the modification date
            
            do {
                try viewContext.save()
                
                print("✅ Document title saved: \(titleEdit)")
            } catch {
                print("❌ Error saving document title: \(error)")
            }
        }
    }
    
    func saveComments(forceSave: Bool = false) {
        if let document = document {
            document.comments = comments
            document.updatedAt = Date() // Update the modification date
            
            do {
                try viewContext.save()
                
                print("✅ Document comments saved")
            } catch {
                print("❌ Error saving document comments: \(error)")
            }
        }
    }
    
    // MARK: - Data Loading
    
    func fetchAvailableTags() {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        // Don't include tags already on this document
        if let docTags = document?.tags as? Set<Tag>, !docTags.isEmpty {
            let docTagIds = docTags.compactMap { $0.id }
            fetchRequest.predicate = NSPredicate(format: "NOT (id IN %@)", docTagIds)
        }
        
        do {
            let tags = try viewContext.fetch(fetchRequest)
            let tagItems = tags.compactMap { (tag: Tag) -> TagItem? in
                guard let id = tag.id, let name = tag.name else { return nil }
                return TagItem(id: id, name: name)
            }
            
            // Ensure UI update on main thread
            DispatchQueue.main.async {
                self.availableTags = tagItems
            }
        } catch {
            print("Error fetching available tags: \(error)")
        }
    }
    
    func fetchAllFolders() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let folders = try viewContext.fetch(fetchRequest)
            let folderItems = folders.compactMap { (folder: Folder) -> FolderItem? in
                guard let id = folder.id, let name = folder.name else { return nil }
                return FolderItem(id: id, name: name)
            }
            
            var currentFolderName: String? = nil
            if let folderId = document?.folderId {
                currentFolderName = folderItems.first(where: { $0.id == folderId })?.name
            }
            
            DispatchQueue.main.async {
                self.allFolders = folderItems
                self.folderName = currentFolderName
            }
        } catch {
            print("Error fetching folders: \(error)")
        }
    }
    
    func saveFolder(sendNotification: Bool = true) {
        if let document = document {
            // Mark as updated
            document.updatedAt = Date()
            
            // Save the changes
            do {
                try viewContext.save()
                
                // Only send notification if requested
                if sendNotification {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DocumentFolderChanged"),
                        object: nil,
                        userInfo: ["documentId": document.id ?? UUID()]
                    )
                }
                
                // Always mark as changed so it gets caught by onDisappear
                hasChanges = true
                
                print("✅ Folder changes saved")
            } catch {
                print("Error saving folder changes: \(error)")
            }
        }
    }
    
    // MARK: - Folder Creation
    
    func createTempFolder(name: String) -> FolderItem? {
        // Check for reserved names
        let reservedNames = ["No Folder", "No Folder Assigned"]
        if reservedNames.contains(name) {
            print("⚠️ Attempted to create folder with reserved name: \(name)")
            return nil
        }
        
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = name
        
        do {
            try viewContext.save()
            
            // Add the new folder to allFolders list
            let newItem = FolderItem(id: newFolder.id!, name: name)
            allFolders.append(newItem)
            
            return newItem
        } catch {
            print("Error creating temp folder: \(error)")
            return nil
        }
    }
    
    // Method to set a folder by ID and name
    func setFolder(id: UUID?, name: String?) {
        document?.folderId = id
        folderName = name
        hasChanges = true
    }
    
    // Method to refresh the folder name display from the document
    func refreshFolderName() {
        if let folderId = document?.folderId {
            folderName = allFolders.first(where: { $0.id == folderId })?.name
        } else {
            folderName = nil
        }
    }
    
    // MARK: - Document Saving
    
    func saveSilently() {
        // Save changes to Core Data without triggering navigation
        if let document = document {
            document.updatedAt = Date() // Ensure updated timestamp
            
            do {
                // Save changes to Core Data
                try viewContext.save()
                
                print("✅ Document saved silently with title: \(document.title ?? "unknown")")
                
                // Post notification with both silentUpdate and forceRefresh flags
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshVaultDocuments"),
                    object: nil
                )
                
                // Also post a document-specific notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentUpdated"),
                    object: nil,
                    userInfo: [
                        "documentId": document.id!,
                        "silentUpdate": true,
                        "forceRefresh": true,
                        "updatedTitle": document.title ?? "",
                        "timestamp": Date().timeIntervalSince1970
                    ]
                )
                
                hasChanges = true // Mark as changed for tracking purposes
                
            } catch {
                print("❌ Error saving document changes: \(error)")
            }
        }
    }
    
    // Refresh from Core Data to ensure we have the latest data
    func refreshFromCoreData() {
        if let documentId = document?.id {
            let request = NSFetchRequest<Document>(entityName: "Document")
            request.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
            
            do {
                let results = try viewContext.fetch(request)
                if let refreshedDocument = results.first {
                    // Update all properties on main thread
                    DispatchQueue.main.async {
                        // Update the local document instance
                        self.document = refreshedDocument
                        
                        // Update all the UI properties
                        self.titleEdit = refreshedDocument.title ?? ""
                        self.comments = refreshedDocument.comments ?? ""
                        
                        // Use the correct approach to get folder name based on folderId
                        if let folderId = refreshedDocument.folderId {
                            self.folderName = self.allFolders.first(where: { $0.id == folderId })?.name
                        } else {
                            self.folderName = nil
                        }
                    }
                    
                    print("✅ Document refreshed from Core Data")
                }
            } catch {
                print("❌ Error refreshing document: \(error)")
            }
        }
    }
    
    func saveLocally() {
        // Save changes to Core Data WITHOUT sending notifications
        if let document = document {
            // Set the document properties
            document.title = titleEdit
            document.comments = comments
            document.updatedAt = Date()
            
            do {
                // Save changes to Core Data
                try viewContext.save()
                print("✅ Document saved locally with title: \(document.title ?? "unknown")")
                
                // Fetch the latest version of the document to ensure UI is up-to-date
                refreshFromCoreData()
                hasChanges = true
            } catch {
                print("❌ Error saving document changes: \(error)")
            }
        }
    }
    
    func saveLocallyWithoutNotifications() {
        // Save changes to Core Data WITHOUT sending ANY notifications
        if let document = document {
            // Set the document properties
            document.title = titleEdit
            document.comments = comments
            document.updatedAt = Date()
            
            do {
                // Save changes to Core Data
                try viewContext.save()
                print("✅ Document saved locally with title: \(document.title ?? "unknown")")
                
                // Fetch the latest version of the document to ensure UI is up-to-date
                refreshFromCoreData()
                hasChanges = true 
            } catch {
                print("❌ Error saving document changes: \(error)")
            }
        }
    }
    
    func saveTags(sendNotification: Bool = true) {
        if let document = document {
            // Mark as updated
            document.updatedAt = Date()
            
            // Save the changes
            do {
                try viewContext.save()
                
                // Only send notification if requested
                if sendNotification {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DocumentTagsChanged"),
                        object: nil,
                        userInfo: ["documentId": document.id ?? UUID()]
                    )
                }
                
                // Always mark as changed so it gets caught by onDisappear
                hasChanges = true
                
                print("✅ Tags saved")
            } catch {
                print("Error saving tags: \(error)")
            }
        }
    }
    
    // Method to move OCR text from comments to text field
    func moveOCRTextFromCommentsToTextField() {
        guard let document = document,
              let documentText = document.text,
              let comments = document.comments else { return }
        
        // If comments starts with or is exactly the OCR text
        if comments == documentText || comments.hasPrefix(documentText) {
            // Save OCR in text field, remove from comments
            document.text = documentText
            
            // If comments just contains the OCR text, clear it
            if comments == documentText {
                document.comments = nil
            } else {
                // If comments contain OCR plus user comments, remove just the OCR part
                let ocr = documentText
                let cleanedComments = comments.replacingOccurrences(of: ocr, with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                document.comments = cleanedComments
            }
            
            // Save changes without sending notifications
            saveLocallyWithoutNotifications()
            print("Moved OCR text from comments to text field")
        }
    }
    
    // Method to reload all data - used when metadata changes
    func reloadData() {
        // Reload metadata
        loadMetadata()
        
        // Refresh document from database to ensure we have latest changes
        if let docId = document?.id {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", docId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                if let refreshedDoc = try viewContext.fetch(fetchRequest).first {
                    document = refreshedDoc
                }
            } catch {
                print("Error refreshing document: \(error)")
            }
        }
    }
    
    // Public accessor for PDF document
    var getPDFDocument: PDFDocument? {
        return pdfDocument
    }
    
    // Modify loadPage to be more memory efficient for large documents
    func loadPage(at index: Int) {
        guard let pdfDocument = pdfDocument, index >= 0, index < pageCount else {
            print("⚠️ Invalid page index or no PDF document available")
            return
        }
        
        // Always use good quality for visible pages
        let defaultScale: CGFloat = 1.5
        
        // Check if the page is already loaded with full quality
        if index < documentPages.count, documentPages[index].size.width > 100 {
            // Page is already loaded with reasonable quality, skip rendering again
            print("📄 Page \(index + 1) already loaded with good quality")
            return
        }
        
        // Use high priority for current page, medium for others
        let qos: DispatchQoS.QoSClass = (index == currentPageIndex) ? .userInitiated : .userInitiated
        
        // Ensure UI updates happen on main thread
        DispatchQueue.global(qos: qos).async { [weak self] in
            guard let self = self else { return }
            
            // Use autoreleasepool to manage memory better
            autoreleasepool {
                // Get the page from the PDF document
                if let page = pdfDocument.page(at: index) {
                    print("📄 Loading page \(index + 1) of \(self.pageCount)")
                    
                    // Always use good quality rendering
                    if let pageImage = self.renderPDFPage(page, scale: defaultScale) {
                        print("✅ Successfully rendered page \(index + 1) at \(pageImage.size.width) x \(pageImage.size.height)")
                        
                        // Update UI on main thread
                        DispatchQueue.main.async {
                            // Ensure array is large enough
                            while self.documentPages.count <= index {
                                self.documentPages.append(UIImage())
                            }
                            
                            // Update the image at the specific index
                            self.documentPages[index] = pageImage
                        }
                    } else {
                        print("❌ Failed to render page \(index + 1)")
                    }
                } else {
                    print("❌ Failed to get page \(index + 1) from PDF document")
                }
            }
        }
    }
    
    // Update prepareForDisplaying to be more aggressive in loading pages
    func prepareForDisplaying(page: Int) {
        currentPageIndex = page
        
        // For small to medium documents, preload more aggressively
        // For very large documents, be more conservative
        let isLargeDocument = pageCount > 20
        let pageRange: Int = isLargeDocument ? 1 : 3
        
        // Define the range of pages to load (current page and adjacent ones)
        let pagesToKeep = Set((page - pageRange...page + pageRange)
            .filter { $0 >= 0 && $0 < pageCount })
        
        // Load current page immediately with high priority
        loadPage(at: page)
        
        // Load adjacent pages quickly with slight offset to avoid blocking
        for adjacentPage in pagesToKeep where adjacentPage != page {
            let delay = Double(abs(adjacentPage - page)) * 0.05 // Stagger loads slightly
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.loadPage(at: adjacentPage)
            }
        }
        
        // For large documents, release memory for far away pages after a delay
        if isLargeDocument {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                // Keep more loaded pages in the viewport to avoid thumbnails
                let extendedRange = Set((page - 5...page + 5)
                    .filter { $0 >= 0 && $0 < self.pageCount })
                
                // Release memory only for very distant pages
                for i in 0..<self.pageCount where !extendedRange.contains(i) {
                    if i < self.documentPages.count && self.documentPages[i].size.width > 1 {
                        // Replace with empty placeholder to release memory
                        DispatchQueue.main.async {
                            if i < self.documentPages.count {
                                self.documentPages[i] = UIImage()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Set current page and load adjacent pages
    func setCurrentPage(_ index: Int) {
        // Update the current page index
        currentPageIndex = index
        
        // Load the page and adjacent pages for smoother navigation
        prepareForDisplaying(page: index)
    }
    
    // Setup notification observers
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DocumentReadyForDisplay"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let documentId = notification.userInfo?["documentId"] as? UUID,
                  documentId == self.document?.id else {
                return
            }
            
            // Force the current page to refresh
            if let currentPage = self.currentPageIndex {
                self.prepareForDisplaying(page: currentPage)
            } else {
                self.prepareForDisplaying(page: 0)
            }
        }
    }
}

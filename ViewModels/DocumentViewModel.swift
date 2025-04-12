import SwiftUI
import CoreData
import Combine
import Foundation
import PDFKit

class DocumentViewModel: ObservableObject {
    private let persistenceController = PersistenceController.shared
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
    
    init(document: Document) {
        self.viewContext = PersistenceController.shared.container.viewContext
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
        
        // Register for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // Add initializer that takes a document ID
    init(documentId: UUID) {
        self.viewContext = PersistenceController.shared.container.viewContext
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
        loadAvailableTags()
        
        // Load all folders
        loadAllFolders()
    }
    
    private func loadAvailableTags() {
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
            
            // Ensure UI update happens on main thread
            DispatchQueue.main.async {
                self.availableTags = tagItems
            }
        } catch {
            print("Error loading available tags: \(error)")
        }
    }
    
    private func loadAllFolders() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let folders = try viewContext.fetch(fetchRequest)
            let folderItems = folders.compactMap { (folder: Folder) -> FolderItem? in
                guard let id = folder.id, let name = folder.name else { return nil }
                return FolderItem(id: id, name: name)
            }
            
            // Get folder name on main thread
            var currentFolderName: String? = nil
            if let folderId = document?.folderId {
                currentFolderName = folderItems.first(where: { $0.id == folderId })?.name
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.allFolders = folderItems
                self.folderName = currentFolderName
            }
        } catch {
            print("Error loading folders: \(error)")
        }
    }
    
    private func loadDocumentContent() {
        guard let document = document, let documentData = document.documentData else {
            print("⚠️ No document or document data available")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        // Process document data on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check if it's a PDF
            if let pdfDocument = PDFDocument(data: documentData) {
                print("📄 Initializing PDF document with \(pdfDocument.pageCount) pages")
                
                // Validate PDF document
                guard pdfDocument.pageCount > 0 else {
                    print("⚠️ PDF document has no pages")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                // Store PDF data for lazy loading
                let pdfData = documentData
                let pageCount = pdfDocument.pageCount
                
                // Update UI on main thread with initial state
                DispatchQueue.main.async {
                    self.documentPDFData = pdfData
                    self.pdfDocument = pdfDocument
                    self.pageCount = pageCount
                    self.isLoading = false
                }
                
                // Pre-load first page for better UX
                if let firstPage = pdfDocument.page(at: 0) {
                    print("🔄 Attempting to render first page")
                    if let firstPageImage = self.renderPDFPage(firstPage, scale: 1.0) {
                        print("✅ Successfully rendered first page: \(firstPageImage.size.width) x \(firstPageImage.size.height)")
                        
                        // Update UI with first page
                        DispatchQueue.main.async {
                            self.previewImage = firstPageImage
                            self.documentPages = [firstPageImage]
                        }
                        
                        // Schedule loading of additional pages after UI appears
                        DispatchQueue.global(qos: .userInitiated).async {
                            // Pre-load the rest of the pages in the background
                            for i in 1..<pdfDocument.pageCount {
                                self.loadPage(at: i)
                            }
                        }
                    } else {
                        print("⚠️ Failed to render first page of PDF")
                        // Try again with higher quality
                        if let firstPageImage = self.renderPDFPage(firstPage, scale: 1.5) {
                            print("✅ Successfully rendered first page with higher quality")
                            DispatchQueue.main.async {
                                self.previewImage = firstPageImage
                                self.documentPages = [firstPageImage]
                            }
                        } else {
                            print("❌ Failed to render first page even with higher quality")
                        }
                    }
                } else {
                    print("❌ Failed to get first page from PDF document")
                }
            } else {
                // It's an image
                if let image = UIImage(data: documentData) {
                    print("🖼️ Successfully loaded image document")
                    DispatchQueue.main.async {
                        self.previewImage = image
                        self.documentPages = [image]
                        self.pageCount = 1
                        self.isLoading = false
                    }
                } else {
                    print("⚠️ Failed to create image from document data")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func renderPDFPage(_ page: PDFPage, scale: CGFloat = 1.0) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        
        // Reduce the size to save memory
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        // Create renderer with proper format
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        
        let image = renderer.image { ctx in
            // Fill with white background
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: scaledSize))
            
            // Set up proper transformation for PDF rendering
            ctx.cgContext.translateBy(x: 0, y: scaledSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            
            // Draw the PDF page
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        
        // Validate the image is properly rendered by checking dimensions
        if image.size.width < 10 || image.size.height < 10 {
            print("⚠️ Warning: Rendered PDF page has invalid dimensions: \(image.size)")
            return nil
        }
        
        return image
    }
    
    // Add required methods for handling document operations
    func deleteDocument(completion: @escaping (Bool) -> Void) {
        guard let document = document else {
            completion(false)
            return
        }
        
        // Use VaultViewModel to handle the deletion
        let vaultViewModel = VaultViewModel()
        vaultViewModel.deleteDocument(document.id!)
        completion(true)
    }
    
    // Add other necessary methods
    
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
    
    // Add folder-related methods
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
    
    // Add tag-related methods
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
    
    // Add save methods
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
    
    // Add these methods to DocumentViewModel to fetch tags and folders
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
    
    // Add these methods to DocumentViewModel
    
    // Method to create a folder without setting it on the document
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
    
    // Add this method to DocumentViewModel.swift
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
    
    // Add this method to ensure the view model refreshes from Core Data
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
    
    // Add this method to DocumentViewModel.swift
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
    
    // Add this method to DocumentViewModel
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
    
    // Add this method to DocumentViewModel class
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
    
    // Add to DocumentViewModel
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
            
            // Fix: Call saveLocallyWithoutNotifications() instead which doesn't take parameters
            saveLocallyWithoutNotifications()
            print("Moved OCR text from comments to text field")
        }
    }
    
    // Add this method to lazy load specific PDF pages when needed
    func loadPage(at index: Int) {
        guard let pdfDoc = pdfDocument else {
            print("⚠️ No PDF document available for loading page \(index)")
            return
        }
        
        guard index >= 0 && index < pageCount else {
            print("⚠️ Invalid page index: \(index) for document with \(pageCount) pages")
            return
        }
        
        // Check if we need to load the page without using main.sync
        let currentPagesCount = documentPages.count
        let shouldLoadPage = index >= currentPagesCount || 
            (index < currentPagesCount && 
             (documentPages[index].size.width < 10 || 
              documentPages[index].size.height < 10))
        
        if shouldLoadPage {
            print("🔄 Loading page \(index+1) of \(pageCount)")
            
            // Force loading this page as it's either missing or has invalid content
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                autoreleasepool {
                    guard let page = pdfDoc.page(at: index) else {
                        print("❌ Failed to get page \(index+1) from PDF document")
                        return
                    }
                    
                    // First try with normal scale
                    if var pageImage = self.renderPDFPage(page, scale: 1.0) {
                        print("✅ Successfully rendered page \(index+1): \(pageImage.size.width) x \(pageImage.size.height)")
                        
                        // If dimensions are suspicious, try again with higher quality
                        if pageImage.size.width < 50 || pageImage.size.height < 50 {
                            print("⚠️ Low quality detected for page \(index+1), trying higher quality render")
                            if let betterImage = self.renderPDFPage(page, scale: 1.2) {
                                pageImage = betterImage
                                print("✅ Re-rendered with better quality: \(pageImage.size.width) x \(pageImage.size.height)")
                            }
                        }
                        
                        DispatchQueue.main.async {
                            // Ensure array is properly sized
                            while self.documentPages.count <= index {
                                self.documentPages.append(UIImage())
                            }
                            // Replace the placeholder with actual content
                            self.documentPages[index] = pageImage
                        }
                    } else {
                        print("❌ Failed to render page \(index+1), trying with higher quality")
                        // Try again with higher quality
                        if let pageImage = self.renderPDFPage(page, scale: 1.5) {
                            print("✅ Successfully rendered page \(index+1) with higher quality: \(pageImage.size.width) x \(pageImage.size.height)")
                            
                            DispatchQueue.main.async {
                                // Ensure array is properly sized
                                while self.documentPages.count <= index {
                                    self.documentPages.append(UIImage())
                                }
                                // Replace the placeholder with actual content
                                self.documentPages[index] = pageImage
                            }
                        } else {
                            print("❌ Failed to render page \(index+1) even with higher quality")
                        }
                    }
                }
            }
        }
    }
    
    // Load the current page and adjacent pages
    func loadVisiblePages(currentIndex: Int) {
        // Load current page and one page before/after
        let pagesToLoad = [currentIndex - 1, currentIndex, currentIndex + 1]
        
        for index in pagesToLoad where index >= 0 && index < pageCount {
            loadPage(at: index)
        }
        
        // Purge pages that are far away to save memory
        purgeDistantPages(currentIndex: currentIndex)
    }
    
    // Remove pages from memory that are far from the current view
    private func purgeDistantPages(currentIndex: Int) {
        // Keep only pages within a certain range of the current index
        let keepRange = max(0, currentIndex - 2)...min(pageCount - 1, currentIndex + 2)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for i in 0..<self.documentPages.count {
                if !keepRange.contains(i) && i < self.documentPages.count {
                    // Replace with a low-res version or nil to save memory
                    if i == 0 && self.previewImage != nil {
                        self.documentPages[i] = self.previewImage! // Keep first page as preview
                    } else if self.documentPages[i] != self.previewImage {
                        self.documentPages[i] = UIImage() // Use empty image as placeholder
                    }
                }
            }
        }
    }
    
    // Add memory warning handler
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
    
    // Update the set current page method
    func setCurrentPage(_ index: Int) {
        // Must update @Published properties on main thread
        DispatchQueue.main.async {
            self.currentPageIndex = index
        }
        loadVisiblePages(currentIndex: index)
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
} 

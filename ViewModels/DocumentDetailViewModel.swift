import SwiftUI
import CoreData
import Combine
import PDFKit

// Specify the model types by adding unique namespaces or type aliases
// If these types are defined elsewhere, use those instead
typealias VMTagItem = TagItem
typealias VMFolderItem = FolderItem

class DocumentDetailViewModel: ObservableObject {
    @Published var document: Document?
    @Published var isLoading = true
    @Published var error: Error?
    @Published var previewImage: UIImage?
    @Published var documentPDFData: Data?
    @Published var documentPages: [UIImage] = []
    
    @Published var titleEdit = ""
    @Published var comments = ""
    @Published var isEditingComments = false
    
    // Use the prefixed type aliases to avoid ambiguity
    @Published var allTags: [VMTagItem] = []
    @Published var availableTags: [VMTagItem] = []
    @Published var allFolders: [VMFolderItem] = []
    @Published var folderName: String?
    
    let persistenceController: PersistenceController
    
    private var cancellables = Set<AnyCancellable>()
    
    init(document: Document? = nil, persistenceController: PersistenceController) {
        self.document = document
        self.persistenceController = persistenceController
        
        // Initialize published properties based on the document
        if let doc = document {
            self.titleEdit = doc.title ?? ""
            self.comments = doc.comments ?? ""
            
            // Extract folder name if available
            if let folderId = doc.folderId {
                let folderItem = fetchFolder(with: folderId)
                self.folderName = folderItem?.name
            } else {
                self.folderName = nil
            }
            
            // Load PDF data and extract all pages
            if let documentData = doc.documentData {
                self.documentPDFData = documentData
                
                if let pdfDocument = PDFDocument(data: documentData) {
                    // Extract all pages from the PDF
                    var pages: [UIImage] = []
                    
                    // Always process at least one page
                    let pageCount = max(1, pdfDocument.pageCount)
                    
                    for i in 0..<pageCount {
                        if let page = pdfDocument.page(at: i),
                           let pageImage = self.renderPDFPageToImage(page) {
                            pages.append(pageImage)
                        }
                    }
                    
                    // Set both documentPages and previewImage
                    self.documentPages = pages
                    self.previewImage = pages.first
                } else if let image = UIImage(data: documentData) {
                    // Handle case for images directly
                    self.previewImage = image
                    self.documentPages = [image]
                }
            }
            
            // Load available tags
            loadAvailableTags()
            
            // Load all folders
            loadAllFolders()
        }
    }
    
    func updateAvailableTags() {
        guard let document = document, let documentTags = document.tags as? Set<Tag> else {
            availableTags = allTags
            return
        }
        
        let documentTagIds = Set(documentTags.compactMap { $0.id })
        availableTags = allTags.filter { !documentTagIds.contains($0.id) }
    }
    
    private func fetchFolder(with id: UUID) -> VMFolderItem? {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try persistenceController.viewContext.fetch(fetchRequest)
            if let folder = results.first, let folderName = folder.name {
                return VMFolderItem(id: id, name: folderName)
            }
        } catch {
            print("Error fetching folder: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func loadAvailableTags() {
        fetchAllTags()
        updateAvailableTags()
    }
    
    private func loadAllFolders() {
        fetchAllFolders()
    }
    
    func loadDocument(id: UUID) {
        isLoading = true
        
        // Fetch the document
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try persistenceController.viewContext.fetch(fetchRequest)
            if let fetchedDocument = results.first {
                self.document = fetchedDocument
                self.titleEdit = fetchedDocument.title ?? ""
                self.comments = fetchedDocument.comments ?? ""
                
                // Extract folder name if available
                if let folderId = fetchedDocument.folderId {
                    let folderItem = fetchFolder(with: folderId)
                    self.folderName = folderItem?.name
                } else {
                    self.folderName = nil
                }
                
                // Load PDF data and extract all pages
                if let documentData = fetchedDocument.documentData {
                    self.documentPDFData = documentData
                    
                    if let pdfDocument = PDFDocument(data: documentData) {
                        // Extract all pages from the PDF
                        var pages: [UIImage] = []
                        
                        // Always process at least one page
                        let pageCount = max(1, pdfDocument.pageCount)
                        
                        for i in 0..<pageCount {
                            if let page = pdfDocument.page(at: i),
                               let pageImage = self.renderPDFPageToImage(page) {
                                pages.append(pageImage)
                            }
                        }
                        
                        // Set both documentPages and previewImage
                        self.documentPages = pages
                        self.previewImage = pages.first
                    } else if let image = UIImage(data: documentData) {
                        // Handle case for images directly
                        self.previewImage = image
                        self.documentPages = [image]
                    }
                }
                
                // Load available tags
                loadAvailableTags()
                
                // Load all folders
                loadAllFolders()
                
                DispatchQueue.main.async {
                    self.verifyPDFData()
                    self.isLoading = false
                }
            }
        } catch {
            print("Error fetching document: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    func saveTitle() {
        guard let document = document, !titleEdit.isEmpty else { return }
        
        persistenceController.viewContext.perform { [weak self] in
            guard let self = self else { return }
            
            document.title = self.titleEdit
            document.updatedAt = Date()
            
            do {
                try self.persistenceController.viewContext.save()
            } catch {
                print("Error saving title: \(error)")
            }
        }
    }
    
    func saveComments() {
        guard let document = document else { return }
        
        persistenceController.viewContext.perform { [weak self] in
            guard let self = self else { return }
            
            document.comments = self.comments
            document.updatedAt = Date()
            
            do {
                try self.persistenceController.viewContext.save()
                
                DispatchQueue.main.async {
                    self.isEditingComments = false
                }
            } catch {
                print("Error saving comments: \(error)")
            }
        }
    }
    
    func removeTag(_ tag: Tag) {
        guard let document = document else { return }
        
        // Remove tag from the document
        document.removeFromTags(tag)
        
        // Save changes
        do {
            try persistenceController.viewContext.save()
            
            // Now check if this tag is used on any other documents
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "ANY tags.id == %@", tag.id! as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let tagStillInUse = try persistenceController.viewContext.fetch(fetchRequest).count > 0
            
            // If tag is not used anywhere else, delete it
            if !tagStillInUse {
                print("Tag '\(tag.name ?? "unknown")' is no longer used on any documents - deleting")
                persistenceController.viewContext.delete(tag)
                try persistenceController.viewContext.save()
            }
            
            // Refresh UI elements to show the tags have been updated
            self.objectWillChange.send()
            
            // Don't post notification yet - wait for user to save the entire document
            
        } catch {
            print("Error removing tag: \(error.localizedDescription)")
        }
    }
    
    func addTag(_ tag: VMTagItem) {
        guard let document = document else { return }
        
        persistenceController.viewContext.perform { [weak self] in
            guard let self = self else { return }
            
            let tagFetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            tagFetchRequest.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)
            tagFetchRequest.fetchLimit = 1
            
            do {
                let tagResults = try self.persistenceController.viewContext.fetch(tagFetchRequest)
                
                if let tagObject = tagResults.first {
                    document.addToTags(tagObject)
                    document.updatedAt = Date()
                    
                    try self.persistenceController.viewContext.save()
                    self.updateAvailableTags()
                }
            } catch {
                print("Error adding tag: \(error)")
            }
        }
    }
    
    func createAndAddTag(name: String) {
        guard let document = document, !name.isEmpty else { return }
        
        persistenceController.viewContext.perform { [weak self] in
            guard let self = self else { return }
            
            // Create new tag
            let tag = Tag(context: self.persistenceController.viewContext)
            tag.id = UUID()
            tag.name = name
            tag.createdAt = Date()
            
            document.addToTags(tag)
            document.updatedAt = Date()
            
            do {
                try self.persistenceController.viewContext.save()
                
                // Update tag collections
                DispatchQueue.main.async {
                    // Also add to allTags
                    let newTagItem = VMTagItem(id: tag.id!, name: name)
                    self.allTags.append(newTagItem)
                    self.allTags.sort { $0.name < $1.name }
                    self.updateAvailableTags()
                }
            } catch {
                print("Error creating and adding tag: \(error)")
            }
        }
    }
    
    func removeFolder() {
        guard let document = document else { return }
        
        persistenceController.viewContext.perform { [weak self] in
            guard let self = self else { return }
            
            document.folderId = nil
            document.updatedAt = Date()
            
            do {
                try self.persistenceController.viewContext.save()
                
                DispatchQueue.main.async {
                    self.folderName = nil
                }
            } catch {
                print("Error removing folder: \(error)")
            }
        }
    }
    
    func setFolder(_ folder: VMFolderItem) {
        guard let document = document else { return }
        
        persistenceController.viewContext.perform { [weak self] in
            guard let self = self else { return }
            
            document.folderId = folder.id
            document.updatedAt = Date()
            
            do {
                try self.persistenceController.viewContext.save()
                
                DispatchQueue.main.async {
                    self.folderName = folder.name
                }
            } catch {
                print("Error setting folder: \(error)")
            }
        }
    }
    
    func createAndSetFolder(name: String) {
        guard let document = document, !name.isEmpty else { return }
        
        persistenceController.viewContext.perform { [weak self] in
            guard let self = self else { return }
            
            // Create new folder
            let folder = Folder(context: self.persistenceController.viewContext)
            folder.id = UUID()
            folder.name = name
            folder.createdAt = Date()
            
            document.folderId = folder.id
            document.updatedAt = Date()
            
            do {
                try self.persistenceController.viewContext.save()
                
                DispatchQueue.main.async {
                    self.folderName = name
                    
                    // Also add to allFolders
                    let newFolderItem = VMFolderItem(id: folder.id!, name: name)
                    self.allFolders.append(newFolderItem)
                    self.allFolders.sort { $0.name < $1.name }
                }
            } catch {
                print("Error creating and setting folder: \(error)")
            }
        }
    }
    
    func deleteDocument(completion: @escaping (Bool) -> Void) {
        guard let document = document, let documentId = document.id else {
            completion(false)
            return
        }
        
        // Use VaultViewModel to handle the deletion
        let vaultViewModel = VaultViewModel(persistenceController: self.persistenceController)
        vaultViewModel.deleteDocument(documentId)
        completion(true)
    }
    
    // MARK: - Private Methods
    
    private func fetchAllTags() {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let fetchedTags = try persistenceController.viewContext.fetch(fetchRequest)
            
            self.allTags = fetchedTags.compactMap { tag in
                guard let id = tag.id, let name = tag.name else {
                    return nil
                }
                
                return VMTagItem(id: id, name: name)
            }
        } catch {
            print("Failed to fetch tags: \(error.localizedDescription)")
        }
    }
    
    private func fetchAllFolders() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let fetchedFolders = try persistenceController.viewContext.fetch(fetchRequest)
            
            self.allFolders = fetchedFolders.compactMap { folder in
                guard let id = folder.id, let name = folder.name else {
                    return nil
                }
                
                return VMFolderItem(id: id, name: name)
            }
        } catch {
            print("Failed to fetch folders: \(error.localizedDescription)")
        }
    }
    
    // Improve the PDF rendering quality and ensure the whole page is visible
    private func renderPDFPageToImage(_ page: PDFPage) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        
        // Create a renderer at 2x scale for better resolution but not too large
        let scale: CGFloat = 2.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        )
        
        let img = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(x: 0, y: 0, width: pageRect.width * scale, height: pageRect.height * scale))
            
            // Save the graphics state
            ctx.cgContext.saveGState()
            
            // Get the context and translate/flip as needed for PDF coordinates
            ctx.cgContext.translateBy(x: 0, y: pageRect.height * scale)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            
            // Draw the page
            page.draw(with: .mediaBox, to: ctx.cgContext)
            
            // Restore the graphics state
            ctx.cgContext.restoreGState()
        }
        
        return img
    }
    
    // Update loadDocumentPages to be more robust
    func loadDocumentPages() {
        guard let document = document, let documentData = document.documentData else {
            documentPages = []
            return
        }
        
        // Check if the document is a PDF
        if isPDF(data: documentData) {
            // Try to extract pages from PDF using Core Graphics directly
            let pdfPages = extractPDFPages(from: documentData)
            
            if !pdfPages.isEmpty {
                documentPages = pdfPages
            } else {
                // Fallback - try using PDFKit
                if let pdfDocument = PDFDocument(data: documentData) {
                    var pages: [UIImage] = []
                    
                    let pageCount = max(1, pdfDocument.pageCount)
                    
                    for i in 0..<pageCount {
                        if let page = pdfDocument.page(at: i),
                           let pageImage = renderPDFPageToImage(page) {
                            pages.append(pageImage)
                        }
                    }
                    
                    documentPages = pages
                }
            }
        } else {
            // Single image document
            if let image = UIImage(data: documentData) {
                documentPages = [image]
            } else {
                documentPages = []
            }
        }
        
        // Set the preview image for compatibility
        previewImage = documentPages.first
    }
    
    private func isPDF(data: Data) -> Bool {
        // Check for PDF signature at the beginning of the data
        let pdfSignature = "%PDF"
        if let dataString = String(data: data.prefix(10), encoding: .ascii),
           dataString.hasPrefix(pdfSignature) {
            return true
        }
        return false
    }
    
    private func extractPDFPages(from data: Data) -> [UIImage] {
        var images: [UIImage] = []
        
        guard let provider = CGDataProvider(data: data as CFData),
              let pdfDocument = CGPDFDocument(provider) else {
            return images
        }
        
        let pageCount = pdfDocument.numberOfPages
        
        for pageNumber in 1...pageCount {
            guard let page = pdfDocument.page(at: pageNumber) else {
                continue
            }
            
            let pageRect = page.getBoxRect(.mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            
            let img = renderer.image { ctx in
                // Fill the background with white
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: pageRect.size))
                
                // Save graphics state
                ctx.cgContext.saveGState()
                
                // Draw the PDF page
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                ctx.cgContext.drawPDFPage(page)
                
                // Restore graphics state
                ctx.cgContext.restoreGState()
            }
            
            images.append(img)
        }
        
        return images
    }
    
    // Add this debug method to check PDF data
    func verifyPDFData() {
        if let documentData = document?.documentData {
            if documentData.isEmpty {
                print("⚠️ Document data is empty")
                self.documentPDFData = nil
            } else {
                print("✅ Document data exists: \(documentData.count) bytes")
                
                // Check if it's a valid PDF
                if let dataString = String(data: documentData.prefix(10), encoding: .ascii),
                   dataString.hasPrefix("%PDF") {
                    print("✅ Data appears to be a valid PDF")
                    self.documentPDFData = documentData
                } else {
                    print("⚠️ Data does not appear to be a PDF, creating PDF from image")
                    // If it's an image, convert it to PDF for proper sharing
                    if let image = UIImage(data: documentData) {
                        print("🔄 Converting image to PDF for sharing")
                        if let pdfData = createPDFFromImage(image) {
                            print("✅ Successfully created PDF from image: \(pdfData.count) bytes")
                            self.documentPDFData = pdfData
                        } else {
                            print("❌ Failed to create PDF from image")
                            // Make sure we don't have stale data
                            self.documentPDFData = nil
                        }
                    } else {
                        print("❌ Could not interpret data as PDF or image")
                        self.documentPDFData = nil
                    }
                }
            }
        } else {
            print("❌ No document data available")
            self.documentPDFData = nil
        }
    }
    
    // Add this helper method to create a PDF from an image if needed
    private func createPDFFromImage(_ image: UIImage) -> Data? {
        let pdfData = NSMutableData()
        
        // Create PDF with appropriate page size (use the image dimensions)
        let imageRect = CGRect(origin: .zero, size: image.size)
        
        // Start PDF context
        UIGraphicsBeginPDFContextToData(pdfData, imageRect, nil)
        
        // Create a PDF page
        UIGraphicsBeginPDFPage()
        
        // Get the current context
        if let context = UIGraphicsGetCurrentContext() {
            // Save the graphics state
            context.saveGState()
            
            // Fill with white background
            UIColor.white.setFill()
            context.fill(imageRect)
            
            // Flip coordinates (PDF coordinate system is different)
            context.translateBy(x: 0, y: image.size.height)
            context.scaleBy(x: 1, y: -1)
            
            // Draw the image
            if let cgImage = image.cgImage {
                context.draw(cgImage, in: imageRect)
            }
            
            // Restore the graphics state
            context.restoreGState()
        }
        
        // End PDF context
        UIGraphicsEndPDFContext()
        
        if pdfData.length > 0 {
            return pdfData as Data
        } else {
            return nil
        }
    }
}

// If you need access to these types within this file only,
// you can move them to a separate Model file or use the following
// declarations but keep them commented out in this file
/*
struct TagItem: Identifiable {
    let id: UUID
    let name: String
}

struct FolderItem: Identifiable {
    let id: UUID
    let name: String
}
*/ 
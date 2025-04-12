import SwiftUI
import CoreData
import AppKit
import PDFKit
import ObjectiveC

struct DocumentViewerWindow: View {
    let document: NSManagedObject
    @State private var currentPage: Int = 0
    @State private var isLoading: Bool = true
    @State private var documentHasPDF: Bool = false
    @State private var pdfDocument: PDFDocument? = nil
    @State private var pageCount: Int = 0
    @State private var thumbnailImage: NSImage? = nil
    @State private var zoomLevel: Double = 1.2 // Changed from 0.67 to 1.2 (120%)
    @State private var showingDetailsSheet = false // Added for metadata sheet
    @State private var hasChanges = false {
        didSet {
            print("hasChanges changed from \(oldValue) to \(hasChanges)")
        }
    }
    
    // State variables for editable metadata fields
    @State private var title: String = ""
    @State private var category: String = ""
    @State private var comments: String = "" // Renamed from notes to comments
    @State private var folderName: String = "Unassigned Document" // Changed from "Unfiled"
    @State private var selectedFolderId: UUID?
    @State private var allFolders: [FolderItem] = []
    @State private var showingNewFolderAlert = false
    @State private var newFolderName: String = ""
    @Environment(\.managedObjectContext) var viewContext
    
    @State private var tagArray: [String] = [] // New array to manage individual tags
    @State private var newTag: String = "" // For adding new tags
    
    // Add focus state for comments
    @FocusState private var _isCommentsFocused: Bool // Renamed from _isNotesFocused
    
    // Add these new state variables
    @State private var showSaveConfirmation = false
    @State private var isSaving = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Extract the left sidebar into a separate view
            DocumentSidebar(
                document: document,
                title: $title,
                category: $category,
                comments: $comments, // Renamed from notes to comments
                folderName: $folderName,
                selectedFolderId: $selectedFolderId,
                allFolders: allFolders,
                showingNewFolderAlert: $showingNewFolderAlert,
                newFolderName: $newFolderName,
                tagArray: $tagArray,
                newTag: $newTag,
                isCommentsFocused: $_isCommentsFocused, // Renamed from isNotesFocused
                showSaveConfirmation: $showSaveConfirmation,
                isSaving: $isSaving,
                hasChanges: $hasChanges,
                onSave: saveChanges,
                createNewFolder: createNewFolder,
                addNewTag: addNewTag,
                hasProperty: hasProperty
            )
            
            // Extract the right document display into a separate view
            DocumentDisplay(
                document: document,
                documentHasPDF: documentHasPDF,
                pdfDocument: pdfDocument,
                pageCount: pageCount,
                currentPage: $currentPage,
                zoomLevel: $zoomLevel,
                isLoading: isLoading,
                thumbnailImage: thumbnailImage
            )
        }
        .onAppear {
            loadPDFDocument()
            loadDocumentData()
            loadFolderInfo()
            fetchAllFolders()
            
            DispatchQueue.main.async {
                hasChanges = false
            }
            
            print("Initial hasChanges state: \(hasChanges)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                documentShareButton
            }
            
            if documentHasPDF {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: toggleZoomMode) {
                        Image(systemName: "text.magnifyingglass")
                            .imageScale(.large)
                            .help("Toggle between fit to width and actual size")
                    }
                }
            } else if thumbnailImage != nil {
                // Only show image controls if we have an image to display
                // Removed isImageDocument() call which was causing the crash
                
                // Add image-specific controls when viewing an image
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if let window = NSApplication.shared.keyWindow,
                           let scrollView = findScrollView(in: window.contentView),
                           let imageView = scrollView.documentView as? NSImageView {
                            
                            // Toggle between fit and 1:1 view
                            if scrollView.magnification != 1.0 {
                                // Set to 1:1
                                scrollView.magnification = 1.0
                            } else {
                                // Fit to view
                                if let image = imageView.image {
                                    let viewSize = scrollView.contentSize
                                    let imageSize = image.size
                                    let widthRatio = viewSize.width / imageSize.width
                                    let heightRatio = viewSize.height / imageSize.height
                                    scrollView.magnification = min(widthRatio, heightRatio)
                                }
                            }
                        }
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .imageScale(.large)
                            .help("Toggle between actual size and fit to view")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if let window = NSApplication.shared.keyWindow,
                           let scrollView = findScrollView(in: window.contentView) {
                            // Zoom in
                            scrollView.magnification = min(scrollView.magnification * 1.25, scrollView.maxMagnification)
                        }
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .imageScale(.large)
                            .help("Zoom in")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if let window = NSApplication.shared.keyWindow,
                           let scrollView = findScrollView(in: window.contentView) {
                            // Zoom out
                            scrollView.magnification = max(scrollView.magnification * 0.8, scrollView.minMagnification)
                        }
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .imageScale(.large)
                            .help("Zoom out")
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetailsSheet) {
            DocumentMetadataSheet(document: document, hasChanges: $hasChanges)
                .frame(width: 500, height: 600)
        }
        .onDisappear {
            if hasChanges {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentUpdated"),
                    object: nil,
                    userInfo: [
                        "documentId": document.value(forKey: "id") as? UUID ?? UUID(),
                        "folderChanged": false,
                        "timestamp": Date()
                    ]
                )
            }
        }
        .overlay(saveConfirmationOverlay)
    }
    
    // Extract the share button logic into a computed property
    private var documentShareButton: some View {
        Group {
            if documentHasPDF {
                Button(action: {
                    if let pdfData = document.value(forKey: "documentData") as? Data ?? document.value(forKey: "pdfData") as? Data {
                        sharePDFDocument(pdfData)
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.large)
                }
            } else {
                ShareLink(item: document.value(forKey: "title") as? String ?? "Untitled Document") {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.large)
                }
            }
        }
    }
    
    // Extract the save confirmation overlay into a computed property
    private var saveConfirmationOverlay: some View {
        ZStack {
            if showSaveConfirmation {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title)
                        
                        VStack(alignment: .leading) {
                            Text("Changes Saved!")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if selectedFolderId != nil {
                                Text("Document moved to: \(folderName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(radius: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 2)
                    )
                }
                .padding()
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSaveConfirmation = false
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showSaveConfirmation)
    }
    
    private func loadPDFDocument() {
        isLoading = true
        print("===== DOCUMENT DEBUG =====")
        print("Entity name: \(document.entity.name ?? "Unknown")")
        print("Available properties: \(document.entity.propertiesByName.keys.joined(separator: ", "))")
        
        // First check if this is actually an image file rather than a PDF
        if isImageDocument() {
            print("📸 Document is an image file, loading as image")
            loadImageDocument()
            isLoading = false
            return
        }
        
        // Check for PDF data in either field name
        if loadPDFFromProperty("pdfData") || loadPDFFromProperty("documentData") {
            print("PDF document loaded successfully")
        } else {
            print("❌ No PDF content could be found")
            documentHasPDF = false
        }
        
        isLoading = false
        
        // Simplified thumbnail loading - consolidate into a single check
        if !documentHasPDF {
            if hasProperty("thumbnail"), let thumbnailData = document.value(forKey: "thumbnail") as? Data,
               let thumbnail = NSImage(data: thumbnailData) {
                print("✅ Found thumbnail image")
                self.thumbnailImage = thumbnail
            } else if let thumbnail = document.getThumbnailImage?() as? NSImage {
                print("✅ Retrieved thumbnail via method")
                self.thumbnailImage = thumbnail
            }
        }
    }
    
    // New method to check if document is an image type
    private func isImageDocument() -> Bool {
        // Check for common image properties safely
        if let doc = document as? NSManagedObject {
            let imageProps = ["imageData", "image", "originalImage"]
            
            // First check for image data properties
            for prop in imageProps {
                if doc.entity.propertiesByName[prop] != nil,
                   let data = doc.value(forKey: prop) as? Data,
                   !data.isEmpty {
                    return true
                }
            }
            
            // If we have a filename that looks like an image
            if doc.entity.propertiesByName["fileName"] != nil,
               let fileName = doc.value(forKey: "fileName") as? String {
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff"]
                if imageExtensions.contains(where: { fileName.lowercased().hasSuffix(".\($0)") }) {
                    return true
                }
            }
            
            // As a fallback, check the title
            if let title = doc.value(forKey: "title") as? String {
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff"]
                if imageExtensions.contains(where: { title.lowercased().hasSuffix(".\($0)") }) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // New method to load image document data
    private func loadImageDocument() {
        print("🖼️ Loading image document...")
        
        // Log document properties for debugging
        print("📊 Document properties: \(document.entity.propertiesByName.keys.joined(separator: ", "))")
        
        // First try directly setting documentHasPDF to false to ensure we treat this as an image
        documentHasPDF = false
        
        // Attempt to load the full-resolution image from all possible sources
        if loadFullResolutionImage() {
            print("✅ Successfully loaded full-resolution image")
            return
        }
        
        // Fall back to thumbnail if no full image is found
        print("⚠️ Could not find full-resolution image, checking for thumbnail")
        if hasProperty("thumbnail"), let thumbnailData = document.value(forKey: "thumbnail") as? Data,
           !thumbnailData.isEmpty, let thumbnail = NSImage(data: thumbnailData) {
            print("✅ Using thumbnail as fallback: \(thumbnailData.count) bytes")
            self.thumbnailImage = thumbnail
        } else if let thumbnail = document.getThumbnailImage?() as? NSImage {
            print("✅ Using method-based thumbnail as fallback")
            self.thumbnailImage = thumbnail
        } else {
            print("❌ No image data found in document")
        }
    }
    
    // New method to try loading the full-resolution image from all possible sources
    private func loadFullResolutionImage() -> Bool {
        // All possible property names that could contain image data
        let imageProperties = ["imageData", "image", "originalImage", "documentData", "pdfData", "data", "fileData", "content"]
        
        // Try each property
        for prop in imageProperties {
            if hasProperty(prop), let data = document.value(forKey: prop) as? Data, !data.isEmpty {
                print("📊 Checking property: \(prop) with \(data.count) bytes")
                if let image = NSImage(data: data) {
                    print("✅ Loaded full-resolution image from \(prop) property: \(data.count) bytes")
                    print("✅ Image dimensions: \(image.size.width) x \(image.size.height)")
                    self.thumbnailImage = image
                    return true
                } else {
                    print("⚠️ Data in \(prop) could not be converted to image")
                }
            }
        }
        
        return false
    }
    
    // Helper method to try loading PDF from a specific property
    private func loadPDFFromProperty(_ propertyName: String) -> Bool {
        if hasProperty(propertyName) {
            print("\(propertyName) property exists!")
            if let pdfData = document.value(forKey: propertyName) as? Data {
                print("PDF data found: \(pdfData.count) bytes")
                if let pdf = PDFDocument(data: pdfData) {
                    print("PDF document created successfully with \(pdf.pageCount) pages")
                    self.pdfDocument = pdf
                    self.pageCount = pdf.pageCount
                    documentHasPDF = true
                    return true
                } else {
                    print("⚠️ Failed to create PDFDocument from data")
                }
            } else {
                print("⚠️ No PDF data value found or could not be cast to Data")
            }
        }
        return false
    }
    
    // Helper function to check if a property exists
    private func hasProperty(_ name: String) -> Bool {
        return document.entity.propertiesByName[name] != nil
    }
    
    // Simple PDF sharing function with improved error handling
    private func sharePDFDocument(_ pdfData: Data) {
        let fileName = (document.value(forKey: "title") as? String ?? "Untitled Document").replacingOccurrences(of: "/", with: "-")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pdf")
        
        do {
            try pdfData.write(to: tempURL)
            let sharingPicker = NSSharingServicePicker(items: [tempURL])
            
            if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
                sharingPicker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
            }
        } catch {
            print("Error sharing PDF: \(error)")
        }
    }
    
    private func loadDocumentData() {
        // Basic properties
        title = document.value(forKey: "title") as? String ?? ""
        
        // Only attempt to get category if the property exists
        if document.entity.propertiesByName["category"] != nil {
            category = document.value(forKey: "category") as? String ?? ""
        } else {
            category = "" // Default value if property doesn't exist
        }
        
        // Enhanced tag parsing with debug output
        print("📌 Loading tags for document: \((document.value(forKey: "id") as? UUID)?.uuidString ?? "unknown")")
        
        // First check if tags is a relationship
        if let tagsSet = document.value(forKey: "tags") as? NSSet {
            print("📌 Found tags relationship with \(tagsSet.count) items")
            
            // Convert Tag entities to strings
            tagArray = tagsSet.compactMap { tagObject in
                guard let tag = tagObject as? NSManagedObject else { return nil }
                let tagName = tag.value(forKey: "name") as? String
                print("📌 Found tag: \(tagName ?? "unnamed")")
                return tagName
            }
            
            print("📌 Loaded \(tagArray.count) tags from relationship: \(tagArray.joined(separator: ", "))")
        } else if let tagsString = document.value(forKey: "tags") as? String {
            // Handle tags as a string
            print("📌 Found tags string: \"\(tagsString)\"")
            
            tagArray = !tagsString.isEmpty ? 
                tagsString.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } : 
                []
            
            print("📌 Parsed \(tagArray.count) tags from string: \(tagArray.joined(separator: ", "))")
        } else {
            print("📌 No tags found or unable to parse tags")
            tagArray = []
        }
        
        // Get comments - always check 'comments' field first
        if hasProperty("comments") {
            comments = document.value(forKey: "comments") as? String ?? ""
        } else if hasProperty("notes") {
            // Fallback to notes if comments doesn't exist
            comments = document.value(forKey: "notes") as? String ?? ""
        } else {
            comments = ""
        }
        
        // Get folder ID
        if let folderId = document.value(forKey: "folderId") as? UUID {
            selectedFolderId = folderId
        } else {
            selectedFolderId = nil
            folderName = "Unassigned Document"
        }
    }
    
    private func saveChanges() {
        // Start saving indicator
        isSaving = true
        
        // Use shared save function
        document.saveDocumentChanges(
            title: title,
            notes: comments, // Pass comments to the save method
            category: hasProperty("category") ? category : nil,
            selectedFolderId: selectedFolderId,
            tagArray: tagArray
        ) { success in
            // Update UI state based on result
            withAnimation {
                self.showSaveConfirmation = success
                self.isSaving = false
                self.hasChanges = false
            }
            
            // Set a timeout to recover from hangs
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if self.isSaving {
                    print("⚠️ Save operation timed out after 5 seconds")
                    self.isSaving = false
                }
            }
            
            // Auto-hide the confirmation after delay
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        self.showSaveConfirmation = false
                    }
                }
            }
        }
    }
    
    // Function to add a new tag
    private func addNewTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tagArray.contains(trimmedTag) {
            tagArray.append(trimmedTag)
            newTag = ""
            hasChanges = true
        }
    }
    
    // Renamed from loadFolderName to loadFolderInfo
    private func loadFolderInfo() {
        // Default to "Unassigned Document" if anything goes wrong
        folderName = "Unassigned Document" // Changed from "Unfiled"
        
        // Check if folderId exists
        guard let folderId = document.value(forKey: "folderId") as? UUID else {
            print("📁 No folderId found for document")
            return
        }
        
        selectedFolderId = folderId
        
        // Make sure we have a valid managed object context
        guard let context = document.managedObjectContext else {
            print("❌ No managedObjectContext available for the document")
            return
        }
        
        // Use the document's context instead of viewContext
        print("📁 Attempting to fetch folder with ID: \(folderId)")
        
        // Create safer fetch request
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
        fetchRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let folder = results.first, let name = folder.value(forKey: "name") as? String {
                folderName = name
                print("✅ Found folder: \(name)")
            } else {
                print("⚠️ Folder with ID \(folderId) not found")
            }
        } catch {
            print("❌ Error fetching folder: \(error.localizedDescription)")
        }
    }
    
    // New method to fetch all folders
    private func fetchAllFolders() {
        allFolders = document.fetchAllFolders()
        print("📁 Fetched \(allFolders.count) folders")
    }
    
    // New method to create a folder
    private func createNewFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let context = document.managedObjectContext else {
            return
        }
        
        // Create a new Folder entity
        let entityDescription = NSEntityDescription.entity(forEntityName: "Folder", in: context)
        guard let entityDescription = entityDescription else {
            print("❌ Couldn't get entity description for Folder")
            return
        }
        
        let newFolder = NSManagedObject(entity: entityDescription, insertInto: context)
        let folderId = UUID()
        
        newFolder.setValue(folderId, forKey: "id")
        newFolder.setValue(newFolderName, forKey: "name")
        newFolder.setValue(Date(), forKey: "createdAt")
        
        do {
            try context.save()
            print("✅ Created new folder: \(newFolderName)")
            
            // Update local state
            selectedFolderId = folderId
            folderName = newFolderName
            
            // Add to folders list
            allFolders.append(FolderItem(id: folderId, name: newFolderName))
            allFolders.sort { $0.name < $1.name }
            
            // Mark document as changed
            hasChanges = true
            
            // Reset new folder name
            newFolderName = ""
        } catch {
            print("❌ Failed to create folder: \(error.localizedDescription)")
        }
    }
    
    // Function to toggle between zoom modes
    private func toggleZoomMode() {
        guard let pdfView = getPDFView() else { return }
        
        if pdfView.autoScales {
            // Switch to manual zoom mode (120%)
            pdfView.autoScales = false
            pdfView.scaleFactor = 1.2
            zoomLevel = 1.2
        } else {
            // Switch to auto-fit mode
            pdfView.autoScales = true
            DispatchQueue.main.async {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                // Update the zoom slider to roughly match the fit scale
                zoomLevel = pdfView.scaleFactor
            }
        }
    }
    
    // Helper method to find the current PDFView
    private func getPDFView() -> PDFView? {
        // Try to find the PDFView in the app's windows
        for window in NSApplication.shared.windows {
            for view in window.contentView?.subviews ?? [] {
                if let pdfView = findPDFView(in: view) {
                    return pdfView
                }
            }
        }
        return nil
    }
    
    // Recursive helper to find PDFView
    private func findPDFView(in view: NSView) -> PDFView? {
        if let pdfView = view as? PDFView {
            return pdfView
        }
        
        for subview in view.subviews {
            if let pdfView = findPDFView(in: subview) {
                return pdfView
            }
        }
        
        return nil
    }
    
    // Helper to find a scroll view in the view hierarchy
    private func findScrollView(in view: NSView?) -> NSScrollView? {
        guard let view = view else { return nil }
        
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        
        return nil
    }
}

// Create a new struct for the document sidebar
struct DocumentSidebar: View {
    let document: NSManagedObject
    @Binding var title: String
    @Binding var category: String
    @Binding var comments: String
    @Binding var folderName: String
    @Binding var selectedFolderId: UUID?
    let allFolders: [FolderItem]
    @Binding var showingNewFolderAlert: Bool
    @Binding var newFolderName: String
    @Binding var tagArray: [String]
    @Binding var newTag: String
    var isCommentsFocused: FocusState<Bool>.Binding
    @Binding var showSaveConfirmation: Bool
    @Binding var isSaving: Bool
    @Binding var hasChanges: Bool
    let onSave: () -> Void
    let createNewFolder: () -> Void
    let addNewTag: () -> Void
    let hasProperty: (String) -> Bool
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Document Information section
                    documentInfoSection
                    
                    // Tags section
                    tagsSection
                    
                    Divider()
                    
                    // Notes section (if applicable)
                    if hasProperty("notes") || hasProperty("comments") {
                        notesSection
                        Divider()
                    }
                    
                    // System Information section
                    systemInfoSection
                    
                    Spacer(minLength: 20)
                    
                    // Save button
                    saveButton
                }
                .padding()
            }
        }
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
        .border(Color.gray.opacity(0.2), width: 1)
        .alert("Create New Folder", isPresented: $showingNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                createNewFolder()
            }
        } message: {
            Text("Enter a name for the new folder")
        }
    }
    
    // Document info section as a computed property
    private var documentInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document Information")
                .font(.headline)
            
            // Title field
            VStack(alignment: .leading) {
                Text("Title")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: title) { oldValue, newValue in
                        if oldValue != newValue {
                            hasChanges = true
                        }
                    }
            }
            
            // Folder field
            VStack(alignment: .leading) {
                Text("Folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                CustomFolderPopup(
                    selectedFolderId: $selectedFolderId,
                    folderName: $folderName,
                    hasChanges: $hasChanges,
                    folders: allFolders,
                    showNewFolderAlert: { showingNewFolderAlert = true }
                )
                .frame(maxWidth: .infinity, minHeight: 30, idealHeight: 30, maxHeight: 30)
            }
        }
    }
    
    // Tags section as a computed property
    private var tagsSection: some View {
        VStack(alignment: .leading) {
            Text("Tags")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Display existing tags
            if tagArray.isEmpty {
                Text("No tags")
                    .italic()
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(tagArray, id: \.self) { tagName in
                        HStack {
                            Text(tagName)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            Button(action: {
                                removeTag(tagName)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.small)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Add new tag UI
            HStack {
                TextField("Add tag", text: $newTag, onCommit: addNewTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addNewTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // Notes section as a computed property
    private var notesSection: some View {
        Group {
            Text("Notes")
                .font(.headline)
            
            TextEditor(text: $comments)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .onChange(of: comments) { _, _ in hasChanges = true }
                .focused(isCommentsFocused)
        }
    }
    
    // System info section as a computed property
    private var systemInfoSection: some View {
        Group {
            Text("System Information")
                .font(.headline)
            
            if let createdAt = document.value(forKey: "createdAt") as? Date {
                Text("Scanned: \(createdAt.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            if let updatedAt = document.value(forKey: "updatedAt") as? Date {
                Text("Last updated: \(updatedAt.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            if let documentId = document.value(forKey: "id") as? UUID {
                Text("UUID: \(documentId.uuidString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }
    
    // Save button as a computed property
    private var saveButton: some View {
        Button(action: onSave) {
            HStack {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else if showSaveConfirmation {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
                
                Text(showSaveConfirmation ? "Saved!" : "Save Changes")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!hasChanges || isSaving || showSaveConfirmation)
        .opacity(hasChanges ? 1.0 : 0.6)
    }
    
    // Add a helper method to the DocumentSidebar struct
    func removeTag(_ tagName: String) {
        if let index = tagArray.firstIndex(of: tagName) {
            tagArray.remove(at: index)
            hasChanges = true
        }
    }
}

// Create a new struct for the document display
struct DocumentDisplay: View {
    let document: NSManagedObject
    let documentHasPDF: Bool
    let pdfDocument: PDFDocument?
    let pageCount: Int
    @Binding var currentPage: Int
    @Binding var zoomLevel: Double
    let isLoading: Bool
    let thumbnailImage: NSImage?
    
    var body: some View {
        VStack {
            // Navigation header
            documentHeader
            
            // Document content
            if isLoading {
                ProgressView("Loading document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if documentHasPDF, let pdfDoc = pdfDocument {
                pdfDocumentView(pdfDoc)
            } else if let thumbnail = thumbnailImage {
                // Show image directly - bypass the old check
                imageViewer(thumbnail)
            } else {
                noContentView
            }
        }
    }
    
    // Document header as a computed property
    private var documentHeader: some View {
        HStack {
            Text(document.value(forKey: "title") as? String ?? "Untitled Document")
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            // Zoom controls for PDF
            if documentHasPDF {
                zoomControls
            }
            
            // Page navigation for multi-page documents
            if pageCount > 1 {
                pageNavigation
            }
        }
        .padding()
    }
    
    // Zoom controls as a computed property
    private var zoomControls: some View {
        HStack(spacing: 8) {
            // Add fit to width button
            Button(action: {
                if let window = NSApplication.shared.keyWindow,
                   let pdfView = findPDFView(in: window.contentView) {
                    pdfView.autoScales = true
                    DispatchQueue.main.async {
                        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                    }
                }
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .help("Fit to Width")
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            
            Image(systemName: "minus")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $zoomLevel, in: 0.25...2.0) { _ in }
                .frame(width: 120)
                .onChange(of: zoomLevel) { _, newValue in
                    if pdfDocument != nil {
                        // Disable auto-scaling when manually adjusting zoom
                        if let window = NSApplication.shared.keyWindow,
                           let pdfView = findPDFView(in: window.contentView) {
                            pdfView.autoScales = false
                        }
                        NotificationCenter.default.post(
                            name: NSNotification.Name("UpdateZoom"),
                            object: newValue
                        )
                    }
                }
            
            Image(systemName: "plus")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
    
    // Helper to find a PDFView in the view hierarchy
    private func findPDFView(in view: NSView?) -> PDFView? {
        guard let view = view else { return nil }
        
        if let pdfView = view as? PDFView {
            return pdfView
        }
        
        for subview in view.subviews {
            if let found = findPDFView(in: subview) {
                return found
            }
        }
        
        return nil
    }
    
    // Page navigation as a computed property
    private var pageNavigation: some View {
        HStack(spacing: 20) {
            Button(action: {
                if currentPage > 0 {
                    currentPage -= 1
                }
            }) {
                Image(systemName: "chevron.left")
                    .imageScale(.large)
            }
            .disabled(currentPage == 0)
            
            Text("\(currentPage + 1) of \(pageCount)")
                .font(.subheadline)
            
            Button(action: {
                if currentPage < pageCount - 1 {
                    currentPage += 1
                }
            }) {
                Image(systemName: "chevron.right")
                    .imageScale(.large)
            }
            .disabled(currentPage == pageCount - 1)
        }
    }
    
    // PDF document view as a method
    private func pdfDocumentView(_ pdfDoc: PDFDocument) -> some View {
        Group {
            if pageCount > 1 {
                // Multi-page PDF document
                VStack(spacing: 0) {
                    // Main PDF view
                    PDFViewerWithNavigation(pdfDocument: pdfDoc, initialPage: currentPage)
                        .onChange(of: currentPage) { _, newValue in
                            if let page = pdfDoc.page(at: newValue) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("GoToPage"),
                                    object: page
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Thumbnail strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<pageCount, id: \.self) { index in
                                PDFThumbnailView(
                                    pdfDocument: pdfDoc,
                                    pageIndex: index,
                                    onSelect: {
                                        currentPage = index
                                        if let page = pdfDoc.page(at: index) {
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("GoToPage"),
                                                object: page
                                            )
                                        }
                                    }
                                )
                                .frame(width: 70, height: 90)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(currentPage == index ? Color.blue : Color.gray, lineWidth: 2)
                                )
                                .background(currentPage == index ? Color.blue.opacity(0.1) : Color.clear)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    }
                    .frame(height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } else {
                // Single-page PDF document
                PDFViewerWithNavigation(pdfDocument: pdfDoc, initialPage: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // Renamed from thumbnailView to imageView to better reflect its purpose
    private func thumbnailView(_ image: NSImage) -> some View {
        Group {
            if isImageDocument() {
                // For actual image documents, display at full resolution with zoom controls
                imageViewer(image)
            } else {
                // For PDF thumbnails, keep the message
                VStack {
                    Text("PDF content not available - showing thumbnail")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    // New image viewer optimized for displaying images like in iOS
    private func imageViewer(_ image: NSImage) -> some View {
        BasicImageViewer(image: image)
    }
    
    // Helper to check if this is an image document vs a PDF with thumbnail
    private func isImageDocument() -> Bool {
        // Check for common image properties safely
        if let doc = document as? NSManagedObject {
            let imageProps = ["imageData", "image", "originalImage"]
            
            // First check for image data properties
            for prop in imageProps {
                if doc.entity.propertiesByName[prop] != nil,
                   let data = doc.value(forKey: prop) as? Data,
                   !data.isEmpty {
                    return true
                }
            }
            
            // If we have a filename that looks like an image
            if doc.entity.propertiesByName["fileName"] != nil,
               let fileName = doc.value(forKey: "fileName") as? String {
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff"]
                if imageExtensions.contains(where: { fileName.lowercased().hasSuffix(".\($0)") }) {
                    return true
                }
            }
            
            // As a fallback, check the title
            if let title = doc.value(forKey: "title") as? String {
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff"]
                if imageExtensions.contains(where: { title.lowercased().hasSuffix(".\($0)") }) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // No content view as a computed property
    private var noContentView: some View {
        Text("No document content available")
            .font(.title)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Improved PDF viewer with navigation support
struct PDFViewerWithNavigation: NSViewRepresentable {
    let pdfDocument: PDFDocument
    var initialPage: Int = 0
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        
        // Configure general settings
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = 0.25
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.interpolationQuality = .high
        pdfView.backgroundColor = NSColor(white: 0.95, alpha: 1.0)
        
        // Show a border around the page for better visibility
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Set scaling based on PDF type
        DispatchQueue.main.async {
            if pdfDocument.isScannedPDF() {
                // For scanned/image-based PDFs:
                // 1. Enable auto-scaling to fit width
                pdfView.autoScales = true
                // 2. Use scale to fit for better viewing
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            } else {
                // For vector/native PDFs:
                // Keep the current fixed scaling behavior
                pdfView.autoScales = false
                pdfView.scaleFactor = 1.2 // 120%
            }
        }
        
        // Go to initial page
        if initialPage > 0 && initialPage < pdfDocument.pageCount,
           let page = pdfDocument.page(at: initialPage) {
            pdfView.go(to: page)
        }
        
        // Set up observers for page navigation and zoom
        context.coordinator.pdfView = pdfView
        context.coordinator.setupObservers()
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Keep document up to date
        nsView.document = pdfDocument
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        weak var pdfView: PDFView?
        var observers: [NSObjectProtocol] = []
        
        deinit {
            // Remove all observers in one step
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            print("🧹 PDFViewerWithNavigation.Coordinator deinit")
        }
        
        func setupObservers() {
            // Create and store all observers in the array for easier management
            let pageObserver = NotificationCenter.default.addObserver(
                forName: .goToPage,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self, let pdfView = self.pdfView else { return }
                
                if let page = notification.object as? PDFPage {
                    pdfView.go(to: page)
                }
            }
            
            let zoomObserver = NotificationCenter.default.addObserver(
                forName: .updateZoom,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self, let pdfView = self.pdfView else { return }
                
                if let zoomLevel = notification.object as? Double {
                    pdfView.scaleFactor = zoomLevel
                }
            }
            
            // Store observers for cleanup
            observers = [pageObserver, zoomObserver]
        }
    }
}

// PDF thumbnail view simplified
struct PDFThumbnailView: NSViewRepresentable {
    let pdfDocument: PDFDocument
    let pageIndex: Int
    let onSelect: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        // Create container and PDF view in one operation
        let containerView = NSView()
        let thumbnailView = PDFView()
        
        // Configure PDF view with chained properties
        thumbnailView.document = pdfDocument
        thumbnailView.displayMode = .singlePage
        thumbnailView.autoScales = true
        thumbnailView.backgroundColor = .white
        if let page = pdfDocument.page(at: pageIndex) {
            thumbnailView.go(to: page)
        }
        
        // Add to container with auto layout
        containerView.addSubview(thumbnailView)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: containerView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Add click recognizer
        containerView.addGestureRecognizer(
            NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick))
        )
        
        return containerView
    }
    
    // Simplify update method
    func updateNSView(_ nsView: NSView, context: Context) {
        if let pdfView = nsView.subviews.first as? PDFView, 
           let page = pdfDocument.page(at: pageIndex) {
            pdfView.go(to: page)
        }
        context.coordinator.onSelect = onSelect
    }
    
    // Simplify coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject {
        var onSelect: () -> Void
        
        init(onSelect: @escaping () -> Void) {
            self.onSelect = onSelect
            super.init()
        }
        
        @objc func handleClick() {
            onSelect()
        }
    }
}

// Window management code
class DocumentWindowController: NSObject, NSWindowDelegate {
    var window: NSWindow?
    var observer: Any?
    
    deinit {
        print("🧹 DocumentWindowController deinit")
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        print("🪟 Document window will close")
        
        // Remove from static array to prevent memory leaks
        if let window = notification.object as? NSWindow {
            DocumentViewerWindow.windowControllers.removeAll { $0.window === window }
        }
        
        // Remove all observers
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        
        // Clear window reference
        window = nil
    }
    
    func showWindow(with contentView: DocumentViewerWindow, title: String) {
        // Create and configure window in a single step
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Quick configuration in one block
        window.title = title
        window.contentViewController = NSHostingController(rootView: contentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = NSToolbar(identifier: "EmptyToolbar")
        window.delegate = self
        window.isReleasedWhenClosed = false
        
        // Store reference and show
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.setFrame(NSScreen.main?.visibleFrame ?? window.frame, display: true)
        
        // Register for window closing notification in one step
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            self?.windowWillClose(notification)
        }
    }
}

// Static window controller management - simplify by removing redundant checks
extension DocumentViewerWindow {
    // Static window controller tracking
    static var windowControllers = [DocumentWindowController]()
    
    static func openDocument(_ document: NSManagedObject) {
        // Get the document ID
        guard let documentId = document.value(forKey: "id") as? UUID else {
            print("❌ Cannot open document: Missing document ID")
            return
        }
        
        // Get document title for better logging
        let documentTitle = document.value(forKey: "title") as? String ?? "Untitled Document"
        
        print("🔐🔐🔐 DOCUMENT LOCK TEST: Opening document '\(documentTitle)' with ID: \(documentId)")
        
        // Check if document is locked first
        let isLocked = DocumentLockManager.shared.isDocumentLocked(documentId)
        print("🔐🔐🔐 DOCUMENT LOCK TEST: Is document '\(documentTitle)' locked? \(isLocked)")
        
        if isLocked {
            // Check if document was recently authenticated
            if DocumentLockManager.shared.hasRecentAuthentication(documentId) {
                print("🔐🔐🔐 DOCUMENT LOCK TEST: Document '\(documentTitle)' was recently authenticated, skipping password prompt")
                createAndShowWindow(document)
                return
            }
            
            print("🔐🔐🔐 DOCUMENT LOCK TEST: Document '\(documentTitle)' IS LOCKED, should show password prompt")
            // Use the standard system alert for password prompt
            let alert = NSAlert()
            alert.messageText = "This document is locked"
            alert.informativeText = "Please enter the password to view this document."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Unlock")
            alert.addButton(withTitle: "Cancel")
            
            let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            passwordField.placeholderString = "Password"
            alert.accessoryView = passwordField
            
            if alert.runModal() == .alertFirstButtonReturn {
                let password = passwordField.stringValue
                print("🔐🔐🔐 DOCUMENT LOCK TEST: Password entered for '\(documentTitle)', verifying...")
                
                let isPasswordValid = DocumentLockManager.shared.verifyDocumentLockPasswordCrossPlatform(password)
                print("🔐🔐🔐 DOCUMENT LOCK TEST: Password validation result: \(isPasswordValid)")
                
                if isPasswordValid {
                    // Password correct, temporarily unlock and continue opening
                    print("🔐🔐🔐 DOCUMENT LOCK TEST: Password verified successfully, continuing to open document '\(documentTitle)'")
                    
                    // Add this document to authentication cache
                    DocumentLockManager.shared.addToAuthenticationCache(documentId)
                    
                    // Temporarily grant access without actually unlocking the document in the system
                    // Only create and show the window, but don't call unlockDocument()
                    createAndShowWindow(document)
                    
                    // No need to re-lock since we never unlocked in the first place
                    print("🔐🔐🔐 DOCUMENT LOCK TEST: Document '\(documentTitle)' remains locked in the system")
                    
                    // Notify that temporary access was granted
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TemporaryDocumentAccess"),
                        object: nil,
                        userInfo: ["documentId": documentId]
                    )
                } else {
                    // Password incorrect
                    print("🔐🔐🔐 DOCUMENT LOCK TEST: Password verification FAILED for '\(documentTitle)'")
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Incorrect Password"
                    errorAlert.informativeText = "The password you entered is incorrect."
                    errorAlert.alertStyle = .critical
                    errorAlert.runModal()
                    return
                }
            } else {
                // User canceled, don't open the document
                print("🔐🔐🔐 DOCUMENT LOCK TEST: User canceled password entry for '\(documentTitle)'")
                return
            }
        } else {
            // Document not locked, proceed with opening
            print("🔐🔐🔐 DOCUMENT LOCK TEST: Document '\(documentTitle)' is NOT locked, opening directly")
            createAndShowWindow(document)
        }
    }
    
    private static func createAndShowWindow(_ document: NSManagedObject) {
        // Create a window controller
        let delegate = DocumentWindowDelegate()
        
        // Create the window with a larger size
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.delegate = delegate
        
        // Set title based on document title
        window.title = document.value(forKey: "title") as? String ?? "Untitled Document"
        
        // Create the SwiftUI view for the document
        let documentView = DocumentViewerWindow(document: document)
        
        // Set the window content view
        window.contentView = NSHostingView(rootView: documentView)
        
        // Add the window to the tracking array
        documentWindows.append(window)
        print("✅ Added window to tracking array, now tracking \(documentWindows.count) windows")
        
        // Save a reference to the delegate to prevent it from being deallocated
        objc_setAssociatedObject(window, &delegateAssociationKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Set new window as key and front
        window.makeKeyAndOrderFront(nil)
        
        // Maximize the window on main thread after it's displayed
        DispatchQueue.main.async {
            window.zoom(nil)
        }
        
        // Notify that document was opened successfully
        if let documentId = document.value(forKey: "id") as? UUID {
            NotificationCenter.default.post(
                name: NSNotification.Name("DocumentOpened"),
                object: nil,
                userInfo: ["documentId": documentId]
            )
        }
    }
}

// Improved double-click modifier with better error handling
struct DocumentDoubleClickModifier: ViewModifier {
    let document: NSManagedObject
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var passwordError = false
    
    private var documentId: String {
        if let uuid = document.value(forKey: "id") as? UUID {
            return uuid.uuidString
        }
        return "unknown"
    }
    
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle()) // Ensure entire area is clickable
            .onTapGesture(count: 2) {
                print("🖱️ Double-click detected on document \(documentId)")
                handleDocumentOpen()
            }
            .contextMenu {
                Button(action: handleDocumentOpen) {
                    Label("Open Document", systemImage: "doc.text.magnifyingglass")
                }
            }
            .alert("Enter Password", isPresented: $showPasswordPrompt) {
                SecureField("Password", text: $passwordInput)
                    .textContentType(.password)
                
                Button("Cancel", role: .cancel) {
                    passwordInput = ""
                    passwordError = false
                }
                
                Button("Unlock") {
                    verifyPasswordAndOpen()
                }
            } message: {
                VStack {
                    Text("This document is locked. Please enter the password to view it.")
                    
                    if passwordError {
                        Text("Incorrect password. Please try again.")
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                }
            }
    }
    
    private func handleDocumentOpen() {
        guard let docId = document.value(forKey: "id") as? UUID else {
            print("❌ Cannot open document: Missing document ID")
            return
        }
        
        // Check if document is locked using direct call to DocumentLockManager
        let isLocked = DocumentLockManager.shared.isDocumentLocked(docId)
        print("🔑 Checking if document is locked: \(docId) - isLocked: \(isLocked)")
        
        if isLocked {
            print("🔒 Document is locked, showing password prompt")
            showPasswordPrompt = true
        } else {
            // If not locked, open directly
            print("🔓 Document is not locked, opening directly")
            openDocument()
        }
    }
    
    private func verifyPasswordAndOpen() {
        guard let docId = document.value(forKey: "id") as? UUID else {
            passwordInput = ""
            return
        }
        
        let isPasswordValid = DocumentLockManager.shared.verifyDocumentLockPassword(passwordInput, for: docId)
        print("🔑 Password verification result: \(isPasswordValid) for document: \(docId)")
        
        if isPasswordValid {
            // Password correct, open document
            passwordInput = ""
            passwordError = false
            
            // Temporarily access the document without unlocking it in the system
            print("🔓 Password verified for temporary access, document remains locked in the system")
            
            // Open the document without unlocking it
            openDocument()
            
            // Notify about the temporary access
            NotificationCenter.default.post(
                name: NSNotification.Name("TemporaryDocumentAccess"),
                object: nil,
                userInfo: ["documentId": docId]
            )
        } else {
            // Password incorrect, show error and keep dialog open
            passwordError = true
            showPasswordPrompt = true
        }
    }
    
    private func openDocument() {
        // Debug log to check if this function is called
        print("📄 DocumentDoubleClickModifier.openDocument() called for ID: \(documentId)")
        
        // Ensure we're using the main thread
        DispatchQueue.main.async {
            // Call static method directly
            DocumentViewerWindow.openDocument(document)
        }
    }
}

extension View {
    func onDocumentDoubleClick(document: NSManagedObject) -> some View {
        self.modifier(DocumentDoubleClickModifier(document: document))
    }
}

extension NSObject {
    var getThumbnailImage: (() -> Any?)? {
        let selector = NSSelectorFromString("getThumbnailImage")
        guard responds(to: selector) else { return nil }
        
        let method = method(for: selector)
        typealias MethodType = @convention(c) (NSObject, Selector) -> Any?
        let implementation = unsafeBitCast(method, to: MethodType.self)
        
        return { implementation(self, selector) }
    }
}

// New struct for document metadata editing
struct DocumentMetadataSheet: View {
    let document: NSManagedObject
    @Binding var hasChanges: Bool
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    
    // State variables for editable fields
    @State private var title: String = ""
    @State private var category: String = ""
    @State private var comments: String = ""
    @State private var folderName: String = "Unassigned Document" // Changed from "Unfiled"
    @State private var selectedFolderId: UUID?
    @State private var allFolders: [FolderItem] = []
    @State private var showingNewFolderAlert = false
    @State private var newFolderName: String = ""
    
    @State private var tagArray: [String] = [] // New array to manage individual tags
    @State private var newTag: String = "" // For adding new tags
    
    // Add focus state
    @FocusState private var metadataSheetCommentsFocused: Bool
    
    // Add these new state variables
    @State private var showSaveConfirmation = false
    @State private var isSaving = false
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Document Information")) {
                    TextField("Title", text: $title)
                    
                    // Replace folder display with folder picker
                    VStack(alignment: .leading) {
                        Text("Folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        CustomFolderPopup(
                            selectedFolderId: $selectedFolderId,
                            folderName: $folderName,
                            hasChanges: $hasChanges,
                            folders: allFolders,
                            showNewFolderAlert: { showingNewFolderAlert = true }
                        )
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $comments)
                        .frame(minHeight: 100, idealHeight: 100, maxHeight: 100)
                        .focused($metadataSheetCommentsFocused)
                }
                
                if let createdAt = document.value(forKey: "createdAt") as? Date {
                    Section(header: Text("System Information")) {
                        Text("Scanned: \(createdAt.formatted())")
                            .foregroundColor(.secondary)
                        
                        if let documentId = document.value(forKey: "id") as? UUID {
                            Text("UUID: \(documentId.uuidString)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    isSaving = true
                    saveChanges()
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else if showSaveConfirmation {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        
                        Text(showSaveConfirmation ? "Saved!" : "Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || isSaving || showSaveConfirmation)
                .opacity(hasChanges && !showSaveConfirmation && !isSaving ? 1.0 : 0.6)
            }
            .padding()
        }
        .onAppear {
            loadDocumentData()
            loadFolderInfo()
            fetchAllFolders()
            
            // Explicitly reset the change state on load
            DispatchQueue.main.async {
                hasChanges = false
            }
            
            // Debug print to verify initial state
            print("Initial hasChanges state: \(hasChanges)")
        }
        .alert("Create New Folder", isPresented: $showingNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                createNewFolder()
            }
        } message: {
            Text("Enter a name for the new folder")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            // Save confirmation overlay with animation
            ZStack {
                if showSaveConfirmation {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title)
                            
                            VStack(alignment: .leading) {
                                Text("Changes Saved!")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if selectedFolderId != nil {
                                    Text("Document moved to: \(folderName)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.windowBackgroundColor))
                                .shadow(radius: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green, lineWidth: 2)
                        )
                    }
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        // Ensure this overlay persists long enough to be noticed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showSaveConfirmation = false
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSaveConfirmation)
        )
    }
    
    private func loadDocumentData() {
        // Basic properties
        title = document.value(forKey: "title") as? String ?? ""
        
        // Only attempt to get category if the property exists
        if document.entity.propertiesByName["category"] != nil {
            category = document.value(forKey: "category") as? String ?? ""
        } else {
            category = "" // Default value if property doesn't exist
        }
        
        // Enhanced tag parsing with debug output
        print("📌 Loading tags for document: \((document.value(forKey: "id") as? UUID)?.uuidString ?? "unknown")")
        
        // First check if tags is a relationship
        if let tagsSet = document.value(forKey: "tags") as? NSSet {
            print("📌 Found tags relationship with \(tagsSet.count) items")
            
            // Convert Tag entities to strings
            tagArray = tagsSet.compactMap { tagObject in
                guard let tag = tagObject as? NSManagedObject else { return nil }
                let tagName = tag.value(forKey: "name") as? String
                print("📌 Found tag: \(tagName ?? "unnamed")")
                return tagName
            }
            
            print("📌 Loaded \(tagArray.count) tags from relationship: \(tagArray.joined(separator: ", "))")
        } else if let tagsString = document.value(forKey: "tags") as? String {
            // Handle tags as a string
            print("📌 Found tags string: \"\(tagsString)\"")
            
            tagArray = !tagsString.isEmpty ? 
                tagsString.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } : 
                []
            
            print("📌 Parsed \(tagArray.count) tags from string: \(tagArray.joined(separator: ", "))")
        } else {
            print("📌 No tags found or unable to parse tags")
            tagArray = []
        }
        
        // Get comments - always check 'comments' field first
        if hasProperty("comments") {
            comments = document.value(forKey: "comments") as? String ?? ""
        } else if hasProperty("notes") {
            // Fallback to notes if comments doesn't exist
            comments = document.value(forKey: "notes") as? String ?? ""
        } else {
            comments = ""
        }
        
        // Get folder ID
        if let folderId = document.value(forKey: "folderId") as? UUID {
            selectedFolderId = folderId
        } else {
            selectedFolderId = nil
            folderName = "Unassigned Document"
        }
    }
    
    private func saveChanges() {
        // Start saving indicator
        isSaving = true
        
        // Use shared save function
        document.saveDocumentChanges(
            title: title,
            notes: comments, // Pass comments to the save method
            category: hasProperty("category") ? category : nil,
            selectedFolderId: selectedFolderId,
            tagArray: tagArray
        ) { success in
            // Update UI state based on result
            withAnimation {
                self.showSaveConfirmation = success
                self.isSaving = false
                self.hasChanges = false
            }
            
            // Auto-hide the confirmation and dismiss sheet after delay
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.showSaveConfirmation = false
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // Function to add a new tag
    private func addNewTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tagArray.contains(trimmedTag) {
            tagArray.append(trimmedTag)
            newTag = ""
            hasChanges = true
        }
    }
    
    // Renamed from loadFolderName to loadFolderInfo
    private func loadFolderInfo() {
        // Default to "Unassigned Document" if anything goes wrong
        folderName = "Unassigned Document" // Changed from "Unfiled"
        
        // Check if folderId exists
        guard let folderId = document.value(forKey: "folderId") as? UUID else {
            print("📁 No folderId found for document")
            return
        }
        
        selectedFolderId = folderId
        
        // Make sure we have a valid managed object context
        guard let context = document.managedObjectContext else {
            print("❌ No managedObjectContext available for the document")
            return
        }
        
        // Use the document's context instead of viewContext
        print("📁 Attempting to fetch folder with ID: \(folderId)")
        
        // Create safer fetch request
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
        fetchRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let folder = results.first, let name = folder.value(forKey: "name") as? String {
                folderName = name
                print("✅ Found folder: \(name)")
            } else {
                print("⚠️ Folder with ID \(folderId) not found")
            }
        } catch {
            print("❌ Error fetching folder: \(error.localizedDescription)")
        }
    }
    
    // New method to fetch all folders
    private func fetchAllFolders() {
        allFolders = document.fetchAllFolders()
        print("📁 Fetched \(allFolders.count) folders")
    }
    
    // New method to create a folder
    private func createNewFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let context = document.managedObjectContext else {
            return
        }
        
        // Create a new Folder entity
        let entityDescription = NSEntityDescription.entity(forEntityName: "Folder", in: context)
        guard let entityDescription = entityDescription else {
            print("❌ Couldn't get entity description for Folder")
            return
        }
        
        let newFolder = NSManagedObject(entity: entityDescription, insertInto: context)
        let folderId = UUID()
        
        newFolder.setValue(folderId, forKey: "id")
        newFolder.setValue(newFolderName, forKey: "name")
        newFolder.setValue(Date(), forKey: "createdAt")
        
        do {
            try context.save()
            print("✅ Created new folder: \(newFolderName)")
            
            // Update local state
            selectedFolderId = folderId
            folderName = newFolderName
            
            // Add to folders list
            allFolders.append(FolderItem(id: folderId, name: newFolderName))
            allFolders.sort { $0.name < $1.name }
            
            // Mark document as changed
            hasChanges = true
            
            // Reset new folder name
            newFolderName = ""
        } catch {
            print("❌ Failed to create folder: \(error.localizedDescription)")
        }
    }
    
    // Add this method within the DocumentMetadataSheet struct
    private func hasProperty(_ name: String) -> Bool {
        return document.entity.propertiesByName[name] != nil
    }
}

// Helper struct for folder items
struct FolderItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// Add this NSViewRepresentable for an NSPopUpButton without the left chevron
struct CustomFolderPopup: NSViewRepresentable {
    @Binding var selectedFolderId: UUID?
    @Binding var folderName: String
    @Binding var hasChanges: Bool
    let folders: [FolderItem]
    let showNewFolderAlert: () -> Void
    
    func makeNSView(context: Context) -> NSPopUpButton {
        let popupButton = NSPopUpButton(frame: .zero, pullsDown: false)
        popupButton.target = context.coordinator
        popupButton.action = #selector(Coordinator.selectionChanged(_:))
        
        // Configure appearance
        popupButton.bezelStyle = .rounded
        popupButton.contentTintColor = NSColor.labelColor
        
        return popupButton
    }
    
    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        // Preserve selection during updates
        let currentFolderId = selectedFolderId
        
        // Clear and rebuild the menu
        nsView.removeAllItems()
        
        // Add unassigned option
        nsView.addItem(withTitle: "Unassigned Document")
        nsView.menu?.items[0].representedObject = nil
        
        nsView.menu?.addItem(NSMenuItem.separator())
        
        // Add folder options
        for folder in folders {
            nsView.addItem(withTitle: folder.name)
            nsView.lastItem?.representedObject = folder.id
        }
        
        nsView.menu?.addItem(NSMenuItem.separator())
        
        // Add "Create New Folder" option
        let newFolderItem = NSMenuItem(title: "Create New Folder", action: #selector(Coordinator.createNewFolder(_:)), keyEquivalent: "")
        newFolderItem.target = context.coordinator
        let folderImage = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        newFolderItem.image = folderImage
        nsView.menu?.addItem(newFolderItem)
        
        // Select the current folder
        if let currentFolderId = currentFolderId {
            for (index, item) in (nsView.menu?.items ?? []).enumerated() {
                if let itemId = item.representedObject as? UUID, itemId == currentFolderId {
                    nsView.selectItem(at: index)
                    break
                }
            }
        } else {
            // Select "Unassigned Document"
            nsView.selectItem(at: 0)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CustomFolderPopup
        
        init(_ parent: CustomFolderPopup) {
            self.parent = parent
        }
        
        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if let item = sender.selectedItem {
                if let folderId = item.representedObject as? UUID {
                    parent.selectedFolderId = folderId
                    parent.folderName = item.title
                } else if sender.indexOfSelectedItem == 0 {
                    parent.selectedFolderId = nil
                    parent.folderName = "Unassigned Document"
                }
                parent.hasChanges = true
            }
        }
        
        @objc func createNewFolder(_ sender: Any) {
            parent.showNewFolderAlert()
        }
    }
}

// Create a utility extension for document operations
extension NSManagedObject {
    // Updated to safely check if property exists first
    func getValue<T>(forKey key: String, defaultValue: T) -> T {
        // First check if the property exists
        if !self.entity.propertiesByName.keys.contains(key) {
            print("⚠️ Property '\(key)' doesn't exist on entity \(self.entity.name ?? "Unknown")")
            return defaultValue
        }
        
        // Then try to get and cast the value
        return self.value(forKey: key) as? T ?? defaultValue
    }
    
    // Get folder name from ID
    func getFolderName(forId folderId: UUID?) -> String {
        guard let folderId = folderId,
              let context = self.managedObjectContext else {
            return "Unassigned Document"
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
        fetchRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            if let folder = try context.fetch(fetchRequest).first,
               let name = folder.value(forKey: "name") as? String {
                return name
            }
        } catch {
            print("Error fetching folder: \(error)")
        }
        
        return "Unassigned Document"
    }
    
    // Fetch all available folders
    func fetchAllFolders() -> [FolderItem] {
        guard let context = self.managedObjectContext else {
            return []
        }
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let folders = try context.fetch(fetchRequest)
            return folders.compactMap { folder in
                if let id = folder.value(forKey: "id") as? UUID,
                   let name = folder.value(forKey: "name") as? String {
                    return FolderItem(id: id, name: name)
                }
                return nil
            }
        } catch {
            print("Error fetching folders: \(error)")
            return []
        }
    }
    
    // Check if entity has a specific property
    func hasProperty(_ name: String) -> Bool {
        return entity.propertiesByName[name] != nil
    }
    
    // Parse tags string into array
    func parseTagsArray(from tagsString: String?) -> [String] {
        guard let tagsString = tagsString, !tagsString.isEmpty else {
            return []
        }
        
        return tagsString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // Helper to open a document in a window - rename this to avoid any potential conflicts
    static func openDocumentInViewer(for document: NSManagedObject) {
        guard let docId = document.value(forKey: "id") as? UUID else {
            print("❌ Cannot open document: Missing document ID")
            return
        }
        
        print("📄 Opening document with ID: \(docId.uuidString)")
        
        // Clean up closed windows
        DocumentViewerWindow.windowControllers = DocumentViewerWindow.windowControllers.filter { 
            $0.window?.isVisible == true 
        }
        
        // Check if already open
        if let existingController = DocumentViewerWindow.windowControllers.first(where: { controller in
            guard let hostingController = controller.window?.contentViewController as? NSHostingController<DocumentViewerWindow>,
                  let viewDocId = hostingController.rootView.document.value(forKey: "id") as? UUID else {
                return false
            }
            return viewDocId == docId
        }) {
            existingController.window?.makeKeyAndOrderFront(nil)
            existingController.window?.orderFrontRegardless()
            return
        }
        
        // Create new window
        let controller = DocumentWindowController()
        let documentViewer = DocumentViewerWindow(document: document)
        
        DocumentViewerWindow.windowControllers.append(controller)
        controller.showWindow(with: documentViewer, title: document.value(forKey: "title") as? String ?? "Untitled Document")
    }
    
    // Add this missing method - needs to be in the same extension as the other utility methods
    func saveDocumentChanges(
        title: String,
        notes: String,
        category: String?,
        selectedFolderId: UUID?,
        tagArray: [String],
        completionHandler: @escaping (Bool) -> Void
    ) {
        print("💾 SAVE START - Saving document with \(tagArray.count) tags")
        
        do {
            guard let context = self.managedObjectContext else {
                throw NSError(domain: "DocumentSaving", code: 1, 
                             userInfo: [NSLocalizedDescriptionKey: "No context available"])
            }
            
            // Save basic properties
            self.setValue(title, forKey: "title")
            
            // Category if available
            if self.hasProperty("category") && category != nil {
                self.setValue(category, forKey: "category")
            }
            
            // Save comments field (checking both property names)
            if self.hasProperty("comments") {
                self.setValue(notes, forKey: "comments")
            } else if self.hasProperty("notes") {
                self.setValue(notes, forKey: "notes")
            }
            
            // Folder ID
            if let currentFolderId = self.value(forKey: "folderId") as? UUID {
                print("📂 Changing folder from \(currentFolderId) to \(selectedFolderId?.uuidString ?? "nil")")
            }
            self.setValue(selectedFolderId, forKey: "folderId")
            
            // Timestamp
            self.setValue(Date(), forKey: "updatedAt")
            
            // Handle tags - check if using Tag entities or string
            if self.entity.relationshipsByName["tags"] != nil {
                print("📌 Using relationship-based tags")
                
                // Clear existing tags - fix the conditional binding error
                let existingTags = self.mutableSetValue(forKey: "tags")
                existingTags.removeAllObjects()
                
                // Create new Tag entities
                for tagName in tagArray {
                    // Find or create Tag entity
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Tag")
                    fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
                    
                    let existingTags = try context.fetch(fetchRequest)
                    let tagEntity: NSManagedObject
                    
                    if let existingTag = existingTags.first {
                        print("📌 Using existing tag: \(tagName)")
                        tagEntity = existingTag
                    } else {
                        print("📌 Creating new tag: \(tagName)")
                        tagEntity = NSEntityDescription.insertNewObject(
                            forEntityName: "Tag",
                            into: context
                        )
                        tagEntity.setValue(tagName, forKey: "name")
                        tagEntity.setValue(UUID(), forKey: "id")
                    }
                    
                    // Add to relationship
                    self.mutableSetValue(forKey: "tags").add(tagEntity)
                }
            } else {
                // Using string-based tags
                print("📌 Using string-based tags")
                let tagsString = tagArray.joined(separator: ", ")
                self.setValue(tagsString, forKey: "tags")
            }
            
            // Save changes
            print("📝 Saving context")
            try context.save()
            
            // Save parent context if it exists
            if let parentContext = context.parent {
                print("📝 Saving parent context")
                try parentContext.save()
            }
            
            print("✅ Save successful!")
            
            // Notify caller of success
            completionHandler(true)
            
            // Post notification about the update
            if let docId = self.value(forKey: "id") as? UUID {
                NotificationCenter.default.postDocumentUpdated(
                    documentId: docId,
                    folderChanged: true,
                    newFolderId: selectedFolderId
                )
                
                print("📢 Posted DocumentUpdated notification with folder: \(selectedFolderId?.uuidString ?? "unassigned")")
            }
            
        } catch {
            print("❌ Failed to save: \(error.localizedDescription)")
            print("Detailed error: \(error)")
            
            // Notify caller of failure
            completionHandler(false)
        }
    }
}

// Create an extension to standardize notification names
extension Notification.Name {
    static let documentUpdated = Notification.Name("DocumentUpdated")
    static let goToPage = Notification.Name("GoToPage")
    static let updateZoom = Notification.Name("UpdateZoom")
}

// Create a utility for posting document notifications
extension NotificationCenter {
    func postDocumentUpdated(documentId: UUID, folderChanged: Bool = false, newFolderId: UUID? = nil) {
        post(
            name: .documentUpdated,
            object: nil,
            userInfo: [
                "documentId": documentId,
                "folderChanged": folderChanged,
                "newFolderId": newFolderId as Any,
                "timestamp": Date()
            ]
        )
    }
}

// Create a zoomable image view similar to iOS experience
struct ZoomableImageView: NSViewRepresentable {
    let image: NSImage
    
    func makeNSView(context: Context) -> NSScrollView {
        print("📊 Creating ZoomableImageView with image: \(image.size.width) x \(image.size.height)")
        
        // Create and configure a scroll view with clean, iOS-like settings
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        
        // Create the image view with iOS-like configuration
        let imageView = NSImageView()
        imageView.image = image
        
        // Critical: Don't apply ANY scaling or resizing to the image
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        
        // Set the image view's frame to EXACTLY match the image's natural size
        let imageSize = image.size
        imageView.frame = NSRect(origin: .zero, size: imageSize)
        
        // Configure the scroll view with the image as its document
        scrollView.documentView = imageView
        
        // Add zoom support like iOS Photos app
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 4.0
        
        // Set initial state after layout
        DispatchQueue.main.async {
            // Start with a true "fit to view" magnification
            let viewSize = scrollView.contentSize
            
            // Calculate the scaling that would display the whole image
            let widthRatio = viewSize.width / imageSize.width
            let heightRatio = viewSize.height / imageSize.height
            
            // Use the smaller ratio to ensure the entire image fits without distortion
            let fitScale = min(widthRatio, heightRatio)
            
            // Never upscale small images beyond their natural size
            if imageSize.width < viewSize.width && imageSize.height < viewSize.height {
                scrollView.magnification = 1.0
            } else {
                scrollView.magnification = fitScale * 0.95 // Slight margin
            }
            
            // Center the image in the view (critical for iOS-like behavior)
            self.centerImage(in: scrollView)
        }
        
        // Add double-click handler to toggle between 1:1 and fit
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        clickGesture.numberOfClicksRequired = 2
        imageView.addGestureRecognizer(clickGesture)
        
        // Store a reference to the scrollView
        context.coordinator.scrollView = scrollView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let imageView = nsView.documentView as? NSImageView else { return }
        
        // Only update if the image changed
        if imageView.image != image {
            imageView.image = image
            
            // Reconfigure with iOS-like settings
            imageView.imageScaling = .scaleNone
            imageView.imageAlignment = .alignCenter
            
            // IMPORTANT: Reset frame to exact image dimensions
            let imageSize = image.size
            imageView.frame = NSRect(origin: .zero, size: imageSize)
            
            // Reset zoom to fit view
            DispatchQueue.main.async {
                let viewSize = nsView.contentSize
                
                // Calculate proper fit scale
                let widthRatio = viewSize.width / imageSize.width
                let heightRatio = viewSize.height / imageSize.height
                let fitScale = min(widthRatio, heightRatio)
                
                // Never upscale small images
                if imageSize.width < viewSize.width && imageSize.height < viewSize.height {
                    nsView.magnification = 1.0
                } else {
                    nsView.magnification = fitScale * 0.95 // Slight margin
                }
                
                // iOS always centers images
                self.centerImage(in: nsView)
            }
        }
    }
    
    // iOS-style image centering logic
    private func centerImage(in scrollView: NSScrollView) {
        guard let imageView = scrollView.documentView as? NSImageView,
              let image = imageView.image else { return }
        
        let imageSize = image.size
        let visibleRect = scrollView.documentVisibleRect
        let scaledSize = CGSize(
            width: imageSize.width * scrollView.magnification,
            height: imageSize.height * scrollView.magnification
        )
        
        // Center horizontally
        var newOrigin = NSPoint.zero
        if scaledSize.width < visibleRect.width {
            newOrigin.x = (visibleRect.width - scaledSize.width) / 2
        }
        
        // Center vertically
        if scaledSize.height < visibleRect.height {
            newOrigin.y = (visibleRect.height - scaledSize.height) / 2
        }
        
        // Apply centering
        scrollView.contentView.scroll(to: newOrigin)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var scrollView: NSScrollView?
        
        @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scrollView = scrollView,
                  let imageView = scrollView.documentView as? NSImageView,
                  let image = imageView.image else { return }
            
            // Get click location for smart zoom
            let clickLocation = gesture.location(in: imageView)
            
            // iOS Photos-style toggle between fit and 1:1
            if abs(scrollView.magnification - 1.0) < 0.1 {
                // Currently at 1:1, switch to fit
                let viewSize = scrollView.contentSize
                let imageSize = image.size
                let widthRatio = viewSize.width / imageSize.width
                let heightRatio = viewSize.height / imageSize.height
                let fitScale = min(widthRatio, heightRatio) * 0.95
                
                // Animate zoom
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    scrollView.animator().magnification = fitScale
                    centerImage(in: scrollView)
                }
            } else {
                // Currently at some other zoom, switch to 1:1
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    scrollView.animator().magnification = 1.0
                    
                    // Scroll to center on clicked point (iOS behavior)
                    if let clipView = scrollView.contentView as? NSClipView {
                        let centeredPoint = NSPoint(
                            x: clickLocation.x - clipView.bounds.width/2,
                            y: clickLocation.y - clipView.bounds.height/2
                        )
                        clipView.animator().scroll(to: centeredPoint)
                    }
                }
            }
        }
        
        // Helper to center the image - reused from parent
        private func centerImage(in scrollView: NSScrollView) {
            guard let imageView = scrollView.documentView as? NSImageView,
                  let image = imageView.image else { return }
            
            let imageSize = image.size
            let visibleRect = scrollView.documentVisibleRect
            let scaledSize = CGSize(
                width: imageSize.width * scrollView.magnification,
                height: imageSize.height * scrollView.magnification
            )
            
            // Center horizontally
            var newOrigin = NSPoint.zero
            if scaledSize.width < visibleRect.width {
                newOrigin.x = (visibleRect.width - scaledSize.width) / 2
            }
            
            // Center vertically
            if scaledSize.height < visibleRect.height {
                newOrigin.y = (visibleRect.height - scaledSize.height) / 2
            }
            
            // Apply centering
            scrollView.contentView.scroll(to: newOrigin)
        }
    }
}

// Create a utility extension for PDFDocument
extension PDFDocument {
    // Helper function to detect scanned/image-based PDFs
    func isScannedPDF() -> Bool {
        // Always check the document attributes first
        if let attributes = self.documentAttributes {
            // Check creator application - if it's a scanner software
            if let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String {
                let scannerApps = ["Scanner", "scan", "NAPS2", "Adobe Scan", "CamScanner", 
                                  "Scanbot", "SwiftScan", "ScanPro", "Office Lens"]
                
                for app in scannerApps {
                    if creator.contains(app) {
                        return true
                    }
                }
            }
            
            // Check PDF producer - if it contains scanner info
            if let producer = attributes[PDFDocumentAttribute.producerAttribute] as? String {
                if producer.contains("Scanner") || producer.contains("scan") {
                    return true
                }
            }
        }
        
        // Check first 3 pages (or fewer if document has fewer pages)
        let pagesToCheck = min(3, self.pageCount)
        var totalTextCharacters = 0
        var hasVectorGraphics = false
        
        for i in 0..<pagesToCheck {
            guard let page = self.page(at: i) else { continue }
            
            // Method 1: Check annotations (vector PDFs often have them)
            let annotations = page.annotations
            if !annotations.isEmpty {
                for annotation in annotations {
                    // Exclude common scanner annotations
                    if annotation.type != "Link" && annotation.type != "Highlight" {
                        return false // Has non-link annotations, likely a vector PDF
                    }
                }
            }
            
            // Method 2: Check if the page contains selectable text
            if let pageContent = page.string {
                totalTextCharacters += pageContent.count
                
                // Check for characteristics of OCR text
                if !pageContent.isEmpty && pageContent.count > 200 {
                    let words = pageContent.components(separatedBy: .whitespacesAndNewlines)
                    
                    // OCR text often has abnormal spacing and special characters
                    if words.count > 50 {
                        let specialCharCount = pageContent.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count
                        let specialCharRatio = Double(specialCharCount) / Double(pageContent.count)
                        
                        // Low special char ratio suggests well-formatted text (likely vector PDF)
                        if specialCharRatio < 0.05 {
                            hasVectorGraphics = true
                        }
                    }
                }
            }
            
            // Method 3: Check for images in the page
            if hasLargeImage(page) {
                return true // If the page is dominated by an image, it's likely scanned
            }
        }
        
        // Method 4: If it has substantial proper text content and no large images, it's likely a vector PDF
        if totalTextCharacters > 300 && hasVectorGraphics {
            return false
        }
        
        // If we're in doubt, check if the document looks like a recipe or has "recipe" in title
        if let title = self.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String {
            if title.lowercased().contains("recipe") || 
               title.lowercased().contains("food") || 
               title.lowercased().contains("dish") {
                return true // Recipes are commonly scanned
            }
        }
        
        // If we get here with little text, it's likely a scanned/image-based PDF
        return totalTextCharacters < 100
    }
    
    // Helper to check if a page is dominated by an image
    private func hasLargeImage(_ page: PDFPage) -> Bool {
        let pageRect = page.bounds(for: .mediaBox)
        
        // Create a PDF context to analyze the page content
        let pageWidth = pageRect.width
        let pageHeight = pageRect.height
        let pageArea = pageWidth * pageHeight
        
        // Try to render to analyze bitmap coverage
        let thumbnail = page.thumbnail(of: CGSize(width: 300, height: 300), for: .mediaBox)
        
        // Check if image takes up significant area of the page
        if let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let imageRep = NSBitmapImageRep(cgImage: cgImage)
            
            // Count non-white pixels
            var nonWhitePixels = 0
            let totalPixels = imageRep.pixelsWide * imageRep.pixelsHigh
            
            for x in 0..<imageRep.pixelsWide {
                for y in 0..<imageRep.pixelsHigh {
                    if let color = imageRep.colorAt(x: x, y: y) {
                        // If pixel is not close to white
                        if color.brightnessComponent < 0.9 {
                            nonWhitePixels += 1
                        }
                    }
                }
            }
            
            // If more than 15% of pixels are non-white, likely an image-heavy document
            let nonWhiteRatio = Double(nonWhitePixels) / Double(totalPixels)
            if nonWhiteRatio > 0.15 {
                return true
            }
        }
        
        return false
    }
} 

// New simpler image viewer using pure SwiftUI (no NSViewRepresentable)
struct BasicImageViewer: View {
    let image: NSImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyState: CGFloat = 1.0
    @State private var showControls: Bool = true
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.windowBackgroundColor).brightness(0.02)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    if showControls {
                        HStack {
                            Text("Image: \(Int(image.size.width)) × \(Int(image.size.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                resetZoom(frameSize: geo.size)
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {
                                scale = min(scale * 1.25, 4.0)
                                lastScale = scale
                            }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {
                                scale = max(scale * 0.8, 0.1)
                                lastScale = scale
                            }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
                    
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .updating($magnifyState) { value, state, _ in
                                    state = value
                                }
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = min(max(newScale, 0.1), 4.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if abs(scale - 1.0) < 0.1 {
                                    // Currently at original size, fit to view
                                    resetZoom(frameSize: geo.size)
                                } else {
                                    // Reset to 1:1
                                    scale = 1.0
                                    offset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                }
                            }
                        }
                        .onTapGesture(count: 1) {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                }
                .onAppear {
                    // Fit to view on initial appearance
                    resetZoom(frameSize: geo.size)
                }
            }
        }
    }
    
    private func resetZoom(frameSize: CGSize) {
        let imageSize = image.size
        let widthRatio = frameSize.width / imageSize.width
        let heightRatio = frameSize.height / imageSize.height
        
        // Use the smaller ratio to ensure the entire image fits
        if imageSize.width < frameSize.width && imageSize.height < frameSize.height {
            // Small image - show at actual size
            scale = 1.0
        } else {
            // Large image - fit to view
            scale = min(widthRatio, heightRatio) * 0.9
        }
        
        // Reset position
        offset = .zero
        lastScale = scale
        lastOffset = .zero
    }
}

// Add this outside any existing struct/class
private var delegateAssociationKey: UInt8 = 0

// Add this class outside of any other struct/class
class DocumentWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: NSNotification) {
        // Clean up when window closes
        guard let window = notification.object as? NSWindow else { return }
        
        print("🚪 Document window will close")
        
        // Use DispatchQueue.main.async to prevent potential race conditions
        DispatchQueue.main.async {
            // Remove the window from our tracking array
            if let index = documentWindows.firstIndex(of: window) {
                documentWindows.remove(at: index)
                print("🚪 Removed window from tracking array, remaining: \(documentWindows.count)")
            }
            
            // Break potential retain cycles
            objc_setAssociatedObject(window, &delegateAssociationKey, nil, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
}

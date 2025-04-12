import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Security

// Add this property at the top of the file, outside any class or struct
// We need a strong reference to document windows to prevent deallocation issues
var documentWindows: [NSWindow] = []

struct FoldersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: NSEntityDescription.entity(forEntityName: "Folder", in: PersistenceController.shared.container.viewContext)!,
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) private var folders: FetchedResults<NSManagedObject>
    
    // Add the UI lock check throttling as regular @State properties
    @State private var lastUILockCheckTime: [UUID: Date] = [:]
    private let uiLockCheckThrottleInterval: TimeInterval = 3.0 // seconds
    
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    @State private var selectedFolder: NSManagedObject?
    @State private var navigateToFolder: NSManagedObject?
    @State private var showAsGrid = true // Default to grid/thumbnail view
    @State private var navigateToUnassigned = true // Auto-navigate to unassigned
    @State private var targetedFolder: NSManagedObject? = nil
    @State private var targetedUnassigned: Bool = false
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var refreshCounter = 0
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("ScanVault AI Folders:")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            if folders.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("No Folders")
                        .font(.title)
                    
                    Text("Create folders to organize your documents")
                        .foregroundColor(.secondary)
                    
                    Button("Create Folder") {
                        showingAddFolder = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    List(selection: $selectedFolder) {
                        // Add special "Unassigned Documents" folder at the TOP
                        NavigationLink(
                            destination: UnassignedDocumentsView(showAsGrid: showAsGrid),
                            isActive: $navigateToUnassigned
                        ) {
                            HStack {
                                Image(systemName: "folder.badge.questionmark")
                                    .foregroundColor(.orange)
                                Text("Unassigned Documents")
                                    .bold() // Make it more prominent
                            }
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            // Handle the drop to unassigned folder
                            handleDropToUnassigned(providers: providers)
                            return true
                        }
                        
                        // Regular folders - no divider
                        ForEach(folders, id: \.self) { folder in
                            NavigationLink(
                                destination: FolderDetailView(
                                    folderName: folder.value(forKey: "name") as? String ?? "Unnamed Folder",
                                    folderId: folder.value(forKey: "id") as? UUID
                                ),
                                tag: folder,
                                selection: $navigateToFolder
                            ) {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.blue)
                                    Text(folder.value(forKey: "name") as? String ?? "Unnamed Folder")
                                }
                                .overlay(
                                    isDragging && targetedFolder == folder ? 
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.blue, lineWidth: 2)
                                            .padding(-2)
                                        : nil
                                )
                            }
                            .tag(folder)
                            .onDrop(of: [.text], isTargeted: .init(get: { false }, set: { targeted in
                                // Update the targeted state when hovering over this folder
                                if targeted {
                                    self.targetedFolder = folder
                                    self.isDragging = true
                                } else if self.targetedFolder == folder {
                                    self.targetedFolder = nil
                                }
                            })) { providers in
                                // Handle the drop
                                handleDrop(providers: providers, targetFolder: folder)
                                self.isDragging = false
                                self.targetedFolder = nil
                                return true
                            }
                            .overlay(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DropPreferenceKey.self,
                                        value: [DropInfo(id: folder.objectID, frame: geo.frame(in: .global))]
                                    )
                                }
                            )
                        }
                        .onDelete(perform: deleteFolder)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            NewFolderView(isPresented: $showingAddFolder, addFolder: addFolder)
        }
        .navigationTitle("Folders")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingAddFolder = true }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                
                Button(action: { showAsGrid = false }) {
                    Label("List View", systemImage: "list.bullet")
                        .foregroundColor(showAsGrid ? .secondary : .accentColor)
                }
                
                Button(action: { showAsGrid = true }) {
                    Label("Grid View", systemImage: "square.grid.2x2")
                        .foregroundColor(showAsGrid ? .accentColor : .secondary)
                }
            }
        }
        .onChange(of: selectedFolder) { _, newValue in
            if let folder = newValue {
                print("Selected folder: \(folder.value(forKey: "name") as? String ?? "Unnamed Folder")")
                navigateToFolder = folder
                navigateToUnassigned = false // Deactivate unassigned navigation when selecting a folder
            }
        }
        .onAppear {
            print("FoldersView appeared with \(folders.count) folders")
            
            // Register for document lock changes notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("DocumentLocksChanged"),
                object: nil,
                queue: .main
            ) { _ in
                // Force a refresh of the view when document locks change
                print("🔁 Refreshing view after document locks changed")
                self.refreshCounter += 1 // Use a refresh counter to force view update
            }
            
            // This ensures the Unassigned Documents view is preselected on app launch
            navigateToUnassigned = true
            navigateToFolder = nil
        }
        .onDisappear {
            // Remove notification observer
            NotificationCenter.default.removeObserver(self)
        }
        .id(refreshCounter) // Force refresh when counter changes
        .onPreferenceChange(DropPreferenceKey.self) { dropInfos in
            // Find if we're hovering over any drop zones
            guard isDragging else { return }
            if let hitTest = dropInfos.first(where: { $0.frame.contains(dragLocation) }) {
                if let folder = folders.first(where: { $0.objectID == hitTest.id }) {
                    self.targetedFolder = folder
                }
            } else {
                self.targetedFolder = nil
            }
        }
        // Add a gesture recognizer to track mouse location during drag
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    self.dragLocation = value.location
                    self.isDragging = true
                }
                .onEnded { _ in
                    self.isDragging = false
                    self.targetedFolder = nil
                    self.targetedUnassigned = false
                }
        )
        .background(
            MouseLocationTracker { location in
                if self.isDragging {
                    self.dragLocation = location
                }
            }
        )
    }
    
    private func deleteFolder(offsets: IndexSet) {
        withAnimation {
            offsets.map { folders[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting folder: \(nsError)")
            }
        }
    }
    
    private func addFolder(name: String) {
        withAnimation {
            let _ = NSManagedObject.createFolder(title: name, context: viewContext)
            try? viewContext.save()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], targetFolder: NSManagedObject) -> Bool {
        // Get the first provider
        guard let provider = providers.first else { 
            print("No provider found")
            return false 
        }
        
        // Check if the provider contains a text item (the document ID)
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, error in
                if let error = error {
                    print("Error loading drag item: \(error)")
                    return
                }
                
                guard let data = data, let idString = String(data: data, encoding: .utf8) else {
                    print("Could not convert data to string")
                    return
                }
                
                print("Successfully decoded document ID string: \(idString)")
                
                guard let documentId = UUID(uuidString: idString) else {
                    print("Invalid UUID string: \(idString)")
                    return
                }
                
                print("Processing document ID: \(documentId.uuidString)")
                
                // Find the document in CoreData
                DispatchQueue.main.async {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
                    
                    do {
                        let results = try self.viewContext.fetch(fetchRequest)
                        print("Found \(results.count) documents matching ID")
                        
                        if let document = results.first {
                            // Get target folder ID
                            guard let targetFolderId = targetFolder.value(forKey: "id") as? UUID else {
                                print("Failed to get target folder ID")
                                return
                            }
                            
                            print("Moving document to folder: \(targetFolderId.uuidString)")
                            
                            // Update the document's folder ID
                            let oldFolderId = document.value(forKey: "folderId") as? UUID
                            print("Old folder ID: \(String(describing: oldFolderId))")
                            
                            document.setValue(targetFolderId, forKey: "folderId")
                            
                            // Save the context
                            do {
                                try self.viewContext.save()
                                print("✅ Document moved successfully")
                                
                                // Force refresh all views
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshDocumentViews"), object: nil)
                                
                                // Additional notification for refreshing
                                self.viewContext.refreshAllObjects()
                            } catch {
                                print("❌ Error saving context: \(error)")
                            }
                        } else {
                            print("⚠️ No document found with ID: \(documentId.uuidString)")
                        }
                    } catch {
                        print("Error fetching document: \(error)")
                    }
                }
            }
            return true
        } else {
            print("Provider doesn't contain plain text")
            return false
        }
    }
    
    private func handleDropToUnassigned(providers: [NSItemProvider]) -> Bool {
        // Get the first provider
        guard let provider = providers.first else { return false }
        
        // Check if the provider contains a text item (the document ID)
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, error in
                if let error = error {
                    print("Error loading drag item: \(error)")
                    return
                }
                
                guard let data = data, let idString = String(data: data, encoding: .utf8) else {
                    print("Could not convert data to string")
                    return
                }
                
                print("Successfully decoded document ID string for unassigned: \(idString)")
                
                guard let documentId = UUID(uuidString: idString) else {
                    print("Invalid UUID string: \(idString)")
                    return
                }
                
                // Find the document in CoreData
                DispatchQueue.main.async {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
                    
                    do {
                        let results = try self.viewContext.fetch(fetchRequest)
                        if let document = results.first {
                            // Set folder ID to nil (unassigned)
                            document.setValue(nil, forKey: "folderId")
                            
                            // Save the context
                            try self.viewContext.save()
                            print("✅ Document moved to unassigned successfully")
                            
                            // Force refresh all views
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshDocumentViews"), object: nil)
                            
                            // Additional notification for refreshing
                            self.viewContext.refreshAllObjects()
                        }
                    } catch {
                        print("Error moving document to unassigned: \(error)")
                    }
                }
            }
            return true
        }
        return false
    }
    
    private func openDocument(_ document: NSManagedObject) {
        print("🔍 Opening document: \(document.value(forKey: "title") as? String ?? "Untitled Document")")
        
        // Make sure the document is valid and still exists in CoreData
        guard !document.isDeleted && document.managedObjectContext != nil else {
            print("⚠️ Cannot open document: Object is deleted or has no context")
            return
        }
        
        // Check if document is locked using direct call to DocumentLockManager
        if let documentId = document.value(forKey: "id") as? UUID {
            // Always do a fresh check with DocumentLockManager
            let isLocked = DocumentLockManager.shared.isDocumentLocked(documentId)
            print("🔒 DOCUMENT OPEN CHECK - ID: \(documentId.uuidString), Locked: \(isLocked)")
            
            if isLocked {
                // Document is definitely locked, show password prompt
                print("🔒 Document is locked, showing password prompt")
                verifyPasswordAndOpenDocument(document)
            } else {
                // Document is not locked, open directly
                print("🔓 Document is not locked, opening directly")
                DocumentViewerWindow.openDocument(document)
            }
        } else {
            print("⚠️ No document ID found")
        }
    }
    
    // Verify password and open document if correct
    private func verifyPasswordAndOpenDocument(_ document: NSManagedObject) {
        guard let docId = document.value(forKey: "id") as? UUID else {
            print("⚠️ No document ID found")
            return
        }
        
        // Double-check that the document is actually locked
        let isLocked = DocumentLockManager.shared.isDocumentLocked(docId)
        if !isLocked {
            print("⚠️ Document was not actually locked, opening directly")
            DocumentViewerWindow.openDocument(document)
            return
        }
        
        // Create a password prompt alert
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
            let isPasswordValid = DocumentLockManager.shared.verifyDocumentLockPassword(password)
            print("🔑 Password verification result: \(isPasswordValid) for document: \(docId)")
            
            if isPasswordValid {
                // Password correct, temporarily unlock the document
                print("✅ Password correct, temporarily unlocking document")
                DocumentLockManager.shared.unlockDocument(docId)
                
                // Open the document now that it's unlocked
                DocumentViewerWindow.openDocument(document)
                
                // Post notification for document locks changed
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentLocksChanged"),
                    object: nil,
                    userInfo: ["documentId": docId]
                )
            } else {
                // Password incorrect, show error
                print("❌ Password incorrect")
                let errorAlert = NSAlert()
                errorAlert.messageText = "Incorrect Password"
                errorAlert.informativeText = "The password you entered is incorrect. Please try again."
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
                
                // Try again
                verifyPasswordAndOpenDocument(document)
            }
        }
    }
    
    // Add the shouldLogUILockCheck method
    private func shouldLogUILockCheck(for documentId: UUID) -> Bool {
        let now = Date()
        if let lastCheck = lastUILockCheckTime[documentId],
           now.timeIntervalSince(lastCheck) < uiLockCheckThrottleInterval {
            return false
        }
        lastUILockCheckTime[documentId] = now
        return true
    }
}

// Add a new view for Unassigned Documents
struct UnassignedDocumentsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest var documents: FetchedResults<NSManagedObject>
    @State private var isShowingDebugInfo = false
    @State private var showPasswordPrompt = false
    @State private var selectedLockedDocument: NSManagedObject? = nil
    @State private var passwordInput = ""
    @State private var passwordError = false
    @ObservedObject private var documentLockManager = DocumentLockManager.shared
    @State private var lastUILockCheckTime: [UUID: Date] = [:]
    private let uiLockCheckThrottleInterval: TimeInterval = 3.0 // seconds
    var showAsGrid: Bool
    
    // Add the shouldLogUILockCheck method
    private func shouldLogUILockCheck(for documentId: UUID) -> Bool {
        let now = Date()
        if let lastCheck = lastUILockCheckTime[documentId],
           now.timeIntervalSince(lastCheck) < uiLockCheckThrottleInterval {
            return false
        }
        lastUILockCheckTime[documentId] = now
        return true
    }
    
    // Helper method to open a document
    private func openDocument(_ document: NSManagedObject) {
        print("🔍 Opening document: \(document.value(forKey: "title") as? String ?? "Untitled Document")")
        
        // Make sure the document is valid and still exists in CoreData
        guard !document.isDeleted && document.managedObjectContext != nil else {
            print("⚠️ Cannot open document: Object is deleted or has no context")
            return
        }
        
        // Check if document is locked using direct call to DocumentLockManager
        if let documentId = document.value(forKey: "id") as? UUID {
            // Always do a fresh check with DocumentLockManager
            let isLocked = DocumentLockManager.shared.isDocumentLocked(documentId)
            print("🔒 DOCUMENT OPEN CHECK - ID: \(documentId.uuidString), Locked: \(isLocked)")
            
            if isLocked {
                // Document is definitely locked, show password prompt
                print("🔒 Document is locked, showing password prompt")
                verifyPasswordAndOpenDocument(document)
            } else {
                // Document is not locked, open directly
                print("🔓 Document is not locked, opening directly")
                DocumentViewerWindow.openDocument(document)
            }
        } else {
            print("⚠️ No document ID found")
        }
    }
    
    // Helper method to create the document cell UI
    @ViewBuilder
    private func documentGridCell(document: NSManagedObject) -> some View {
        // Always do a fresh check for locked status
        let docId = document.value(forKey: "id") as? UUID
        let documentTitle = document.value(forKey: "title") as? String ?? "Untitled Document"
        
        // Debug the document ID only if needed
        if let id = docId, shouldLogUILockCheck(for: id) {
            print("🔐🔐🔐 UI LOCK CHECK: Document '\(documentTitle)' has ID: \(id)")
            
            let isLocked = DocumentLockManager.shared.isDocumentLocked(id)
            print("🔐🔐🔐 UI LOCK CHECK: Document '\(documentTitle)' lock status: \(isLocked)")
        }
        
        // Still get the lock status but without excessive logging
        let isLocked = docId != nil ? DocumentLockManager.shared.isDocumentLocked(docId!) : false
        
        return Button(action: {
            openDocument(document)
        }) {
            VStack {
                // Display document image or placeholder
                Group {
                    if isLocked {
                        // Show lock icon for locked documents
                        ZStack {
                            Image(nsImage: document.getThumbnailImage() ?? NSImage(named: "Placeholder")!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 130)
                            
                            // Show lock overlay for locked documents
                            Color.black.opacity(0.3)
                                .frame(width: 100, height: 130)
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    } else if let thumbnail = document.getThumbnailImage() {
                        // Show document thumbnail
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 130)
                    } else {
                        // Show placeholder
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                            .frame(width: 100, height: 130)
                    }
                }
                
                // Document title
                Text(document.value(forKey: "title") as? String ?? "Untitled Document")
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100, height: 40)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                if let documentId = document.value(forKey: "id") as? UUID {
                    // Toggle document lock state
                    if isLocked {
                        DocumentLockManager.shared.unlockDocument(documentId)
                        print("🔓 Unlocked document: \(documentId)")
                    } else {
                        // Ensure there's a password set
                        if !DocumentLockManager.shared.hasDocumentLock() {
                            DocumentLockManager.shared.saveDocumentLockPassword("test123")
                            print("🔑 Set default document lock password")
                        }
                        
                        DocumentLockManager.shared.lockDocument(documentId)
                        print("🔒 Locked document: \(documentId)")
                    }
                    
                    // Notify others about the lock change - still needed for non-SwiftUI components
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DocumentLocksChanged"),
                        object: nil,
                        userInfo: ["documentId": documentId]
                    )
                }
            }) {
                if isLocked {
                    Label("Unlock Document", systemImage: "lock.open")
                } else {
                    Label("Lock Document", systemImage: "lock")
                }
            }
            
            Button(action: {
                openDocument(document)
            }) {
                Label("Open Document", systemImage: "doc.text.magnifyingglass")
            }
        }
        .onDrag {
            // Allow documents to be dragged between folders
            if let id = document.value(forKey: "id") as? UUID {
                let provider = NSItemProvider(object: id.uuidString as NSString)
                return provider
            }
            return NSItemProvider()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentLocksChanged"))) { notification in
            // The view will refresh automatically through the ObservableObject
            print("🔔 Received DocumentLocksChanged notification")
        }
        .id("\(document.objectID)-\(DocumentLockManager.shared.lockStateChanged)")
    }
    
    // Helper method to show password prompt for locked documents
    private func showPasswordPrompt(for document: NSManagedObject) {
        print("🔒 Showing password prompt for document: \(document.value(forKey: "title") as? String ?? "Untitled Document")")
        self.selectedLockedDocument = document
        self.passwordInput = ""
        self.passwordError = false
        self.showPasswordPrompt = true
    }
    
    // Verify password and open document if correct
    private func verifyPasswordAndOpenDocument(_ document: NSManagedObject) {
        guard let docId = document.value(forKey: "id") as? UUID else {
            print("⚠️ No document ID found")
            return
        }
        
        // Double-check that the document is actually locked
        let isLocked = DocumentLockManager.shared.isDocumentLocked(docId)
        if !isLocked {
            print("⚠️ Document was not actually locked, opening directly")
            DocumentViewerWindow.openDocument(document)
            return
        }
        
        // Create a password prompt alert
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
            let isPasswordValid = DocumentLockManager.shared.verifyDocumentLockPassword(password)
            print("🔑 Password verification result: \(isPasswordValid) for document: \(docId)")
            
            if isPasswordValid {
                // Password correct, temporarily unlock the document
                print("✅ Password correct, temporarily unlocking document")
                DocumentLockManager.shared.unlockDocument(docId)
                
                // Open the document now that it's unlocked
                DocumentViewerWindow.openDocument(document)
                
                // Post notification for document locks changed
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentLocksChanged"),
                    object: nil,
                    userInfo: ["documentId": docId]
                )
            } else {
                // Password incorrect, show error
                print("❌ Password incorrect")
                let errorAlert = NSAlert()
                errorAlert.messageText = "Incorrect Password"
                errorAlert.informativeText = "The password you entered is incorrect. Please try again."
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
                
                // Try again
                verifyPasswordAndOpenDocument(document)
            }
        }
    }
    
    init(showAsGrid: Bool) {
        self.showAsGrid = showAsGrid
        
        // Get all existing folder IDs from CoreData
        let folderFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
        folderFetchRequest.propertiesToFetch = ["id"]
        let folders = (try? PersistenceController.shared.container.viewContext.fetch(folderFetchRequest)) ?? []
        let folderIds = folders.compactMap { $0.value(forKey: "id") as? UUID }
        
        // Create fetch request for documents with no folder or unknown folder
        if folderIds.isEmpty {
            // If there are no folders, just get documents with nil folderId
            _documents = FetchRequest<NSManagedObject>(
                entity: NSEntityDescription.entity(forEntityName: "Document", in: PersistenceController.shared.container.viewContext)!,
                sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
                predicate: NSPredicate(format: "folderId == nil")
            )
        } else {
            // Otherwise, get documents with nil folderId OR documents whose folderId doesn't match any existing folder
            _documents = FetchRequest<NSManagedObject>(
                entity: NSEntityDescription.entity(forEntityName: "Document", in: PersistenceController.shared.container.viewContext)!,
                sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
                predicate: NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "folderId == nil"),
                    NSPredicate(format: "NOT (folderId IN %@)", folderIds)
                ])
            )
        }
    }
    
    var body: some View {
        VStack {
            if documents.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("No Unassigned Documents")
                        .font(.title)
                    
                    Text("All your documents are properly organized in folders")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if showAsGrid {
                    // Grid View with improved adaptive sizing
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 20)
                            ], 
                            spacing: 20
                        ) {
                            ForEach(documents, id: \.self) { document in
                                documentGridCell(document: document)
                            }
                        }
                        .padding()
                    }
                } else {
                    // List View
                    List {
                        ForEach(documents, id: \.self) { document in
                            documentGridCell(document: document)
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .navigationTitle("Unassigned Documents")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingDebugInfo.toggle() }) {
                    Label("Debug Info", systemImage: "info.circle")
                }
            }
        }
        .overlay {
            if isShowingDebugInfo {
                VStack(alignment: .leading) {
                    Text("Document Count: \(documents.count)")
                    
                    // Add thumbnail debugging
                    if let document = documents.first {
                        Text("Document properties: \(document.entity.propertiesByName.keys.joined(separator: ", "))")
                        
                        if let thumbnailValue = document.value(forKey: "thumbnail") {
                            Text("Thumbnail type: \(String(describing: type(of: thumbnailValue)))")
                            Text("Thumbnail value exists: Yes")
                        } else {
                            Text("Thumbnail value exists: No")
                        }
                    }
                    
                    Button("Hide Debug Info") {
                        isShowingDebugInfo = false
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding()
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            // Register for notifications
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshDocumentViews"), 
                                                   object: nil, 
                                                   queue: .main) { _ in
                // Force a refresh of the view
                print("Refreshing unassigned view after document move")
                viewContext.refreshAllObjects()
            }
            
            // Listen for document lock changes
            NotificationCenter.default.addObserver(forName: NSNotification.Name("DocumentLocksChanged"),
                                                 object: nil,
                                                 queue: .main) { _ in
                print("🔁 Refreshing unassigned documents after lock change")
            }
            
            // Listen for RefreshAllDocumentLocks notification
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshAllDocumentLocks"),
                                                 object: nil,
                                                 queue: .main) { _ in
                print("🔄 Refreshing all document locks")
            }
        }
        .onDisappear {
            // Unregister when view disappears
            NotificationCenter.default.removeObserver(self)
        }
        // Use the lockStateChanged property from DocumentLockManager to trigger refreshes
        .id(documentLockManager.lockStateChanged)
    }
}

// Update FolderDetailView to use the showAsGrid property
struct FolderDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let folderName: String
    let folderId: UUID?
    @FetchRequest var documents: FetchedResults<NSManagedObject>
    @State private var viewType: ViewType = .grid
    @State private var searchText: String = ""
    @ObservedObject private var documentLockManager = DocumentLockManager.shared
    // Add static properties for lock checking
    @State private var lastUILockCheckTime: [UUID: Date] = [:]
    private let uiLockCheckThrottleInterval: TimeInterval = 3.0 // seconds

    enum ViewType {
        case grid, list
    }
    
    init(folderName: String, folderId: UUID?) {
        self.folderName = folderName
        self.folderId = folderId
        
        // Create fetch request for documents in this folder
        _documents = FetchRequest<NSManagedObject>(
            entity: NSEntityDescription.entity(forEntityName: "Document", in: PersistenceController.shared.container.viewContext)!,
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: NSPredicate(format: "folderId == %@", folderId as CVarArg? ?? NSNull())
        )
    }
    
    var filteredDocuments: [NSManagedObject] {
        if searchText.isEmpty {
            return Array(documents)
        } else {
            return documents.filter { doc in
                let title = doc.value(forKey: "title") as? String ?? "Untitled Document"
                return title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search and controls
            HStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                
                Spacer()
                
                // View type toggle
                Picker("View", selection: $viewType) {
                    Image(systemName: "square.grid.2x2").tag(ViewType.grid)
                    Image(systemName: "list.bullet").tag(ViewType.list)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 100)
            }
            .padding()
            
            // Documents view based on selected view type
            if filteredDocuments.isEmpty {
                VStack {
                    Text("No documents found")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    if !searchText.isEmpty {
                        Text("Try a different search term")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if viewType == .grid {
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.adaptive(minimum: 120), spacing: 16), count: 1),
                            spacing: 16
                        ) {
                            ForEach(filteredDocuments, id: \.self) { document in
                                documentGridCell(document: document)
                            }
                        }
                        .padding()
                    }
                } else {
                    List {
                        ForEach(filteredDocuments, id: \.self) { document in
                            documentGridCell(document: document)
                        }
                    }
                }
            }
        }
        .navigationTitle(folderName)
        // The view will automatically refresh when documentLockManager's published property changes
        .id(documentLockManager.lockStateChanged)
    }
    
    private func documentGridCell(document: NSManagedObject) -> some View {
        // Always do a fresh check for locked status
        let docId = document.value(forKey: "id") as? UUID
        let documentTitle = document.value(forKey: "title") as? String ?? "Untitled Document"
        
        // Debug the document ID only if needed
        if let id = docId, shouldLogUILockCheck(for: id) {
            print("🔐🔐🔐 UI LOCK CHECK: Document '\(documentTitle)' has ID: \(id)")
            
            let isLocked = DocumentLockManager.shared.isDocumentLocked(id)
            print("🔐🔐🔐 UI LOCK CHECK: Document '\(documentTitle)' lock status: \(isLocked)")
        }
        
        // Still get the lock status but without excessive logging
        let isLocked = docId != nil ? DocumentLockManager.shared.isDocumentLocked(docId!) : false
        
        return Button(action: {
            openDocument(document)
        }) {
            VStack {
                // Display document image or placeholder
                Group {
                    if isLocked {
                        // Show lock icon for locked documents
                        ZStack {
                            Image(nsImage: document.getThumbnailImage() ?? NSImage(named: "Placeholder")!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 130)
                            
                            // Show lock overlay for locked documents
                            Color.black.opacity(0.3)
                                .frame(width: 100, height: 130)
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    } else if let thumbnail = document.getThumbnailImage() {
                        // Show document thumbnail
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 130)
                    } else {
                        // Show placeholder
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                            .frame(width: 100, height: 130)
                    }
                }
                
                // Document title
                Text(document.value(forKey: "title") as? String ?? "Untitled Document")
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100, height: 40)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                if let documentId = document.value(forKey: "id") as? UUID {
                    // Toggle document lock state
                    if isLocked {
                        DocumentLockManager.shared.unlockDocument(documentId)
                        print("🔓 Unlocked document: \(documentId)")
                    } else {
                        // Ensure there's a password set
                        if !DocumentLockManager.shared.hasDocumentLock() {
                            DocumentLockManager.shared.saveDocumentLockPassword("test123")
                            print("🔑 Set default document lock password")
                        }
                        
                        DocumentLockManager.shared.lockDocument(documentId)
                        print("🔒 Locked document: \(documentId)")
                    }
                    
                    // Notify others about the lock change - still needed for non-SwiftUI components
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DocumentLocksChanged"),
                        object: nil,
                        userInfo: ["documentId": documentId]
                    )
                }
            }) {
                if isLocked {
                    Label("Unlock Document", systemImage: "lock.open")
                } else {
                    Label("Lock Document", systemImage: "lock")
                }
            }
            
            Button(action: {
                openDocument(document)
            }) {
                Label("Open Document", systemImage: "doc.text.magnifyingglass")
            }
        }
        .onDrag {
            // Allow documents to be dragged between folders
            if let id = document.value(forKey: "id") as? UUID {
                let provider = NSItemProvider(object: id.uuidString as NSString)
                return provider
            }
            return NSItemProvider()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentLocksChanged"))) { notification in
            // The view will refresh automatically through the ObservableObject
            print("🔔 Received DocumentLocksChanged notification")
        }
        .id("\(document.objectID)-\(DocumentLockManager.shared.lockStateChanged)")
    }
    
    private func openDocument(_ document: NSManagedObject) {
        print("📄 Opening document: \(document.value(forKey: "title") as? String ?? "Untitled Document")")
        
        // Make sure the document is valid and still exists in CoreData
        guard !document.isDeleted && document.managedObjectContext != nil else {
            print("⚠️ Cannot open document: Object is deleted or has no context")
            return
        }
        
        // Check if document is locked using direct call to DocumentLockManager
        if let docId = document.value(forKey: "id") as? UUID {
            // Always do a fresh check with the DocumentLockManager
            let isLocked = DocumentLockManager.shared.isDocumentLocked(docId)
            print("🔒 DOCUMENT OPEN CHECK - ID: \(docId.uuidString), Locked: \(isLocked)")
            
            if isLocked {
                // Document is definitely locked, show password prompt
                print("🔒 Document is locked, showing password prompt")
                verifyPasswordAndOpenDocument(document)
            } else {
                // Document is not locked, open directly
                print("🔓 Document is not locked, opening directly")
                DocumentViewerWindow.openDocument(document)
            }
        } else {
            print("⚠️ No document ID found")
        }
    }
    
    // Verify password and open document if correct
    private func verifyPasswordAndOpenDocument(_ document: NSManagedObject) {
        guard let docId = document.value(forKey: "id") as? UUID else {
            print("⚠️ No document ID found")
            return
        }
        
        // Double-check that the document is actually locked
        let isLocked = DocumentLockManager.shared.isDocumentLocked(docId)
        if !isLocked {
            print("⚠️ Document was not actually locked, opening directly")
            DocumentViewerWindow.openDocument(document)
            return
        }
        
        // Create a password prompt alert
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
            let isPasswordValid = DocumentLockManager.shared.verifyDocumentLockPassword(password)
            print("🔑 Password verification result: \(isPasswordValid) for document: \(docId)")
            
            if isPasswordValid {
                // Password correct, temporarily unlock the document
                print("✅ Password correct, temporarily unlocking document")
                DocumentLockManager.shared.unlockDocument(docId)
                
                // Open the document now that it's unlocked
                DocumentViewerWindow.openDocument(document)
                
                // Post notification for document locks changed
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentLocksChanged"),
                    object: nil,
                    userInfo: ["documentId": docId]
                )
            } else {
                // Password incorrect, show error
                print("❌ Password incorrect")
                let errorAlert = NSAlert()
                errorAlert.messageText = "Incorrect Password"
                errorAlert.informativeText = "The password you entered is incorrect. Please try again."
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
                
                // Try again
                verifyPasswordAndOpenDocument(document)
            }
        }
    }
    
    private func shouldLogUILockCheck(for documentId: UUID) -> Bool {
        let now = Date()
        if let lastLog = lastUILockCheckTime[documentId], 
           now.timeIntervalSince(lastLog) < uiLockCheckThrottleInterval {
            return false
        }
        lastUILockCheckTime[documentId] = now
        return true
    }
}

struct NewFolderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @State private var folderName = ""
    var addFolder: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Folder")
                .font(.headline)
            
            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    addFolder(folderName)
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(folderName.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 350, height: 150)
    }
}

// Add extensions for NSManagedObject
extension NSManagedObject {
    // NSManagedObject extensions for document_displayTitle() and document_folderName() removed to avoid conflicts with CoreDataModels.swift
    
    // Track last log time for each document to avoid excessive logging
    private static var lastLockCheckLogTime: [UUID: Date] = [:]
    private static let lockCheckLogThrottleInterval: TimeInterval = 3.0 // seconds
    
    // Check if a document is currently locked by directly using DocumentLockManager
    func isDocumentLocked() -> Bool {
        guard !self.isDeleted && self.managedObjectContext != nil else {
            return false
        }
        
        if let documentId = self.value(forKey: "id") as? UUID {
            // Always do a fresh check with DocumentLockManager
            let isLocked = DocumentLockManager.shared.isDocumentLocked(documentId)
            
            // Only log if we haven't recently logged for this document
            let now = Date()
            if NSManagedObject.lastLockCheckLogTime[documentId] == nil || 
               now.timeIntervalSince(NSManagedObject.lastLockCheckLogTime[documentId]!) > NSManagedObject.lockCheckLogThrottleInterval {
                
                print("🔒 Document lock check - Document: \(self.value(forKey: "title") as? String ?? "Untitled Document"), Locked: \(isLocked)")
                NSManagedObject.lastLockCheckLogTime[documentId] = now
            }
            
            return isLocked
        }
        
        print("⚠️ Could not check lock status - No document ID found for document: \(self.value(forKey: "title") as? String ?? "Untitled Document")")
        return false
    }
    
    // Get a thumbnail image for a document
    func getThumbnailImage() -> NSImage? {
        // First try the direct 'thumbnail' property which is used in iOS
        if let thumbnail = self.value(forKey: "thumbnail") as? Data, !thumbnail.isEmpty {
            if let image = NSImage(data: thumbnail) {
                return image
            }
        } else if let thumbnail = self.value(forKey: "thumbnail") as? NSImage {
            return thumbnail
        }
        
        // Fall back to checking other potential property names
        let potentialPropertyNames = ["thumbnailData", "previewImage", "preview", "image", "imageData"]
        
        for propertyName in potentialPropertyNames {
            if self.entity.propertiesByName[propertyName] != nil,
               let data = self.value(forKey: propertyName) as? Data,
               !data.isEmpty,
               let image = NSImage(data: data) {
                return image
            }
        }
        
        // Log available properties for debugging
        print("Document entity properties: \(self.entity.propertiesByName.keys.joined(separator: ", "))")
        if let thumbnailValue = self.value(forKey: "thumbnail") {
            print("Thumbnail type: \(type(of: thumbnailValue))")
        } else {
            print("No thumbnail value found")
        }
        
        return nil
    }
}

// Create a tooltip view at the bottom of the file
struct FolderDropTooltip: View {
    let folderName: String
    
    var body: some View {
        Text("Move to: \(folderName)")
            .font(.caption)
            .padding(6)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(4)
            .shadow(radius: 2)
    }
}

// Create a preference key to track drop zones
struct DropInfo: Identifiable, Equatable {
    let id: NSManagedObjectID
    let frame: CGRect
    
    static func == (lhs: DropInfo, rhs: DropInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct DropPreferenceKey: PreferenceKey {
    static var defaultValue: [DropInfo] = []
    
    static func reduce(value: inout [DropInfo], nextValue: () -> [DropInfo]) {
        value.append(contentsOf: nextValue())
    }
}

// Add this MouseLocationTracker struct at the bottom of your file:
struct MouseLocationTracker: NSViewRepresentable {
    var onLocationUpdate: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onLocationUpdate = onLocationUpdate
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? TrackingView {
            view.onLocationUpdate = onLocationUpdate
        }
    }
    
    class TrackingView: NSView {
        var onLocationUpdate: ((CGPoint) -> Void)?
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            
            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }
            
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
            let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(trackingArea)
        }
        
        override func mouseMoved(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            onLocationUpdate?(location)
        }
    }
}

// Then create a global version for use in other views
func createDocumentDragPreview(documentId: UUID, thumbnailImage: NSImage?, title: String, targetFolder: NSManagedObject? = nil) -> NSItemProvider {
    let provider = NSItemProvider()
    
    // Store the document ID as plain text
    let idString = documentId.uuidString
    let data = Data(idString.utf8)
    provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, 
                                       visibility: .all) { completion in
        completion(data, nil)
        return nil
    }
    
    // Check if document is locked
    let isLocked = DocumentLockManager.shared.isDocumentLocked(documentId)
    
    // Create a custom drag preview
    provider.previewImageHandler = { completion, _, _ in
        if let folder = targetFolder {
            // Create a preview with folder name when hovering over a folder
            let customPreview = NSHostingView(rootView: 
                VStack(spacing: 4) {
                    if isLocked {
                        // Show lock icon if document is locked
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.red)
                    } else if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 30))
                    }
                    
                    Text("→ \(folder.value(forKey: "name") as? String ?? "Unnamed Folder")")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }
                .padding(8)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            )
            
            customPreview.frame = CGRect(x: 0, y: 0, width: 100, height: 80)
            
            // Force layout and render
            customPreview.setFrameSize(NSSize(width: 100, height: 80))
            customPreview.layout()
            
            let image = NSImage(data: customPreview.dataWithPDF(inside: customPreview.bounds))
            completion?(image, nil)
        } else if isLocked {
            // Create a locked document preview
            let customPreview = NSHostingView(rootView: 
                VStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.red)
                    Text(title)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            )
            
            customPreview.frame = CGRect(x: 0, y: 0, width: 80, height: 70)
            customPreview.layout()
            
            let image = NSImage(data: customPreview.dataWithPDF(inside: customPreview.bounds))
            completion?(image, nil)
        } else if let image = thumbnailImage {
            // Use thumbnail when not hovering over a folder
            completion?(image, nil)
        } else {
            // Create a basic document preview
            let customPreview = NSHostingView(rootView: 
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                    Text(title)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(8)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            )
            
            customPreview.frame = CGRect(x: 0, y: 0, width: 80, height: 70)
            customPreview.layout()
            
            let image = NSImage(data: customPreview.dataWithPDF(inside: customPreview.bounds))
            completion?(image, nil)
        }
    }
    
    return provider
} 
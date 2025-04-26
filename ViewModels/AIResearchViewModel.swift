import Foundation
import SwiftUI
import CoreData
import Combine

// Document item with selection state for AI Research
struct AIDocumentItem: Identifiable {
    let id: UUID
    let title: String
    let textLength: Int?
    let createdAt: Date
    var folderId: UUID?
    let tagIds: Set<UUID>
    let thumbnail: UIImage?
    let isLocked: Bool
    let estimatedTokens: Int
    
    init(id: UUID, title: String, textLength: Int?, createdAt: Date, folderId: UUID?, tagIds: Set<UUID>, thumbnail: UIImage?, isLocked: Bool) {
        self.id = id
        self.title = title
        self.textLength = textLength
        self.createdAt = createdAt
        self.folderId = folderId
        self.tagIds = tagIds
        self.thumbnail = thumbnail
        self.isLocked = isLocked
        
        // Improved token estimation algorithm based on GPT tokenization research
        // Different languages have different token densities
        // English: ~4 chars/token, Chinese/Japanese: ~1.5 chars/token, Code: ~3.5 chars/token
        if let length = textLength, length > 0 {
            // Default token estimation (roughly 4 characters per token for Latin alphabets)
            let defaultEstimate = max(1, Int(Double(length) / 4.0 * 1.1))
            self.estimatedTokens = defaultEstimate
        } else {
            self.estimatedTokens = 0
        }
    }
}

class AIResearchViewModel: ObservableObject {
    // Document lock manager for document locking operations
    private(set) var documentLockManager = DocumentLockManager.shared
    
    // Add persistence controller - make it a stored property
    let persistenceController: PersistenceController
    var viewContext: NSManagedObjectContext {
        return persistenceController.container.viewContext
    }
    
    // Publish document lists
    @Published var documents: [AIDocumentItem] = []
    @Published var selectedDocumentIds = Set<UUID>()
    @Published var selectedDocuments: [Document] = []
    @Published var isLoading = false
    
    // Search filters - similar to VaultViewModel
    @Published var fromDate: Date
    @Published var toDate: Date = Date()
    @Published var searchTitle = ""
    @Published var selectedTags = Set<UUID>()
    @Published var selectedFolder: UUID? = nil
    
    @Published var allTags: [TagItem] = []
    @Published var allFolders: [FolderItem] = []
    
    @Published var isSelectingFromDate = true
    @Published var showDatePicker = false
    
    @Published var showFolderOptions = false
    @Published var folderSelectionMode: FolderSelectionMode = .allFolders
    
    @Published var isDateFilterActive = false
    @Published var searchText = ""
    @Published var searchOCRText: String = ""
    
    // Token estimation
    @Published var totalSelectedTokens: Int = 0
    
    // Add property to track which model was used
    @Published var modelUsed: String? = nil
    
    // Add property to track request IDs
    @Published var requestIds: [UUID] = []
    
    // Add a property to store the last token usage
    @Published var lastUsage: OpenAIService.TokenUsage?
    
    // First, add a new property to track selected folders
    @Published var selectedFolderIds = Set<UUID>()
    
    // Add this to your AIResearchViewModel class property declarations section
    @Published var showNoTagsOption = false
    
    // Define TagSelectionMode to match the pattern of FolderSelectionMode
    enum TagSelectionMode {
        case allTags
        case selectedTags
    }
    
    // Add property for tag selection mode
    @Published var tagSelectionMode: TagSelectionMode = .allTags
    
    // Add property for selected tag IDs (use different name from selectedTags for clarity)
    @Published var selectedTagIds = Set<UUID>()
    
    // Define the mode enum (without the specific folder case)
    enum FolderSelectionMode {
        case allFolders
        case noFolder
        case selectedFolders // New mode for multiple selected folders
    }
    
    private let openAIService = OpenAIService(apiKey: UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? "")
    public var cancellables = Set<AnyCancellable>()
    
    enum DateRange: String, CaseIterable, Identifiable {
        case all = "All Time"
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastYear = "Last Year"
        
        var id: String { self.rawValue }
    }
    
    // Explicit Initializer accepting PersistenceController
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        // Initialize date properties before accessing viewContext
        self.fromDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // Default to last 30 days

        // Now we can safely use viewContext
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: true)]
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let earliestDoc = results.first, let createdAt = earliestDoc.createdAt {
                self.fromDate = createdAt // Update if an earlier date is found
            }
        } catch {
            print("Error fetching earliest document date: \(error)")
        }
        
        // Setup notifications
        setupNotifications()
    }

    /* Comment out the default initializer that uses the singleton
    init() {
        // Initialize all stored properties first
        self.fromDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // Default to last 30 days
        
        // Now we can use self and access viewContext
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: true)]
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let earliestDoc = results.first, let createdAt = earliestDoc.createdAt {
                self.fromDate = createdAt // Update the value after initialization
            }
        } catch {
            print("Error fetching earliest document date: \(error)")
        }
        
        // Setup notifications
        setupNotifications()
    }
    */
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDocumentDeletedNotification(_:)),
            name: NSNotification.Name("DocumentDeleted"),
            object: nil
        )
    }
    
    @objc private func handleDocumentDeletedNotification(_ notification: Notification) {
        if let documentId = notification.userInfo?["documentId"] as? UUID {
            // Remove from selected documents if it was selected
            if selectedDocumentIds.contains(documentId) {
                selectedDocumentIds.remove(documentId)
                updateTotalTokenCount()
            }
            
            // Refresh the list
            self.searchDocuments()
        }
    }
    
    // MARK: - Document Selection
    
    func selectDocument(_ id: UUID) {
        selectedDocumentIds.insert(id)
        updateTotalTokenCount()
    }
    
    func unselectDocument(_ id: UUID) {
        selectedDocumentIds.remove(id)
        updateTotalTokenCount()
    }
    
    func toggleDocumentSelection(_ id: UUID) {
        if selectedDocumentIds.contains(id) {
            selectedDocumentIds.remove(id)
        } else {
            selectedDocumentIds.insert(id)
        }
        updateTotalTokenCount()
    }
    
    func isDocumentSelected(_ id: UUID) -> Bool {
        return selectedDocumentIds.contains(id)
    }
    
    // MARK: - Tag Selection
    
    func toggleTagSelection(for tagId: UUID) {
        if selectedTags.contains(tagId) {
            selectedTags.remove(tagId)
        } else {
            selectedTags.insert(tagId)
        }
    }
    
    func selectAllDocuments() {
        selectedDocumentIds = Set(documents.map { $0.id })
        updateTotalTokenCount()
    }
    
    func unselectAllDocuments() {
        selectedDocumentIds.removeAll()
        updateTotalTokenCount()
    }
    
    func toggleFolderInSelection(_ folderId: UUID) {
        // Get all document IDs in this folder
        let folderDocumentIds = documents
            .filter { $0.folderId == folderId }
            .map { $0.id }
        
        // Check if all documents in the folder are already selected
        let allSelected = areAllFolderDocumentsSelected(folderId)
        
        if allSelected {
            // If all are selected, deselect all documents in this folder
            for docId in folderDocumentIds {
                selectedDocumentIds.remove(docId)
            }
        } else {
            // Otherwise, select all documents in this folder
            for docId in folderDocumentIds {
                selectedDocumentIds.insert(docId)
            }
        }
        
        // Update the selection mode if needed
        if selectedFolderIds.contains(folderId) {
            selectedFolderIds.remove(folderId)
        } else {
            selectedFolderIds.insert(folderId)
        }
        
        if selectedFolderIds.isEmpty {
            folderSelectionMode = .allFolders
        } else {
            folderSelectionMode = .selectedFolders
        }
        
        // Update the token count
        updateTotalTokenCount()
    }
    
    func areFolderDocumentsSelected(_ folderId: UUID) -> Bool {
        // Get all document IDs in this folder
        let folderDocumentIds = documents
            .filter { $0.folderId == folderId }
            .map { $0.id }
        
        // Return true if at least one document is selected
        return folderDocumentIds.contains { selectedDocumentIds.contains($0) }
    }
    
    func areAllFolderDocumentsSelected(_ folderId: UUID) -> Bool {
        // Get all document IDs in this folder
        let folderDocumentIds = documents
            .filter { $0.folderId == folderId }
            .map { $0.id }
        
        // Return true if all documents are selected
        return !folderDocumentIds.isEmpty && folderDocumentIds.allSatisfy { selectedDocumentIds.contains($0) }
    }
    
    private func updateTotalTokenCount() {
        totalSelectedTokens = documents
            .filter { selectedDocumentIds.contains($0.id) }
            .reduce(0) { $0 + $1.estimatedTokens }
    }
    
    // MARK: - Folder Selection Methods
    
    func resetFolderSelection() {
        selectedFolderIds.removeAll()
        folderSelectionMode = .allFolders
    }
    
    func selectNoFolder() {
        folderSelectionMode = .noFolder
        selectedFolderIds.removeAll()
    }
    
    // MARK: - Data Fetching
    
    func fetchAllTags() {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            let fetchedTags = try viewContext.fetch(fetchRequest)
            
            allTags = fetchedTags.compactMap { tag in
                guard let id = tag.id, let name = tag.name else {
                    return nil
                }
                
                return TagItem(id: id, name: name)
            }
        } catch {
            print("Failed to fetch tags: \(error.localizedDescription)")
        }
    }
    
    func fetchAllFolders() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let fetchedFolders = try viewContext.fetch(fetchRequest)
            
            allFolders = fetchedFolders.compactMap { folder in
                guard let id = folder.id, let name = folder.name else {
                    return nil
                }
                
                return FolderItem(id: id, name: name)
            }
        } catch {
            print("Failed to fetch folders: \(error.localizedDescription)")
        }
    }
    
    func searchDocuments() {
        isLoading = true
        
        // Build the search predicate
        var predicates: [NSPredicate] = []
        
        // Title search
        if !searchTitle.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", searchTitle))
        }
        
        // OCR text search
        if !searchOCRText.isEmpty {
            predicates.append(NSPredicate(format: "text CONTAINS[cd] %@", searchOCRText))
        }
        
        // Date range
        _ = Calendar.current  // if you need the side effect of the call
        let endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: toDate) ?? toDate
        predicates.append(NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", 
                                     fromDate as NSDate, 
                                     endDate as NSDate))
        
        // Tags search
        if !selectedTags.isEmpty {
            let tagPredicate = NSPredicate(format: "ANY tags.id IN %@", selectedTags)
            predicates.append(tagPredicate)
        }
        
        // No tags option
        if showNoTagsOption {
            let noTagsPredicate = NSPredicate(format: "tags.@count == 0")
            predicates.append(noTagsPredicate)
        }
        
        // Folder search
        switch folderSelectionMode {
        case .allFolders:
            // No additional predicate needed for all folders
            break
        case .noFolder:
            // Create a predicate that handles both nil folder IDs and unknown folder IDs
            let folderIds = allFolders.map { $0.id }
            let noFolderPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "folderId == nil"),
                NSPredicate(format: "NOT (folderId IN %@)", folderIds)
            ])
            predicates.append(noFolderPredicate)
        case .selectedFolders:
            if !selectedFolderIds.isEmpty {
                predicates.append(NSPredicate(format: "folderId IN %@", selectedFolderIds))
            }
        }
        
        // Combine all predicates
        let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Perform the search
        DispatchQueue.global(qos: .userInitiated).async {
            // Complete the implementation of the search execution
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = finalPredicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
            
            do {
                let fetchedDocuments = try self.viewContext.fetch(fetchRequest)
                
                // Process the results
                DispatchQueue.main.async {
                    self.documents = fetchedDocuments.compactMap { document in
                        guard let id = document.id,
                              let title = document.title,
                              let createdAt = document.createdAt else {
                            // Instead of returning nil, return a placeholder or empty item
                            return AIDocumentItem(
                                id: UUID(), // Generate a temporary ID
                                title: "Untitled Document",
                                textLength: 0,
                                createdAt: Date(),
                                folderId: nil,
                                tagIds: Set<UUID>(),
                                thumbnail: nil,
                                isLocked: false
                            )
                        }
                        
                        // Create a document item with all the required properties
                        return AIDocumentItem(
                            id: id,
                            title: title,
                            textLength: document.text?.count,
                            createdAt: createdAt,
                            folderId: document.folderId,
                            tagIds: Set(document.tags?.compactMap { ($0 as? Tag)?.id } ?? []),
                            thumbnail: document.thumbnail != nil ? UIImage(data: document.thumbnail!) : nil,
                            isLocked: false
                        )
                    }
                    
                    self.isLoading = false
                }
            } catch {
                print("Error fetching documents: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    // Clear all search criteria to default values
    func clearSearchCriteria() {
        // Clear search text fields
        searchTitle = ""
        searchOCRText = ""
        
        // Reset date range (keep default fromDate from init)
        fromDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        toDate = Date() // Current date
        
        // Clear tag selection
        selectedTags.removeAll()
        showNoTagsOption = false
        
        // Reset folder selection
        selectedFolderIds.removeAll()
        folderSelectionMode = .allFolders
        
        // Clear document selection
        selectedDocumentIds.removeAll()
        updateTotalTokenCount()
    }
    
    func refreshData() {
        fetchAllTags()
        fetchAllFolders()
        searchDocuments()
    }
    
    // MARK: - Document Access
    
    func getSelectedDocuments() -> [AIDocumentItem] {
        return documents.filter { selectedDocumentIds.contains($0.id) }
    }
    
    // Helper to get document text contents for sending to AI
    func getSelectedDocumentContents() -> [(UUID, String, String)] {
        var contents: [(UUID, String, String)] = []
        
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", selectedDocumentIds as CVarArg)
        
        do {
            let fetchedDocuments = try viewContext.fetch(fetchRequest)
            
            contents = fetchedDocuments.compactMap { document in
                guard let id = document.id,
                      let title = document.title,
                      let text = document.text,
                      !text.isEmpty else {
                    return nil
                }
                
                return (id, title, text)
            }
        } catch {
            print("Error fetching document contents: \(error)")
        }
        
        return contents
    }
    
    // MARK: - UI Helper Properties
    
    var folderSelectionText: String {
        switch folderSelectionMode {
        case .allFolders:
            return "All Folders"
        case .noFolder:
            return "No Folder Assigned"
        case .selectedFolders:
            let count = selectedFolderIds.count
            return count == 1 ? "1 Folder Selected" : "\(count) Folders Selected"
        }
    }
    
    func getFolderName(for document: AIDocumentItem) -> String? {
        guard let folderId = document.folderId else { return nil }
        return allFolders.first { $0.id == folderId }?.name
    }
    
    func getTagsText(for document: AIDocumentItem) -> String {
        return document.tagIds.compactMap { tagId in
            allTags.first { $0.id == tagId }?.name
        }.joined(separator: ", ")
    }
    
    // Add tracking of the model used when retrieving the response
    func researchWithAI(prompt: String, systemRole: String) -> AnyPublisher<OpenAIService.AIResearchResponse, Error> {
        // Clear previous model information
        self.modelUsed = nil
        
        // Get the selected model from user defaults
        let selectedModel = UserDefaults.standard.string(forKey: "AIModelPreference") ?? "gpt-4-turbo"
        
        return openAIService.sendChatQueryWithStats(
            prompt: prompt, 
            systemRole: systemRole,
            modelName: selectedModel
        )
        .handleEvents(receiveOutput: { [weak self] response in
            // Record the model that was actually used
            if let model = response.modelUsed {
                self?.modelUsed = model
                print("🤖 AI Research used model: \(model)")
            } else {
                self?.modelUsed = selectedModel
                print("🤖 AI Research using selected model: \(selectedModel)")
            }
            
            // Save the request ID (keep last 5 max)
            self?.saveRequestId(response.requestId)
            print("🔍 OpenAI Request ID: \(response.requestId.uuidString) - save this for checking logs")
        })
        .eraseToAnyPublisher()
    }
    
    // Method to save request ID
    private func saveRequestId(_ requestId: UUID) {
        // Add the request ID to the requestIds array
        requestIds.append(requestId)
        
        // Ensure the array doesn't exceed 5 items
        if requestIds.count > 5 {
            requestIds.removeFirst()
        }
    }
    
    // Method to get the last two request IDs
    func getLastTwoRequestIds() -> [String] {
        var result: [String] = []
        
        // Get last ID if available
        if let lastId = requestIds.last?.uuidString {
            result.append("Latest Request ID: \(lastId)")
        }
        
        // Get second-to-last ID if available
        if requestIds.count > 1 {
            let secondLastId = requestIds[requestIds.count - 2].uuidString
            result.append("Previous Request ID: \(secondLastId)")
        }
        
        // If no IDs available
        if result.isEmpty {
            result.append("No request IDs available yet")
        }
        
        return result
    }
    
    // For no-folder document selection functionality
    func areAllDocumentsWithoutFolderSelected() -> Bool {
        let documentsWithoutFolder = documents.filter { $0.folderId == nil }
        return !documentsWithoutFolder.isEmpty && documentsWithoutFolder.allSatisfy { selectedDocumentIds.contains($0.id) }
    }
    
    func areDocumentsWithoutFolderSelected() -> Bool {
        return documents
            .filter { $0.folderId == nil }
            .contains { selectedDocumentIds.contains($0.id) }
    }
    
    func toggleNoFolderSelection() {
        let documentsWithoutFolder = documents.filter { $0.folderId == nil }
        let allSelected = areAllDocumentsWithoutFolderSelected()
        
        if allSelected {
            // Unselect all documents without folder
            for document in documentsWithoutFolder {
                selectedDocumentIds.remove(document.id)
            }
        } else {
            // Select all documents without folder
            for document in documentsWithoutFolder {
                selectedDocumentIds.insert(document.id)
            }
        }
        
        // Update the token count
        updateTotalTokenCount()
    }
    
    // For tags functionality
    func resetTagSelection() {
        selectedTags.removeAll()
        selectedTagIds.removeAll()
        tagSelectionMode = .allTags
        showNoTagsOption = false
    }
    
    func selectAllTags() {
        selectedTags = Set(allTags.map { $0.id })
        selectedTagIds = selectedTags
    }
    
    func deselectAllTags() {
        selectedTags.removeAll()
        showNoTagsOption = false
    }
    
    // For no tags option toggling (already have the property)
    func toggleNoTagsOption() {
        showNoTagsOption.toggle()
        
        // If enabling "no tags" option, clear any selected tags
        if showNoTagsOption {
            selectedTags.removeAll()
        }
    }
    
    // Method to move a document to a different folder
    func moveDocument(documentId: UUID, toFolderId: UUID) {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Document")
        fetchRequest.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let document = results.first {
                // Use KVC instead of direct property assignment
                document.setValue(toFolderId, forKey: "folderId")
                try context.save()
                
                // Update in-memory model as needed
                if let index = documents.firstIndex(where: { $0.id == documentId }) {
                    var updatedDoc = documents[index]
                    updatedDoc.folderId = toFolderId  // AIDocumentItem has folderId as var, so this is fine
                    documents[index] = updatedDoc
                }
                
                objectWillChange.send()
            }
        } catch {
            print("Error moving document: \(error)")
        }
    }
    
    // Helper method for drag and drop
    func updateFolderForDocument(documentId: UUID, newFolderId: UUID?) {
        // Find the document in local array
        if let index = documents.firstIndex(where: { $0.id == documentId }) {
            // Update its folder ID
            documents[index] = AIDocumentItem(
                id: documents[index].id,
                title: documents[index].title,
                textLength: documents[index].textLength,
                createdAt: documents[index].createdAt,
                folderId: newFolderId,
                tagIds: documents[index].tagIds,
                thumbnail: documents[index].thumbnail,
                isLocked: documents[index].isLocked
            )
            
            // Update in Core Data
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let document = results.first {
                    document.setValue(newFolderId, forKey: "folderId")
                    try context.save()
                }
            } catch {
                print("Error updating document folder: \(error)")
            }
            
            // Notify that data changed
            objectWillChange.send()
        }
    }
    
    // Define a method that takes an ID parameter
    func refreshDocumentInViewModel(documentId: UUID) {
        // Updated implementation that uses the documentId parameter
        if documents.contains(where: { $0.id == documentId }) {
            // Refresh just this document
            objectWillChange.send()
        }
    }
    
    // Use this pattern for all property updates in both iOS and macOS apps
    func updateDocumentProperty(documentId: UUID, propertyName: String, value: Any?) {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Document")
        fetchRequest.predicate = NSPredicate(format: "id == %@", documentId as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let document = results.first {
                // Check if the property exists before setting it
                if document.entity.propertiesByName[propertyName] != nil {
                    document.setValue(value, forKey: propertyName)
                    try context.save()
                    
                    // Update your view model's local cache if needed
                    self.refreshDocumentInViewModel(documentId: documentId)
                } else {
                    print("Property \(propertyName) not found in entity")
                }
            }
        } catch {
            print("Error updating document property: \(error)")
        }
    }
} 
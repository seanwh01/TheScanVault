import SwiftUI
import CoreData
import Combine
import Foundation

extension ViewModels_Vault {
    class VaultSearchService {
        // Persistence controller and context
        private(set) var persistenceController: PersistenceController
        var viewContext: NSManagedObjectContext {
            return persistenceController.container.viewContext
        }
        
        // Services connected to this service
        private var filterService: VaultFilterService?
        private var sortingService: VaultSortingService?
        private var documentManager: VaultDocumentManager?
        
        // Publishers for search results
        private let documentsSubject = CurrentValueSubject<[DocumentListItem], Never>([])
        var documentsPublisher: AnyPublisher<[DocumentListItem], Never> {
            return documentsSubject.eraseToAnyPublisher()
        }
        
        // Loading state publisher
        private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
        var isLoadingPublisher: AnyPublisher<Bool, Never> {
            return isLoadingSubject.eraseToAnyPublisher()
        }
        
        // Storage for cancellables
        var cancellables = Set<AnyCancellable>()
        
        // MARK: - Initialization
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
        }
        
        // MARK: - Setup Methods
        
        func setupBindings(
            filterService: VaultFilterService,
            sortingService: VaultSortingService,
            documentManager: VaultDocumentManager
        ) {
            self.filterService = filterService
            self.sortingService = sortingService
            self.documentManager = documentManager
        }
        
        // MARK: - Search Methods
        
        func performSearch() {
            guard let filterService = filterService else {
                print("❌ Filter service not connected")
                return
            }
            
            isLoadingSubject.send(true)
            
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            var predicates: [NSPredicate] = []
            
            // Add text search predicate
            if !filterService.searchText.isEmpty {
                let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", filterService.searchText)
                let textPredicate = NSPredicate(format: "text CONTAINS[cd] %@", filterService.searchText)
                
                // This will search in both title and extracted text
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [titlePredicate, textPredicate]))
            }
            
            // FOLDER FILTER
            if filterService.selectedFolderIds.contains(ViewModels_Vault.defaultNoFolderId) {
                // For "No Folder Assigned" we should include:
                // 1. Documents with nil folderId
                // 2. Documents with special "unknown" folder IDs
                let unknownFolderIds = findUnknownFolderIds()
                
                if !unknownFolderIds.isEmpty {
                    // Create an OR predicate to match nil folders OR unknown folders
                    let noFolderPredicate = NSPredicate(format: "folderId == nil")
                    let unknownFolderPredicate = NSPredicate(format: "folderId IN %@", unknownFolderIds)
                    
                    predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                        noFolderPredicate, unknownFolderPredicate
                    ]))
                    print("🗂️ Standard search including nil folders and 'unknown' folders")
                } else {
                    // If we couldn't find any unknown folders, just use nil check
                    predicates.append(NSPredicate(format: "folderId == nil"))
                    print("🗂️ Standard search including only nil folders (no unknown folders found)")
                }
                
                // Set the flag to true to ensure our UI shows these as "no folder" documents
                filterService.showNoFolderDocuments = true
            } else if !filterService.selectedFolderIds.isEmpty {
                // Only specific folders are selected (excluding No Folder)
                predicates.append(NSPredicate(format: "folderId IN %@", filterService.selectedFolderIds))
            }
            
            // Date range filter
            if filterService.isDateFilterActive {
                let calendar = Calendar.current
                let startOfFromDate = calendar.startOfDay(for: filterService.fromDate)
                let endOfToDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: filterService.toDate)!
                predicates.append(NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", 
                                           startOfFromDate as NSDate, endOfToDate as NSDate))
            }
            
            // Tags filter
            if !filterService.selectedTags.isEmpty {
                // Use .id for Tag entity (now non-optional)
                let tagPredicate = NSPredicate(format: "ANY tags.id IN %@", filterService.selectedTags)
                predicates.append(tagPredicate)
            } else if filterService.showNoTagsOption {
                predicates.append(NSPredicate(format: "tags.@count == 0"))
            }
            
            // Latest document filter
            if filterService.showLatestOnly, let documentId = filterService.latestDocumentId {
                // Use .id for Document entity (now non-optional)
                predicates.append(NSPredicate(format: "id == %@", documentId as CVarArg))
            }
            
            // Combined predicates
            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            
            // Always sort by date, newest first
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
            
            do {
                let fetchedDocuments = try viewContext.fetch(fetchRequest)
                
                // Convert the fetched documents to DocumentListItems
                let documentItems = fetchedDocuments.compactMap { document -> DocumentListItem? in
                    // Use .id (now non-optional)
                    guard let id = document.id, let title = document.title, let createdAt = document.createdAt else {
                        print("Warning: Found a Document entity with missing id, title or createdAt.")
                        return nil
                    }
                    
                    // Get folder name if it exists
                    var folderName: String? = nil
                    if let folderId = document.folderId {
                        folderName = getFolderName(for: folderId)
                    }
                    
                    // Get tag names
                    let tagNames = (document.tags?.allObjects as? [Tag])?.compactMap { $0.name } ?? []
                    
                    return DocumentListItem(
                        id: id,
                        title: title,
                        createdAt: createdAt,
                        folderName: folderName,
                        tagNames: tagNames,
                        text: document.text
                    )
                }
                
                // Update the published documents
                documentsSubject.send(documentItems)
                isLoadingSubject.send(false)
            } catch {
                print("Failed to fetch documents: \(error.localizedDescription)")
                documentsSubject.send([])
                isLoadingSubject.send(false)
            }
        }
        
        func searchDocumentsWithFreshContext(page: Int = 0, perPage: Int = 50, completion: @escaping ([DocumentListItem], Bool) -> Void = {_, _ in }) {
            guard let filterService = filterService else {
                print("❌ Filter service not connected")
                completion([], true)
                return
            }
            
            print("🔍 Performing search with fresh context, page: \(page), perPage: \(perPage)")
            isLoadingSubject.send(true)
            
            // Create a fresh context for the search
            let freshContext = PersistenceController.shared.container.newBackgroundContext()
            freshContext.automaticallyMergesChangesFromParent = true
            
            // Create a fetch request with the current filters
            let fetchRequest = Document.fetchRequest()
            applyFiltersToFetchRequest(fetchRequest)
            
            // Configure pagination if requested
            if page > 0 || perPage < 50 {
                fetchRequest.fetchLimit = perPage
                fetchRequest.fetchOffset = page * perPage
            } else if perPage >= 50 {
                // If we're fetching the first large page, don't use a limit
                fetchRequest.fetchLimit = 0
            }
            
            // Execute in background
            freshContext.perform { [weak self] in
                guard let self = self else { return }
                
                do {
                    let fetchedDocuments = try fetchRequest.execute()
                    
                    // Check if this is the last page
                    let isLastPage = fetchRequest.fetchLimit == 0 || fetchedDocuments.count < perPage
                    
                    // Log the details of the fetch
                    if page == 0 {
                        print("🔍 Initial fetch returned \(fetchedDocuments.count) documents")
                    } else {
                        print("🔍 Page \(page) fetch returned \(fetchedDocuments.count) documents")
                    }
                    
                    // Convert to DocumentListItems
                    let documents = fetchedDocuments.compactMap { document -> DocumentListItem? in
                        // Use .id (now non-optional)
                        guard let id = document.id, let title = document.title else { return nil }
                        let createdAt = document.createdAt ?? Date()
                        
                        // Tag names
                        var tagNames: [String] = []
                        if let tags = document.tags as? Set<Tag> {
                            tagNames = tags.compactMap { $0.name }.sorted()
                        }
                        
                        // Get folder name if available
                        let folderName: String? = {
                            if let folderId = document.folderId {
                                let folderRequest = NSFetchRequest<Folder>(entityName: "Folder")
                                // Fetch Folder using id (now non-optional)
                                folderRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                                folderRequest.fetchLimit = 1
                                
                                if let folder = try? freshContext.fetch(folderRequest).first {
                                    return folder.name
                                }
                            }
                            return nil
                        }()
                        
                        return DocumentListItem(
                            id: id as UUID,
                            title: title,
                            createdAt: createdAt,
                            folderName: folderName,
                            tagNames: tagNames,
                            text: document.text
                        )
                    }
                    
                    // Update on main thread
                    DispatchQueue.main.async {
                        // If page is 0, replace documents array, otherwise append (preventing duplicates)
                        if page == 0 {
                            self.documentsSubject.send(documents)
                            print("📊 Replaced document list with \(documents.count) documents")
                        } else {
                            // Get the set of existing document IDs
                            let existingIds = Set(self.documentsSubject.value.map { $0.id })
                            
                            // Only add documents that aren't already in the collection
                            let newDocuments = documents.filter { !existingIds.contains($0.id) }
                            
                            if !newDocuments.isEmpty {
                                var updatedDocuments = self.documentsSubject.value
                                updatedDocuments.append(contentsOf: newDocuments)
                                self.documentsSubject.send(updatedDocuments)
                                print("📊 Added \(newDocuments.count) new documents to list")
                            }
                            
                            // Log if we filtered out any duplicates
                            if documents.count != newDocuments.count {
                                print("⚠️ Filtered out \(documents.count - newDocuments.count) duplicate documents during search pagination")
                            }
                        }
                        
                        self.isLoadingSubject.send(false)
                        
                        // Complete with new documents and whether this is the last page
                        completion(documents, isLastPage)
                    }
                } catch {
                    print("❌ Error in search: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingSubject.send(false)
                        completion([], true) // Return empty array and true for last page on error
                    }
                }
            }
        }
        
        // MARK: - Helper Methods
        
        private func applyFiltersToFetchRequest(_ fetchRequest: NSFetchRequest<Document>) {
            guard let filterService = filterService else { return }
            
            var predicates: [NSPredicate] = []
            
            // Title search predicate
            if !filterService.searchTitle.isEmpty {
                predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", filterService.searchTitle))
            }
            
            // OCR text search predicate
            if !filterService.searchOCRText.isEmpty {
                predicates.append(NSPredicate(format: "text != nil AND text != '' AND text CONTAINS[cd] %@", filterService.searchOCRText))
            }
            
            // Add folder predicate
            switch filterService.folderSelectionType {
            case .specificFolder(let folderId):
                predicates.append(NSPredicate(format: "folderId == %@", folderId as CVarArg))
            case .noFolder:
                let unknownFolderIds = findUnknownFolderIds()
                if !unknownFolderIds.isEmpty {
                    predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                        NSPredicate(format: "folderId == nil"),
                        NSPredicate(format: "folderId IN %@", unknownFolderIds)
                    ]))
                } else {
                    predicates.append(NSPredicate(format: "folderId == nil"))
                }
            case .allFolders:
                // No predicate needed - include all folders
                break
            }
            
            // Date range filter
            if filterService.isDateFilterActive {
                let calendar = Calendar.current
                let startOfFromDate = calendar.startOfDay(for: filterService.fromDate)
                let endOfToDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: filterService.toDate)!
                predicates.append(NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", 
                                           startOfFromDate as NSDate, endOfToDate as NSDate))
            }
            
            // Tags filter
            if !filterService.selectedTags.isEmpty {
                // Use .id for Tag entity (now non-optional)
                let tagPredicate = NSPredicate(format: "ANY tags.id IN %@", filterService.selectedTags)
                predicates.append(tagPredicate)
            } else if filterService.showNoTagsOption {
                predicates.append(NSPredicate(format: "tags.@count == 0"))
            }
            
            // Latest document filter
            if filterService.showLatestOnly, let documentId = filterService.latestDocumentId {
                // Use .id for Document entity (now non-optional)
                predicates.append(NSPredicate(format: "id == %@", documentId as CVarArg))
            }
            
            // Combined predicates
            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            
            // Always sort by date, newest first
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
        }
        
        private func getFolderName(for id: UUID) -> String? {
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            // Fetch Folder using id (now non-optional)
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try viewContext.fetch(fetchRequest)
                return results.first?.name
            } catch {
                print("Error fetching folder name: \(error)")
                return nil
            }
        }
        
        func findUnknownFolderIds() -> [UUID] {
            // Find folder IDs that seem to be 'no folder' (empty or containing 'unknown')
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == '' OR name CONTAINS[cd] 'unknown' OR name CONTAINS[cd] 'none'")
            
            do {
                let unknownFolders = try viewContext.fetch(fetchRequest)
                // Map using id (now non-optional)
                let unknownIds = unknownFolders.compactMap { $0.id }
                
                print("Found \(unknownIds.count) 'unknown' folder IDs: \(unknownIds)")
                return unknownIds
            } catch {
                print("Error finding unknown folder IDs: \(error)")
                return []
            }
        }
        
        func refreshDataWithoutNavigation() {
            performSearch()
        }
        
        func fetchDocumentsWithoutFilters() {
            // Simple fetch to quickly get documents without filtering
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
            fetchRequest.fetchLimit = 50 // Limit to prevent huge results
            
            do {
                let fetchedDocuments = try viewContext.fetch(fetchRequest)
                
                // Convert to view models
                let documentItems = fetchedDocuments.compactMap { document -> DocumentListItem? in
                    // Use .id (now non-optional)
                    guard let id = document.id, let title = document.title, let createdAt = document.createdAt else {
                        print("Warning: Found a Document entity with missing id, title or createdAt during unfiltered fetch.")
                        return nil
                    }
                    
                    // Get folder name if it exists
                    var folderName: String? = nil
                    if let folderId = document.folderId {
                        folderName = getFolderName(for: folderId)
                    }
                    
                    // Get tag names
                    let tagNames = (document.tags?.allObjects as? [Tag])?.compactMap { $0.name } ?? []
                    
                    return DocumentListItem(
                        id: id,
                        title: title,
                        createdAt: createdAt,
                        folderName: folderName,
                        tagNames: tagNames,
                        text: document.text
                    )
                }
                
                // Update the published documents
                documentsSubject.send(documentItems)
                isLoadingSubject.send(false)
            } catch {
                print("Failed to fetch documents without filters: \(error.localizedDescription)")
                documentsSubject.send([])
                isLoadingSubject.send(false)
            }
        }
    }
} 
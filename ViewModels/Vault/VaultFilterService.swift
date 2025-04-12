import SwiftUI
import CoreData
import Combine
import Foundation

extension ViewModels_Vault {
    class VaultFilterService {
        // Persistence controller and context
        private(set) var persistenceController: PersistenceController
        var viewContext: NSManagedObjectContext {
            return persistenceController.container.viewContext
        }
        
        // MARK: - Filter State Properties
        
        // Date filters
        @Published var fromDate: Date
        @Published var toDate: Date = Date()
        @Published var isDateFilterActive = false
        @Published var isSelectingFromDate = true
        @Published var showDatePicker = false
        
        // Tag filters
        @Published var selectedTags = Set<UUID>()
        @Published var showNoTagsOption = false
        @Published var allTags: [ViewModels_Vault.TagItem] = []
        
        // Folder filters
        @Published var selectedFolder: UUID? = nil
        @Published var showFolderOptions = false
        @Published var folderSelectionType: FolderSelectionType = .allFolders
        @Published var selectedFolderIds: Set<UUID> = []
        @Published var showNoFolderDocuments = false
        @Published var allFolders: [ViewModels_Vault.FolderItem] = []
        
        // Search filters
        @Published var searchTitle = ""
        @Published var searchText = ""
        @Published var searchOCRText: String = ""
        
        // Latest document filter
        @Published var showLatestOnly = false
        @Published var latestDocumentId: UUID?
        @Published var forceShowNewestDocument = false
        
        // MARK: - Initialization
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
            
            // Initialize from date
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: true)]
            fetchRequest.fetchLimit = 1
            
            // Set default value
            self.fromDate = Date()
            
            // Try to find earliest document date
            do {
                let results = try viewContext.fetch(fetchRequest)
                if let earliestDoc = results.first, let createdAt = earliestDoc.createdAt {
                    self.fromDate = createdAt
                }
            } catch {
                print("Error fetching earliest document date: \(error)")
            }
        }
        
        // MARK: - Tag Methods
        
        func fetchAllTags() {
            // We need a specialized fetch request that only returns tags used on documents
            let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
            
            // Only return tags that are associated with at least one document
            fetchRequest.predicate = NSPredicate(format: "SUBQUERY(documents, $doc, $doc != nil).@count > 0")
            
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                // Ensure the context is up to date
                viewContext.refreshAllObjects()
                
                // Use a fresh execution of the fetch request
                let fetchedTags = try viewContext.fetch(fetchRequest)
                
                // Log the tags for debugging
                print("Fetched \(fetchedTags.count) USED tags: \(fetchedTags.compactMap { $0.name }.joined(separator: ", "))")
                
                allTags = fetchedTags.compactMap { tag in
                    guard let id = tag.id, let name = tag.name else {
                        return nil
                    }
                    
                    return ViewModels_Vault.TagItem(id: id, name: name)
                }
            } catch {
                print("Failed to fetch tags: \(error.localizedDescription)")
            }
        }
        
        func toggleNoTagsOption() {
            // Toggle the state
            showNoTagsOption.toggle()
            
            // If enabling "no tags" option, clear any selected tags
            if showNoTagsOption {
                selectedTags.removeAll()
            }
            
            // Post a notification for observers
            NotificationCenter.default.post(
                name: NSNotification.Name("NoTagsOptionChanged"),
                object: nil,
                userInfo: ["state": showNoTagsOption]
            )
        }
        
        func toggleTag(_ tag: ViewModels_Vault.TagItem) {
            // If "no tags" option is selected, deselect it first
            if showNoTagsOption {
                showNoTagsOption = false
            }
            
            if selectedTags.contains(tag.id) {
                selectedTags.remove(tag.id)
            } else {
                selectedTags.insert(tag.id)
            }
        }
        
        func cleanupSelectedTags() {
            // Get the current IDs of all valid tags
            let validTagIds = Set(allTags.map { $0.id })
            
            // Remove any selected tags that no longer exist
            selectedTags = selectedTags.intersection(validTagIds)
            
            // If we had selected tags but they're all gone now, reset the search
            if selectedTags.isEmpty && !showNoTagsOption {
                // No need to do anything special, tags are already deselected
                print("Selected tags were removed from the database")
            }
        }
        
        // MARK: - Folder Methods
        
        func fetchAllFolders() {
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
            
            do {
                let fetchedFolders = try viewContext.fetch(fetchRequest)
                
                allFolders = fetchedFolders.compactMap { folder in
                    guard let id = folder.id, let name = folder.name else {
                        return nil
                    }
                    
                    return ViewModels_Vault.FolderItem(id: id, name: name)
                }
            } catch {
                print("Failed to fetch folders: \(error.localizedDescription)")
            }
        }
        
        func resetFolderSelection() {
            selectedFolderIds.removeAll()
            folderSelectionType = .allFolders
            selectedFolder = nil
        }
        
        func selectNoFolder() {
            selectedFolderIds.removeAll()
            selectedFolderIds.insert(ViewModels_Vault.defaultNoFolderId)
            folderSelectionType = .noFolder
            selectedFolder = nil
            
            // Set a flag to indicate we want to show all documents without a proper folder
            showNoFolderDocuments = true
            
            // Print debug info
            print("🔍 No Folder Assigned selected - analyzing folder distribution:")
            printFolderDistribution()
        }
        
        func selectFolder(_ folderId: UUID) {
            // Clear selection and add this folder
            selectedFolderIds.removeAll()
            selectedFolderIds.insert(folderId)
            // Keep this for backward compatibility
            folderSelectionType = .specificFolder(folderId)
        }
        
        func toggleFolderSelection(_ folderId: UUID) {
            // Simple toggle logic
            if selectedFolderIds.contains(folderId) {
                selectedFolderIds.remove(folderId)
            } else {
                selectedFolderIds.insert(folderId)
            }
            
            // Update the folderSelectionType for backward compatibility
            updateFolderSelectionTypeFromSet()
        }
        
        private func updateFolderSelectionTypeFromSet() {
            if selectedFolderIds.isEmpty {
                folderSelectionType = .allFolders
                selectedFolder = nil
            } else if selectedFolderIds.count == 1 {
                if let folderId = selectedFolderIds.first {
                    if folderId == ViewModels_Vault.defaultNoFolderId {
                        folderSelectionType = .noFolder
                        selectedFolder = nil
                    } else {
                        folderSelectionType = .specificFolder(folderId)
                        selectedFolder = folderId
                    }
                }
            } else {
                // When multiple folders are selected, use .allFolders
                // but the actual filtering will use selectedFolderIds
                folderSelectionType = .allFolders
                selectedFolder = nil
            }
        }
        
        func printFolderDistribution() {
            print("📊 FOLDER DISTRIBUTION ANALYSIS")
            
            // First count documents with nil folders
            let nilFolderRequest = NSFetchRequest<Document>(entityName: "Document")
            nilFolderRequest.predicate = NSPredicate(format: "folderId == nil")
            
            do {
                let nilFolderCount = try viewContext.count(for: nilFolderRequest)
                print("Documents with nil folder: \(nilFolderCount)")
                
                // Then get all folders and count their documents
                let folderRequest = NSFetchRequest<Folder>(entityName: "Folder")
                let folders = try viewContext.fetch(folderRequest)
                
                for folder in folders {
                    if let folderId = folder.id, let folderName = folder.name {
                        let docRequest = NSFetchRequest<Document>(entityName: "Document")
                        docRequest.predicate = NSPredicate(format: "folderId == %@", folderId as CVarArg)
                        let count = try viewContext.count(for: docRequest)
                        
                        // Check if this folder looks like an "unknown" folder
                        let isUnknownType = folderName.lowercased().contains("unknown") || 
                                           folderName.isEmpty || 
                                           folderName.lowercased().contains("none")
                        
                        print("Folder '\(folderName)' (ID: \(folderId)): \(count) documents \(isUnknownType ? "- UNKNOWN TYPE" : "")")
                    }
                }
            } catch {
                print("Error analyzing folder distribution: \(error)")
            }
        }
        
        // MARK: - General Filter Methods
        
        func clearFilters() {
            // Your existing clearing logic might include:
            selectedTags.removeAll()
            selectedFolder = nil
            folderSelectionType = .allFolders
            selectedFolderIds.removeAll()
            showNoTagsOption = false
            
            // Ensure dates are reset too
            isDateFilterActive = false
            fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            toDate = Date()
            
            // Clear the search title
            searchTitle = ""
            searchText = ""
            searchOCRText = ""
            
            print("🔄 All filters cleared")
        }
        
        // MARK: - Metadata Methods
        
        func forceRefreshMetadata() {
            // Force a complete context reset and refresh
            PersistenceController.shared.container.performBackgroundTask { context in
                // Fetch tags in background context
                let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                tagRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
                
                // Fetch folders in background context
                let folderRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
                folderRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
                
                do {
                    // Execute fetches in background
                    let backgroundTags = try context.fetch(tagRequest)
                    let backgroundFolders = try context.fetch(folderRequest)
                    
                    // Log for debugging
                    print("BACKGROUND FETCH: Found \(backgroundTags.count) tags and \(backgroundFolders.count) folders")
                    
                    // Update on main thread
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // Reset view context
                        self.viewContext.reset()
                        
                        // Re-fetch with fresh context
                        self.fetchAllTags()
                        self.fetchAllFolders()
                        
                        print("REFRESHED UI DATA: \(self.allTags.count) tags and \(self.allFolders.count) folders")
                    }
                } catch {
                    print("Background fetch error: \(error.localizedDescription)")
                }
            }
        }
    }
} 
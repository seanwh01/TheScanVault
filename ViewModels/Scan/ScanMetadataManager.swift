import Foundation
import CoreData
import SwiftUI
import Combine

#if os(macOS)
typealias UIImage = NSImage
#endif

// Define necessary item types if not globally available
// Making them Hashable allows use in Sets if needed later
struct FolderItem: Identifiable, Hashable, Equatable {
    let id: UUID
    let name: String
}

struct TagItem: Identifiable, Hashable, Equatable {
    let id: UUID
    let name: String
}

extension ViewModels_Scan {
    
    // Define the protocol for ScanMetadataManager
    public protocol ScanMetadataManagerProtocol {
        var folders: [FolderItem] { get } // Read-only property
        var tags: [TagItem] { get }     // Read-only property
        func fetchFolders()
        func fetchTags()
        func addFolder(name: String) -> FolderItem
        func addTag(name: String) -> TagItem
        func pendingFolderName(for id: UUID) -> String?
    }

    @MainActor // Ensure UI updates happen on the main thread
    class ScanMetadataManager: ObservableObject {
        @Published var documentTitle: String = ""
        @Published var selectedFolderId: UUID? = nil
        @Published var selectedTagIds: Set<UUID> = []
        @Published var folders: [FolderItem] = []
        @Published var tags: [TagItem] = []
        @Published var aiErrorMessage: String = ""
        
        // State for pending items suggested by AI or added by user before final save
        // These are tracked here, but likely processed/committed by PersistenceService during save
        private(set) var pendingFolderToCreate: (name: String, id: UUID)?
        private(set) var pendingTagsToCreate: [(name: String, id: UUID)] = []
        // Read-only computed property indicating if pending items exist
        var usesPendingCreation: Bool {
             pendingFolderToCreate != nil || !pendingTagsToCreate.isEmpty
        }

        // Public accessor for pending tag names
        public var pendingTagNamesById: [UUID: String] {
            Dictionary(uniqueKeysWithValues: pendingTagsToCreate.map { ($0.id, $0.name) })
        }

        private var cancellables = Set<AnyCancellable>()
        private let persistenceController: PersistenceController // Use concrete class
        let aiService: AIDocumentAnalysisService? // Allow optional AI service
        private var context: NSManagedObjectContext { // Convenience getter for context
            persistenceController.container.viewContext
        }

        init(persistenceController: PersistenceController, aiService: AIDocumentAnalysisService? = nil) {
            self.persistenceController = persistenceController
            self.aiService = aiService
            // Fetching is now done via the convenience context getter
            // fetchFolders() // Called after context is available
            // fetchTags() // Called after context is available
            // Call fetch methods after initialization or ensure context is ready
            // For now, let's assume context is ready immediately, but this might need adjustment.
            fetchFolders() // Refresh initial state
            fetchTags() // Refresh initial state
        }
        
        // MARK: - Fetching
        
        func fetchFolders() {
            let request = NSFetchRequest<Folder>(entityName: "Folder")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
            
            do {
                let results = try context.fetch(request)
                // Use compactMap to safely unwrap optional UUIDs
                self.folders = results.compactMap { folder in
                    guard let id = folder.id else { 
                        print("⚠️ Folder found with nil ID: \(folder.name ?? "Unnamed")")
                        return nil
                    }
                    return FolderItem(id: id, name: folder.name ?? "Unnamed Folder")
                }
                print("📂 Fetched \(self.folders.count) folders")
            } catch {
                print("🚨 Error fetching folders: \(error.localizedDescription)")
                self.folders = [] // Ensure a defined state on error
            }
        }

        func fetchTags() {
            let request = NSFetchRequest<Tag>(entityName: "Tag")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
            
            do {
                let results = try context.fetch(request)
                self.tags = results.compactMap { tag in
                     guard let id = tag.id else { 
                        print("⚠️ Tag found with nil ID: \(tag.name ?? "Unnamed")")
                        return nil
                    }
                    return TagItem(id: id, name: tag.name ?? "Unnamed Tag")
                }
                 print("🏷️ Fetched \(self.tags.count) tags")
            } catch {
                print("🚨 Error fetching tags: \(error.localizedDescription)")
                self.tags = [] // Ensure a defined state on error
            }
        }
        
        // MARK: - AI Suggestion Application
        
        func applyAISuggestions(_ suggestions: DocumentClassifierService.DocumentSuggestions) {
            print("Applying AI suggestions to metadata manager: \(suggestions.suggestedTitle)")
            
            // Reset pending state before applying new suggestions
            resetPendingMetadata()
            
            // Apply suggested title
            self.documentTitle = suggestions.suggestedTitle
            
            // Apply suggested folder
            if let folderName = suggestions.suggestedFolderName, !folderName.isEmpty {
                print("📂 Applying suggested folder: \(folderName)")
                createOrSelectFolder(folderName)
            } else {
                 print("📂 No folder suggested or suggestion is empty.")
                 self.selectedFolderId = nil // Ensure no folder is selected if none suggested
            }
            
            // Apply suggested tags
            var appliedTagIds = Set<UUID>()
            for tagName in suggestions.suggestedTags where !tagName.isEmpty {
                print("🏷️ Applying suggested tag: \(tagName)")
                let normalizedTagName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let tagId = createOrSelectTag(normalizedTagName) {
                    appliedTagIds.insert(tagId)
                }
            }
            // self.selectedTagIds = appliedTagIds // Temporarily comment out to test deletion bug
            print("✅ Applied AI suggestions. Title: '\(documentTitle)', FolderID: \(selectedFolderId?.uuidString ?? "None"), TagIDs: \(selectedTagIds.map { $0.uuidString }) ")

            // Force UI updates if necessary (consider if direct @Published updates suffice)
            // objectWillChange.send()
        }
        
        // MARK: - Metadata Management Helpers
        
        // Resets any pending folder or tags (e.g., when applying new AI suggestions)
        func resetPendingMetadata() {
            print("🔄 Resetting pending metadata")
            pendingFolderToCreate = nil
            pendingTagsToCreate.removeAll()
        }
        
        // Public method to clear all pending tags added via UI
        public func clearPendingTags() {
            print("🗑️ Clearing pending tags.")
            pendingTagsToCreate.removeAll()
            objectWillChange.send() // Notify observers
        }

        // Public method to add a tag name to the pending list (called from UI like SaveTagsEditView)
        // Returns the UUID of the pending or existing tag, or nil if name is invalid/empty.
        @discardableResult
        public func addPendingTag(name: String) -> UUID? {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                print("❌ MetadataManager: Cannot add pending tag with empty name.")
                return nil
            }

            // Check if tag already exists (case-insensitive)
            if let existingTag = tags.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
                print("🏷️ MetadataManager: Tag '\(trimmedName)' already exists (ID: \(existingTag.id)). Not adding as pending.")
                // Depending on desired behavior, you might want to select it instead?
                // For now, just return its ID so the UI knows it exists.
                return existingTag.id 
            }

            // Check if tag is already pending (case-insensitive)
            if let pendingTag = pendingTagsToCreate.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
                print("🏷️ MetadataManager: Tag '\(trimmedName)' is already pending (ID: \(pendingTag.id)).")
                return pendingTag.id
            }

            // Add new tag to pending list
            let newTagId = UUID()
            pendingTagsToCreate.append((name: trimmedName, id: newTagId))
            print("🏷️ MetadataManager: Added pending tag '\(trimmedName)' (Pending ID: \(newTagId)).")
            objectWillChange.send() // Notify observers
            return newTagId
        }

        // Creates a pending folder or selects an existing one, updating selectedFolderId.
        private func createOrSelectFolder(_ folderName: String) {
            let normalizedFolderName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedFolderName.isEmpty { return }
            
            // Check if folder already exists
            if let existingFolder = folders.first(where: { $0.name.caseInsensitiveCompare(normalizedFolderName) == .orderedSame }) {
                print("📂 Selecting existing folder: \(existingFolder.name) (ID: \(existingFolder.id))")
                self.selectedFolderId = existingFolder.id
                // Ensure no pending folder if we selected an existing one
                if pendingFolderToCreate?.name == normalizedFolderName {
                     pendingFolderToCreate = nil
                }
            } else {
                // Folder doesn't exist, set as pending
                let newFolderId = UUID()
                 print("📂 Setting pending folder: \(normalizedFolderName) (Pending ID: \(newFolderId))")
                self.pendingFolderToCreate = (name: normalizedFolderName, id: newFolderId)
                self.selectedFolderId = newFolderId // Select the pending folder
            }
        }
        
        // Creates pending tags or selects existing ones, returning the ID.
        // Note: This adds to `pendingTagsToCreate` but doesn't modify `selectedTagIds` directly.
        // `applyAISuggestions` is responsible for setting `selectedTagIds` based on the results.
        @discardableResult
        private func createOrSelectTag(_ tagName: String) -> UUID? {
            let normalizedTagName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedTagName.isEmpty { return nil }

            // Check if tag already exists
            if let existingTag = tags.first(where: { $0.name.caseInsensitiveCompare(normalizedTagName) == .orderedSame }) {
                 print("🏷️ Selecting existing tag: \(existingTag.name) (ID: \(existingTag.id))")
                // Ensure it's not in pending if we selected an existing one
                pendingTagsToCreate.removeAll { $0.name == normalizedTagName }
                return existingTag.id
            } else {
                // Tag doesn't exist, check if it's already pending
                if let pendingTag = pendingTagsToCreate.first(where: { $0.name.caseInsensitiveCompare(normalizedTagName) == .orderedSame }) {
                     print("🏷️ Tag already pending: \(pendingTag.name) (Pending ID: \(pendingTag.id))")
                     return pendingTag.id
                } else {
                    // Add new tag to pending list
                    let newTagId = UUID()
                    print("🏷️ Setting pending tag: \(normalizedTagName) (Pending ID: \(newTagId))")
                    pendingTagsToCreate.append((name: normalizedTagName, id: newTagId))
                    return newTagId
                }
            }
        }

        // MARK: - Validation Methods

        /// Validates if a folder with the suggested name exists (case-insensitive).
        /// - Parameter name: The suggested folder name.
        /// - Returns: The UUID of the existing folder, or nil if it doesn't exist.
        func validateSuggestedFolder(name: String) -> UUID? {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else { return nil }

            // Check against existing folders (case-insensitive)
            if let existingFolder = folders.first(where: { $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame }) {
                print("✅ Validated existing folder: \(existingFolder.name)")
                return existingFolder.id
            }
            
            print("❓ Folder validation failed for: \(normalizedName)")
            return nil
        }

        /// Validates which suggested tag names correspond to existing tags (case-insensitive).
        /// - Parameter names: An array of suggested tag names.
        /// - Returns: A Set containing the UUIDs of the existing tags found.
        func validateSuggestedTags(names: [String]) -> Set<UUID> {
            var validatedTagIds = Set<UUID>()
            let normalizedNames = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

            for normalizedName in normalizedNames {
                // Check against existing tags (case-insensitive)
                 if let existingTag = tags.first(where: { $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame }) {
                    print("✅ Validated existing tag: \(existingTag.name)")
                    validatedTagIds.insert(existingTag.id)
                 } else {
                    print("❓ Tag validation failed for: \(normalizedName)")
                 }
            }
            print("🏷️ Validation complete. Found \(validatedTagIds.count) existing tags out of \(normalizedNames.count) suggestions.")
            return validatedTagIds
        }

        // MARK: - Public Creation/Selection Methods (Called by ViewModel)

        // Public method for ViewModel to add/select a folder by name
        // Returns the FolderItem (either existing or newly pending)
        func addFolder(name: String) -> FolderItem {
            let normalizedFolderName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedFolderName.isEmpty else {
                // Handle empty name case if necessary, maybe return a default or throw
                // For now, let's return a placeholder or handle upstream
                fatalError("Attempted to add folder with empty name") // Or return a default FolderItem
            }

            // Check existing folders
            if let existingFolder = folders.first(where: { $0.name.caseInsensitiveCompare(normalizedFolderName) == .orderedSame }) {
                print("📂 [Public Add] Selecting existing folder: \(existingFolder.name)")
                self.selectedFolderId = existingFolder.id // Ensure it's selected
                // Clear pending if it matches
                if pendingFolderToCreate?.name == normalizedFolderName {
                     pendingFolderToCreate = nil
                }
                return existingFolder
            } else {
                // Check if already pending
                if let pending = pendingFolderToCreate, pending.name.caseInsensitiveCompare(normalizedFolderName) == .orderedSame {
                     print("📂 [Public Add] Folder already pending: \(pending.name)")
                     self.selectedFolderId = pending.id // Ensure pending is selected
                     return FolderItem(id: pending.id, name: pending.name)
                } else {
                    // Create new pending folder
                    let newFolderId = UUID()
                    print("📂 [Public Add] Setting NEW pending folder: \(normalizedFolderName) (ID: \(newFolderId))")
                    self.pendingFolderToCreate = (name: normalizedFolderName, id: newFolderId)
                    self.selectedFolderId = newFolderId // Select the new pending folder
                    return FolderItem(id: newFolderId, name: normalizedFolderName)
                }
            }
        }

        // Public method for ViewModel to add/select a tag by name
        // Returns the TagItem (either existing or newly pending)
        func addTag(name: String) -> TagItem {
             let normalizedTagName = name.trimmingCharacters(in: .whitespacesAndNewlines)
             guard !normalizedTagName.isEmpty else {
                 fatalError("Attempted to add tag with empty name") // Or return a default TagItem
             }

             // Check existing tags
             if let existingTag = tags.first(where: { $0.name.caseInsensitiveCompare(normalizedTagName) == .orderedSame }) {
                 print("🏷️ [Public Add] Selecting existing tag: \(existingTag.name)")
                 // Ensure it's not pending if we selected an existing one
                 pendingTagsToCreate.removeAll { $0.name == normalizedTagName }
                 // Note: This method doesn't automatically select the tag in selectedTagIds
                 return existingTag
             } else {
                 // Check if already pending
                 if let pendingTag = pendingTagsToCreate.first(where: { $0.name.caseInsensitiveCompare(normalizedTagName) == .orderedSame }) {
                     print("🏷️ [Public Add] Tag already pending: \(pendingTag.name)")
                      return TagItem(id: pendingTag.id, name: pendingTag.name)
                 } else {
                     // Add new tag to pending list
                     let newTagId = UUID()
                     print("🏷️ [Public Add] Setting NEW pending tag: \(normalizedTagName) (ID: \(newTagId))")
                     pendingTagsToCreate.append((name: normalizedTagName, id: newTagId))
                     return TagItem(id: newTagId, name: normalizedTagName)
                 }
             }
         }
        
        // MARK: - Public Interface for ViewModel

        /// Selects an existing folder by name or sets it as pending if it doesn't exist.
        /// Updates `selectedFolderId` accordingly.
        /// - Parameter name: The name of the folder to select or create.
        public func selectOrRequestCreateFolder(name: String) {
            // Call the private helper which contains the core logic
            createOrSelectFolder(name)
        }

        // MARK: - Pending Item Management
        
        /// Removes a pending tag from the creation list using its temporary ID.
        public func removePendingTag(byId id: UUID) {
            if let index = pendingTagsToCreate.firstIndex(where: { $0.id == id }) {
                let removedTagName = pendingTagsToCreate[index].name
                pendingTagsToCreate.remove(at: index)
                print("🏷️ Removed pending tag: \(removedTagName) (ID: \(id))")
            } else {
                print("⚠️ Could not find pending tag with ID \(id) to remove.")
            }
        }

        // MARK: - Tag Creation

        /// Creates a new TagItem in Core Data if a tag with the same name doesn't already exist.
        /// - Parameter name: The name for the new tag.
        /// - Returns: The UUID of the newly created tag, or nil if creation failed (e.g., duplicate name, save error).
        func createTag(name: String) -> UUID? {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                print("❌ MetadataManager: Cannot create tag with empty name.")
                return nil
            }

            // Check for duplicates (case-insensitive) using the correct context and Entity name
            let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            // Use case-insensitive predicate
            fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", trimmedName)
            fetchRequest.fetchLimit = 1 // We only need to know if at least one exists

            do {
                // Use the context computed property
                let existingTags = try context.fetch(fetchRequest)
                if !existingTags.isEmpty {
                    print("ℹ️ MetadataManager: Tag named '\(trimmedName)' already exists. Cannot create duplicate.")
                    return existingTags.first?.id // Return existing tag's ID maybe? Or nil to indicate no *new* tag created?
                }
            } catch {
                print("❌ MetadataManager: Error fetching tags to check for duplicates: \(error.localizedDescription)")
                return nil
            }

            // If no duplicate found, create the new tag
            print("🚀 MetadataManager: Creating new tag: \(trimmedName)")
            // Use the correct Core Data entity 'Tag' and the context property
            let newTag = Tag(context: context)
            newTag.id = UUID() // Assign ID *after* initialization
            newTag.name = trimmedName
            newTag.createdAt = Date()
            // Assuming 'Tag' entity doesn't have 'isPending'. If it does, set it here.

            // Attempt to save the context
            // Use the context property
            if context.hasChanges {
                do {
                    try context.save()
                    print("✅ MetadataManager: Successfully saved new tag '\(trimmedName)' with ID \(newTag.id!.uuidString)")
                    fetchTags() // Refresh the tags list
                    return newTag.id
                } catch {
                    print("❌ MetadataManager: Failed to save context after creating tag: \(error.localizedDescription)")
                    // Use the context property
                    context.rollback() // Rollback changes on save failure
                    return nil
                }
            } else {
                 print("⚠️ MetadataManager: No changes detected in context after creating tag? This shouldn't happen.")
                 return nil
            }
        }

        // MARK: - Folder Creation

        /// Creates a new FolderItem in Core Data if a folder with the same name doesn't already exist.
        /// - Parameter name: The name for the new folder.
        /// - Returns: The newly created FolderItem object, or nil if creation failed (e.g., duplicate name, save error).
        func createFolder(name: String) -> FolderItem? {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                print("❌ MetadataManager: Cannot create folder with empty name.")
                return nil
            }

            // Check for duplicates (case-insensitive) using the correct context and Entity name
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", trimmedName)
            fetchRequest.fetchLimit = 1

            do {
                // Use the context computed property
                let existingFolders = try context.fetch(fetchRequest)
                if let existing = existingFolders.first {
                    print("ℹ️ MetadataManager: Folder named '\(trimmedName)' already exists. Returning existing folder.")
                    // Return the FolderItem struct representation
                    return FolderItem(id: existing.id ?? UUID(), name: existing.name ?? "Unnamed")
                }
            } catch {
                print("❌ MetadataManager: Error fetching folders to check for duplicates: \(error.localizedDescription)")
                return nil
            }

            // If no duplicate found, create the new folder
            print("🚀 MetadataManager: Creating new folder: \(trimmedName)")
            // Use the correct Core Data entity 'Folder' and the context property
            let newFolder = Folder(context: context)
            newFolder.id = UUID() // Assign ID *after* initialization
            newFolder.name = trimmedName

            // Attempt to save the context
            // Use the context property
            if context.hasChanges {
                do {
                    try context.save()
                    print("✅ MetadataManager: Successfully saved new folder '\(trimmedName)' with ID \(newFolder.id!.uuidString)")
                    fetchFolders() // Refresh the folders list
                    // Return the FolderItem struct representation
                    return FolderItem(id: newFolder.id ?? UUID(), name: newFolder.name ?? "Unnamed")
                } catch {
                    print("❌ MetadataManager: Failed to save context after creating folder: \(error.localizedDescription)")
                    // Use the context property
                    context.rollback()
                    return nil
                }
            } else {
                 print("⚠️ MetadataManager: No changes detected in context after creating folder? This shouldn't happen.")
                 return nil
            }
        }

        // MARK: - UI Interaction Methods
        
        func toggleTagSelection(_ tagId: UUID) {
             print("‼️ [MetadataManager] toggleTagSelection called for ID: \(tagId)")
             print("‼️ [MetadataManager] BEFORE operation: selectedTagIds = \(selectedTagIds.map { $0.uuidString }.joined(separator: ", "))")
              // Use a temporary set to avoid Combine race conditions during modification
              var currentIds = self.selectedTagIds

              if currentIds.contains(tagId) {
                  currentIds.remove(tagId)
                  print("‼️ [MetadataManager] AFTER removal: selectedTagIds = \(selectedTagIds.map { $0.uuidString }.joined(separator: ", "))")
                  print("🏷️ Deselected tag ID: \(tagId.uuidString)")
              } else {
                  currentIds.insert(tagId)
                  print("‼️ [MetadataManager] AFTER insert: selectedTagIds = \(selectedTagIds.map { $0.uuidString }.joined(separator: ", "))")
                   print("🏷️ Selected tag ID: \(tagId.uuidString)")
              }
             // Assign the modified set back in one operation
             self.selectedTagIds = currentIds
             print("‼️ [MetadataManager] FINAL state after assignment: selectedTagIds = \(selectedTagIds.map { $0.uuidString }.joined(separator: ", "))")
          }

         func selectFolder(_ folderId: UUID?) {
            self.selectedFolderId = folderId
            // If user explicitly selects a folder (or none), clear any pending folder creation
            if pendingFolderToCreate != nil {
                 print("🔄 Clearing pending folder creation due to explicit user selection.")
                 pendingFolderToCreate = nil
            }
             print("📂 Selected folder ID: \(folderId?.uuidString ?? "None")")
        }

        // Method to explicitly add a new tag (e.g., from user input)
        func addNewTag(_ tagName: String) {
            if let tagId = createOrSelectTag(tagName) {
                selectedTagIds.insert(tagId)
                // Maybe refresh tags list if a pending tag was added?
                // Or rely on save + fetch cycle
            }
        }

        // Method to explicitly add a new folder (e.g., from user input)
        func addNewFolder(_ folderName: String) {
             createOrSelectFolder(folderName)
             // Maybe refresh folders list if a pending folder was added?
             // Or rely on save + fetch cycle
        }
        
        // Function to clear the state for a new document
        func clearForm() {
            documentTitle = ""
            selectedFolderId = nil
            selectedTagIds = []
            resetPendingMetadata()
             print("📄 Cleared document metadata form")
        }
        
        // Implement pendingFolderName(for:) method
        func pendingFolderName(for id: UUID) -> String? {
            if let pending = pendingFolderToCreate, pending.id == id {
                return pending.name
            }
            return nil
        }
        
        // MARK: - Public Accessors
        
        /// Returns the name of a tag given its ID, checking both existing and pending tags.
        /// - Parameter id: The ID of the tag to find.
        /// - Returns: The name of the tag, or nil if not found.
        public func tagName(for id: UUID) -> String? {
            // Check existing tags first
            if let existingTag = tags.first(where: { $0.id == id }) {
                return existingTag.name
            }
            // Check pending tags if not found in existing
            if let pendingName = pendingTagNamesById[id] {
                return pendingName
            }
            // Not found
            return nil
        }
    }
}

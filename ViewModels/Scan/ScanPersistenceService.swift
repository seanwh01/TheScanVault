import Foundation
import CoreData
import Combine
import SwiftUI // For UIImage definition

#if os(macOS)
typealias UIImage = NSImage
#endif

// Define necessary item types if not globally available
struct DocumentItem: Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let folderId: UUID?
    let tagIds: [UUID]
    let thumbnail: Data? // Store as Data
    var isLocked: Bool { // Add isLocked logic if needed here or fetched separately
         DocumentLockManager.shared.isDocumentLocked(id)
    }
}

extension ViewModels_Scan {

    @MainActor
    class ScanPersistenceService: ObservableObject {
        @Published private(set) var recentScans: [DocumentItem] = []
        @Published private(set) var lastSavedDocumentId: UUID? // For success screen
        @Published private(set) var lastSavedDocumentTitle: String = "" // For success screen

        private let viewContext: NSManagedObjectContext
        private let adaptiveClassifier: AdaptiveLearningClassifier
        private var cancellables = Set<AnyCancellable>()
        
        init(context: NSManagedObjectContext, adaptiveClassifier: AdaptiveLearningClassifier) {
            self.viewContext = context
            self.adaptiveClassifier = adaptiveClassifier
            fetchRecentScans()
            print("💾 ScanPersistenceService Initialized")
        }
        
        // MARK: - Fetching
        
        func fetchRecentScans() {
            let request = NSFetchRequest<Document>(entityName: "Document")
            // Fetch limited number, sorted by creation date descending
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
            request.fetchLimit = 20 // Or adjust as needed
            
            do {
                let results = try viewContext.fetch(request)
                self.recentScans = results.compactMap { doc in
                    guard let id = doc.id else { return nil }
                    return DocumentItem(
                        id: id,
                        title: doc.title ?? "Untitled",
                        createdAt: doc.createdAt ?? Date(),
                        folderId: doc.folderId,
                        tagIds: (doc.tags as? Set<Tag>)?.compactMap { $0.id } ?? [],
                        thumbnail: doc.thumbnail
                    )
                }
                print("📄 Fetched \(self.recentScans.count) recent scans")
            } catch {
                print("🚨 Error fetching recent scans: \(error.localizedDescription)")
                self.recentScans = []
            }
        }
        
        // MARK: - Saving Document

        struct SaveContext {
            let title: String
            let selectedFolderId: UUID?
            let selectedTagIds: Set<UUID>
            let ocrText: String?
            let documentData: Data // Native PDF or generated PDF/Image data
            let thumbnailData: Data?
            let pendingFolder: (name: String, id: UUID)?
            let pendingTags: [(name: String, id: UUID)]
            let originalAISuggestions: DocumentClassifierService.DocumentSuggestions? // For adaptive learning
            let inputDataType: InputDataType // Specify if input was PDF or Images
        }
        
        enum InputDataType {
            case pdf
            case images
        }

        // Saves the document and handles pending metadata and adaptive learning.
        // Returns the ID of the saved document or an error.
        func saveDocument(context: SaveContext) -> Result<UUID, Error> {
            print("💾 Attempting to save document: \(context.title)")
            
            // 1. Process Pending Metadata
            let metadataResult = processPendingMetadata(context: context)
            guard let finalFolderId = metadataResult.folderId, let finalTagIds = metadataResult.tagIds else {
                print("🚨 Failed to process pending metadata.")
                return .failure(PersistenceError.metadataProcessingFailed)
            }
            
            // 2. Create and Configure Document Entity
            let newDocument = Document(context: viewContext)
            newDocument.id = UUID()
            newDocument.title = context.title
            newDocument.createdAt = Date()
            newDocument.updatedAt = Date()
            newDocument.text = context.ocrText
            newDocument.documentData = context.documentData // Store the provided data (native PDF or processed images)
            newDocument.thumbnail = context.thumbnailData

            // 3. Assign Relationships
            if let folderId = finalFolderId {
                assignFolder(to: newDocument, folderId: folderId)
            }
            assignTags(to: newDocument, tagIds: finalTagIds)

            // 4. Save to Core Data
            do {
                try viewContext.save()
                guard let savedId = newDocument.id else {
                     print("🚨 Document saved but ID is nil!")
                     return .failure(PersistenceError.saveFailedIdMissing)
                }
                print("✅ Document saved successfully with ID: \(savedId.uuidString)")
                
                // Update state for success screen
                lastSavedDocumentId = savedId
                lastSavedDocumentTitle = newDocument.title ?? "Untitled"
                
                // Fetch recents again to include the new document
                fetchRecentScans()
                
                // 5. Update Adaptive Classifier (after successful save)
                recordUserCorrectionIfApplicable(document: newDocument, originalSuggestions: context.originalAISuggestions)
                
                return .success(savedId)
                
            } catch {
                print("🚨 Error saving document: \(error.localizedDescription)")
                // Rollback? Core Data handles this implicitly if save fails before commit.
                viewContext.rollback()
                return .failure(error)
            }
        }
        
        // MARK: - Metadata Processing (Internal)
        
        // Processes pending folder/tags, returning the final IDs to assign.
        private func processPendingMetadata(context: SaveContext) -> (folderId: UUID??, tagIds: Set<UUID>?) {
            print("💾 Processing pending metadata before saving...")
            var finalFolderId: UUID? = context.selectedFolderId
            var finalTagIds: Set<UUID> = context.selectedTagIds
            var metadataErrorOccurred = false

            // Process pending folder
            if let pendingFolder = context.pendingFolder {
                // Double-check if it was created between suggestion and save (unlikely but possible)
                if fetchFolder(withId: pendingFolder.id) != nil {
                    print("💾 Pending folder \(pendingFolder.name) already exists with ID \(pendingFolder.id)")
                    finalFolderId = pendingFolder.id // Use the existing one
                } else {
                    print("💾 Creating pending folder: \(pendingFolder.name) with ID \(pendingFolder.id)")
                    let newFolder = Folder(context: viewContext)
                    newFolder.id = pendingFolder.id
                    newFolder.name = pendingFolder.name
                    finalFolderId = newFolder.id // Assign the ID of the newly created folder
                    // Don't save context here, save happens once for the document
                }
            }
            
            // Process pending tags
            var resolvedPendingTagIds = Set<UUID>()
            for pendingTag in context.pendingTags {
                 // Check if it was created between suggestion and save
                 if fetchTag(withId: pendingTag.id) != nil {
                    print("💾 Pending tag \(pendingTag.name) already exists with ID \(pendingTag.id)")
                    resolvedPendingTagIds.insert(pendingTag.id)
                 } else {
                    print("💾 Creating pending tag: \(pendingTag.name) with ID \(pendingTag.id)")
                    let newTag = Tag(context: viewContext)
                    newTag.id = pendingTag.id
                    newTag.name = pendingTag.name
                    resolvedPendingTagIds.insert(pendingTag.id)
                    // Don't save context here
                 }
            }
            
            // Combine originally selected tags with newly resolved pending tags
            // We need to ensure we don't add IDs that were for pending items but now resolved
            finalTagIds.formUnion(resolvedPendingTagIds)
            // Remove any original IDs that were placeholders for pending items
            let pendingTagPlaceholders = Set(context.pendingTags.map { $0.id })
            finalTagIds.subtract(pendingTagPlaceholders.subtracting(resolvedPendingTagIds))

            // Check if the final selected folder ID actually exists (could be nil or point to a deleted folder)
            if let folderId = finalFolderId, fetchFolder(withId: folderId) == nil {
                 print("⚠️ Selected Folder ID \(folderId) does not exist in context. Clearing selection.")
                 finalFolderId = nil // Clear the selection if the folder doesn't exist
                 // This handles cases where a pending folder failed creation somehow or a selected folder was deleted.
            }
            
            // Verify final tag IDs exist
            let existingTagIds = fetchTags(withIds: finalTagIds).compactMap { $0.id }
            let missingTagIds = finalTagIds.subtracting(existingTagIds)
            if !missingTagIds.isEmpty {
                print("⚠️ Some selected Tag IDs do not exist: \(missingTagIds). Removing them.")
                finalTagIds.subtract(missingTagIds)
            }

            return (folderId: finalFolderId, tagIds: finalTagIds)
        }
        
        // Helper to assign folder relationship
        private func assignFolder(to document: Document, folderId: UUID) {
            // Fetch the actual Folder object to verify it exists
             if fetchFolder(withId: folderId) != nil { // Keep check to ensure ID is valid
                 print("💾 Setting folderId \(folderId) for document '\(document.title ?? "N/A")'")
                 document.folderId = folderId // Reverted: Assign the UUID to the folderId attribute
             } else {
                 print("🚨 Could not find folder with ID \(folderId) to assign. Leaving folderId nil.")
                 document.folderId = nil // Ensure attribute is nil if folder doesn't exist
             }
        }

        // Helper to assign tag relationships
        private func assignTags(to document: Document, tagIds: Set<UUID>) {
            let tags = fetchTags(withIds: tagIds)
             print("💾 Assigning \(tags.count) tags to document '\(document.title ?? "N/A")'")
            document.tags = Set(tags) as NSSet
        }
        
        // MARK: - Core Data Fetch Helpers (Internal)

        private func fetchFolder(withId id: UUID) -> Folder? {
            let request = NSFetchRequest<Folder>(entityName: "Folder")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try? viewContext.fetch(request).first
        }
        
         private func fetchTag(withId id: UUID) -> Tag? {
            let request = NSFetchRequest<Tag>(entityName: "Tag")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try? viewContext.fetch(request).first
        }

        private func fetchTags(withIds ids: Set<UUID>) -> [Tag] {
            guard !ids.isEmpty else { return [] }
            let request = NSFetchRequest<Tag>(entityName: "Tag")
            request.predicate = NSPredicate(format: "id IN %@", ids as CVarArg)
            return (try? viewContext.fetch(request)) ?? []
        }
        
        // MARK: - Adaptive Learning
        
        private func recordUserCorrectionIfApplicable(document: Document, originalSuggestions: DocumentClassifierService.DocumentSuggestions?) {
            guard let aiSuggestions = originalSuggestions else {
                print("🧠 No original AI suggestions provided, skipping adaptive learning record.")
                return
            }
            
            // Ensure document ID and text exist
            guard let docId = document.id, let docText = document.text else {
                 print("🚨 Cannot record learning example: Document ID or text is missing.")
                 return
            }

            // Construct the user's final choices as a DocumentSuggestions object
            let userSelectedTitle = document.title ?? "Untitled"
            var userSelectedFolderName: String? = nil
            if let fId = document.folderId, let folder = fetchFolder(withId: fId) {
                 userSelectedFolderName = folder.name
            }
            let userSelectedTagNames = (document.tags as? Set<Tag>)?.compactMap { $0.name } ?? []

            // Create the user selection structure (confidence isn't relevant here, use 1.0)
            let userSelection = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: userSelectedTitle,
                suggestedFolderName: userSelectedFolderName,
                suggestedTags: userSelectedTagNames,
                confidence: 1.0 // User choice is definitive
            )
            
            print("🧠 Recording adaptive learning example for document ID: \(docId)")
            print("   AI Suggestion: Title='\(aiSuggestions.suggestedTitle)', Folder='\(aiSuggestions.suggestedFolderName ?? "None")', Tags='\(aiSuggestions.suggestedTags)'")
            print("   User Selection: Title='\(userSelection.suggestedTitle)', Folder='\(userSelection.suggestedFolderName ?? "None")', Tags='\(userSelection.suggestedTags)'")


            adaptiveClassifier.recordUserCorrection(
                originalText: docText,
                aiSuggestion: aiSuggestions,
                finalUserChoice: userSelection
            )
        }
    }
    
    enum PersistenceError: Error {
        case metadataProcessingFailed
        case saveFailedIdMissing
    }
}

// Extension needed for macOS thumbnail generation
#if os(macOS)
extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
#endif

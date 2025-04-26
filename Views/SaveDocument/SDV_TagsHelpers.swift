import SwiftUI
import CoreData
import Combine

// Helper extension for tag management in SaveDocumentView
// This maintains the critical tag handling logic mentioned in the memory requirements
extension Views_SaveDocument {
    struct SDV_TagsHelpers {
        
        // Sync tags between ViewModel and MetadataManager (source of truth)
        // This is a critical function for maintaining proper tag state
        @MainActor
        static func syncTagsWithViewModel(viewModel: ViewModels_Scan.ScanViewModel) {
            print("💫 Synchronizing tags with ViewModel...")
            print("Tags before sync: VM has \(viewModel.selectedTagIds.count) tags, Manager has \(viewModel.metadataManager.selectedTagIds.count) tags")
            
            // Always update the viewModel from the metadataManager (source of truth)
            // This is the critical pattern that fixed the tag deletion bug
            viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
            
            // Force a UI refresh
            DispatchQueue.main.async {
                viewModel.objectWillChange.send()
            }
            
            print("Tags after sync: VM has \(viewModel.selectedTagIds.count) tags, Manager has \(viewModel.metadataManager.selectedTagIds.count) tags")
        }
        
        // Handle suggested tag selection
        // This uses the correct method of adding tags by calling createAndSelectTag
        // rather than directly manipulating viewModel.selectedTagIds
        @MainActor
        static func selectSuggestedTag(viewModel: ViewModels_Scan.ScanViewModel, 
                                       tagName: String, 
                                       showConfirmation: inout Bool) {
            print("🏷️ [SDV_TagsHelpers] User selected suggested tag: \(tagName)")
            
            // Use the createAndSelectTag method which maintains proper state flow
            viewModel.createAndSelectTag(name: tagName)
            
            // Show the confirmation
            withAnimation {
                showConfirmation = true
            }
            
            // Hide it after a delay - use notification to avoid capturing inout parameter
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // Since we can't capture the inout parameter in an escaping closure,
                    // we need to use a different approach. We'll post a notification instead.
                    NotificationCenter.default.post(
                        name: Notification.Name("HideTagConfirmation"),
                        object: nil
                    )
                }
            }
        }
        
        // Apply all suggested tags from AI
        @MainActor
        static func applyAllSuggestedTags(viewModel: ViewModels_Scan.ScanViewModel) {
            guard let suggestions = viewModel.aiSuggestions?.suggestedTags else { return }
            
            print("🏷️ [SDV_TagsHelpers] Applying all \(suggestions.count) suggested tags")
            
            for tag in suggestions {
                // Use the proper method that maintains correct state flow
                viewModel.createAndSelectTag(name: tag)
            }
        }
        
        // Helper to compute tag items for display
        @MainActor
        static func getSelectedTagItems(viewModel: ViewModels_Scan.ScanViewModel) -> [Views_SaveDocument.TagItem] {
            let existingTags = viewModel.metadataManager.tags.filter { 
                viewModel.metadataManager.selectedTagIds.contains($0.id) 
            }
            
            let pendingTags = viewModel.metadataManager.pendingTagNamesById
                .filter { viewModel.metadataManager.selectedTagIds.contains($0.key) }
                .map { Views_SaveDocument.TagItem(id: $0.key, name: $0.value) }
            
            let combined = existingTags.map { Views_SaveDocument.TagItem(id: $0.id, name: $0.name) } + pendingTags.filter { pendingTag in
                !existingTags.contains { $0.id == pendingTag.id }
            }
            
            return combined.sorted { $0.name < $1.name }
        }
    }
}

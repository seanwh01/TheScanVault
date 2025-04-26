import SwiftUI
import CoreData
import Combine

// Tag management view for SaveDocumentView - extracted as part of Phase 3 refactoring
// This ensures UI consistency with DocumentDetailView tag management
extension Views_SaveDocument {
    struct SDV_TagsView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Binding var tagsText: String
        @Binding var showTagConfirmation: Bool
        @EnvironmentObject private var subscriptionManager: SubscriptionManager
        
        // Toggle for showing the tag entry sheet
        @Binding var showTagEditSheet: Bool
        
        var body: some View {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        if viewModel.selectedTagIds.isEmpty {
                            Text("No tags")
                                .foregroundColor(.gray)
                        } else {
                            TagListView(
                                selectedTagIds: viewModel.metadataManager.selectedTagIds,
                                pendingTagNames: Array(viewModel.metadataManager.pendingTagNamesById.values),
                                allTags: viewModel.metadataManager.tags,
                                onRemoveTagId: { tagId in
                                    // Log before removal
                                    print("⚠️ [SDV_TagsView] Removing tag ID: \(tagId)")
                                    print("⚠️ Before removal: selected tags = \(viewModel.metadataManager.selectedTagIds.count)")
                                    
                                    // CRITICAL: This pattern must be preserved for proper tag deletion handling
                                    // It uses metadataManager.toggleTagSelection as the single source of truth
                                    // This is what fixed the tag deletion bug mentioned in the memories
                                    viewModel.metadataManager.toggleTagSelection(tagId)
                                    
                                    // Force UI updates on main thread
                                    DispatchQueue.main.async {
                                        // Critical: Update view model from metadata manager
                                        viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
                                        
                                        // Log after operation 
                                        print("✅ After removal: selected tags = \(viewModel.metadataManager.selectedTagIds.count)")
                                        
                                        // Force view to update
                                        viewModel.objectWillChange.send()
                                    }
                                },
                                onRemovePendingTag: { tagName in
                                    // Find the tag ID for this pending tag name
                                    if let tagId = viewModel.metadataManager.pendingTagNamesById.first(where: { $0.value == tagName })?.key {
                                        print("⚠️ [SDV_TagsView] Removing pending tag: \(tagName) with ID: \(tagId)")
                                        viewModel.metadataManager.removePendingTag(byId: tagId)
                                        
                                        // Force UI updates on main thread
                                        DispatchQueue.main.async {
                                            viewModel.objectWillChange.send()
                                        }
                                    }
                                }
                            )
                        }
                    }
                    Spacer()
                    Text("Add Tags")
                        .foregroundColor(.blue)
                        .onTapGesture {
                            showTagEditSheet = true
                        }
                }
                
                // AI suggestions for tags - preserve the UI pattern from DocumentDetailView
                if subscriptionManager.isPremium && UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                    if let suggestions = viewModel.aiSuggestions?.suggestedTags, !suggestions.isEmpty {
                        Text("AI Suggestions:")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                            
                        ForEach(suggestions, id: \.self) { suggestion in
                            HStack {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Spacer()
                                Button("Use Tag") {
                                    selectSuggestedTag(suggestion)
                                }
                                .font(.subheadline)
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        // Apply all tags button
                        if suggestions.count > 1 {
                            HStack {
                                Spacer()
                                Button("Apply All Tags") {
                                    applyAllSuggestedTags()
                                }
                                .font(.subheadline)
                                .buttonStyle(.bordered)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            } header: {
                Text("TAGS")
            }
        }
        
        // Handle suggested tag selection - implements the critical fix from memories
        // Uses viewModel.createAndSelectTag(name:) instead of directly manipulating selectedTagIds
        private func selectSuggestedTag(_ tagName: String) {
            print("🏷️ [SDV_TagsView] User selected suggested tag: \(tagName)")
            
            // CRITICAL: This method of adding tags was fixed according to the memory
            // "Using viewModel.createAndSelectTag rather than directly manipulating viewModel.selectedTagIds"
            viewModel.createAndSelectTag(name: tagName)
            
            // Show the confirmation
            withAnimation {
                showTagConfirmation = true
            }
            
            // Hide it after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // Use notification to avoid capturing binding in escaping closure
                    NotificationCenter.default.post(
                        name: Notification.Name("HideTagConfirmation"),
                        object: nil
                    )
                }
            }
        }
        
        // Apply all AI suggested tags
        private func applyAllSuggestedTags() {
            guard let suggestions = viewModel.aiSuggestions?.suggestedTags else { return }
            
            print("🏷️ [SDV_TagsView] Applying all \(suggestions.count) suggested tags")
            
            for tag in suggestions {
                // Use the proper method that maintains correct state flow
                viewModel.createAndSelectTag(name: tag)
            }
            
            // Show confirmation
            withAnimation {
                showTagConfirmation = true
            }
            
            // Hide it after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    NotificationCenter.default.post(
                        name: Notification.Name("HideTagConfirmation"),
                        object: nil
                    )
                }
            }
        }
    }
}

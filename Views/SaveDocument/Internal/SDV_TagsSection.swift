import SwiftUI
import CoreData
import Combine

// Tag management section for SaveDocumentView - extracted as a first step in refactoring
// This follows the same interaction patterns as DocumentDetailView for tag management
extension Views_SaveDocument {
    struct SDV_TagsSection {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Binding var tagsText: String
        @Binding var showTagConfirmation: Bool
        @EnvironmentObject private var subscriptionManager: SubscriptionManager
        
        // This static function creates the tag management section but doesn't introduce a new View type
        // that would conflict with existing declarations - critical for avoiding compilation errors
        static func createTagsSection(viewModel: ViewModels_Scan.ScanViewModel, 
                                     tagsText: Binding<String>,
                                     showTagConfirmation: Binding<Bool>) -> some View {
            Section {
                VStack(alignment: .leading) {
                    // Use improved TagListView with blue tag capsules - critical for maintaining
                    // consistent UI patterns between SaveDocumentView and DocumentDetailView
                    TagListView(
                        selectedTagIds: viewModel.metadataManager.selectedTagIds,
                        pendingTagNames: Array(viewModel.metadataManager.pendingTagNamesById.values),
                        allTags: viewModel.metadataManager.tags,
                        onRemoveTagId: { tagId in
                            // Log before removal
                            print("⚠️ [SaveDocumentView] Removing tag ID: \(tagId)")
                            print("⚠️ Before removal: selected tags = \(viewModel.metadataManager.selectedTagIds.count)")
                            
                            // Use the metadata manager as the single source of truth
                            // This is the critical fix that addresses the tag deletion bug mentioned in the memory
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
                                print("⚠️ [SaveDocumentView] Removing pending tag: \(tagName) with ID: \(tagId)")
                                viewModel.metadataManager.removePendingTag(byId: tagId)
                                
                                // Force UI updates on main thread
                                DispatchQueue.main.async {
                                    viewModel.objectWillChange.send()
                                }
                            }
                        }
                    )
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            // Show tag edit sheet - This will be handled by the parent view
                        }) {
                            Text("Edit")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 4)
                    
                    // AI suggestions for tags - using the @AppStorage wrapper for the setting
                    // and accessing SubscriptionManager through the environment
                    if UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                        Text("AI Suggestions:")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        
                        ForEach(viewModel.suggestedTagNames ?? [], id: \.self) { suggestion in
                            HStack {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Spacer()
                                Button("Use Tag") {
                                    selectSuggestedTag(viewModel: viewModel, tagName: suggestion, showConfirmation: showTagConfirmation)
                                }
                                .font(.subheadline)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            } header: {
                Text("TAGS")
            }
        }
        
        // Handle a suggested tag selection - implements the fix from memory
        // Uses viewModel.createAndSelectTag(name:) instead of directly manipulating selectedTagIds
        static private func selectSuggestedTag(viewModel: ViewModels_Scan.ScanViewModel, 
                                             tagName: String,
                                             showConfirmation: Binding<Bool>) {
            print("🏷️ [TagsSection] User selected suggested tag: \(tagName)")
            
            // This method of adding tags was fixed according to the memory:
            // "Using viewModel.addTagById rather than directly manipulating viewModel.selectedTagIds"
            viewModel.createAndSelectTag(name: tagName)
            
            // Show the confirmation
            withAnimation {
                showConfirmation.wrappedValue = true
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
    }
}

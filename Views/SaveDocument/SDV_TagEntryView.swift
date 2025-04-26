import SwiftUI
import CoreData
import Combine

// Tag entry view for SaveDocumentView - extracted as part of refactoring
// This maintains the same UI patterns as DocumentDetailView for tag management
extension Views_SaveDocument {
    struct SDV_TagEntryView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Environment(\.presentationMode) private var presentationMode
        @EnvironmentObject private var appServices: AppServices
        
        @State private var newTagText: String = ""
        @State private var tagError: String? = nil
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    Form {
                        Section {
                            HStack {
                                TextField("New Tag", text: $newTagText)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                Button(action: addTag) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                                .disabled(newTagText.isEmpty)
                            }
                            
                            if let error = tagError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        } header: {
                            Text("ADD TAG")
                        }
                        
                        Section {
                            ForEach(viewModel.metadataManager.tags) { tag in
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Button(action: {
                                        selectTag(Views_SaveDocument.TagItem(id: tag.id, name: tag.name))
                                    }) {
                                        Image(systemName: viewModel.metadataManager.selectedTagIds.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        } header: {
                            Text("EXISTING TAGS")
                        }
                    }
                }
                .navigationBarTitle("Manage Tags", displayMode: .inline)
                .navigationBarItems(
                    trailing: Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        
        // MARK: - Actions
        
        private func addTag() {
            guard !newTagText.isEmpty else { return }
            
            // Check if the tag already exists
            let trimmedName = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if the tag already exists by name - manually since tagExists method isn't available
            let tagAlreadyExists = viewModel.metadataManager.tags.contains { 
                $0.name.lowercased() == trimmedName.lowercased()
            }
            
            if tagAlreadyExists {
                tagError = "Tag already exists"
                return
            }
            
            // Reset error
            tagError = nil
            
            // Create and select the tag using the critical proper flow pattern
            // This maintains the fix for the tag deletion bug
            viewModel.createAndSelectTag(name: trimmedName)
            
            // Clear input
            newTagText = ""
            
            // Log for debugging
            print("✅ Added tag: \(trimmedName)")
            print("Currently selected tags: \(viewModel.metadataManager.selectedTagIds.map { $0.uuidString }.joined(separator: ", "))")
        }
        
        private func selectTag(_ tag: TagItem) {
            // Use the proper method that fixed the tag deletion bug
            viewModel.metadataManager.toggleTagSelection(tag.id)
            
            // Update VM from manager (source of truth)
            viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
            
            // Force UI refresh
            DispatchQueue.main.async {
                viewModel.objectWillChange.send()
            }
        }
    }
}

import SwiftUI
import CoreData
import TheScanVault // Assuming ScanViewModel is defined in TheScanVault module

// View for editing document tags during save process
struct SaveTagsEditView: View {
    @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel // Use fully qualified name
    @Environment(\.presentationMode) var presentationMode
    @State private var newTagName = ""
    
    // Track temporary tag selections locally within this sheet
    @State private var tempSelectedTagIds: Set<UUID>
    @State private var tempNewTagNames: [String] = [] // Tags to be created on save
    
    init(viewModel: ViewModels_Scan.ScanViewModel) {
        self.viewModel = viewModel
        // Initialize local state with ViewModel's current selection
        _tempSelectedTagIds = State(initialValue: viewModel.selectedTagIds)
        // We don't initialize tempNewTagNames from viewModel.pendingTagsToCreate
        // because those might be from previous edits; this sheet starts fresh.
    }
    
    var body: some View {
        NavigationView {
            List {
                // CURRENTLY SELECTED/ADDED TAGS section
                Section(header: Text("SELECTED TAGS")) {
                    if tempSelectedTagIds.isEmpty && tempNewTagNames.isEmpty {
                        Text("No tags selected")
                            .italic()
                            .foregroundColor(.gray)
                    } else {
                        // Show existing tags selected (based on IDs)
                        ForEach(getSortedSelectedTagItems(), id: \.id) { tagItem in
                            tagRow(tagItem: tagItem)
                        }
                        
                        // Show newly added tags (to be created)
                        ForEach(tempNewTagNames.sorted(), id: \.self) { tagName in
                            newTagRow(tagName: tagName)
                        }
                    }
                }
                
                // ADD NEW TAG section
                Section(header: Text("CREATE NEW TAG")) {
                    HStack {
                        TextField("Tag Name", text: $newTagName)
                            .autocapitalization(.none)
                        
                        Button(action: { addNewTagToList() }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                // AVAILABLE TAGS section
                Section(header: Text("AVAILABLE TAGS")) {
                    ForEach(getSortedAvailableTags(), id: \.id) { tagItem in
                        availableTagRow(tagItem: tagItem)
                    }
                }
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Save the tags and dismiss
                        saveTagChanges()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // ---- Helper Views ----
    
    private func tagRow(tagItem: TagItem) -> some View {
        HStack {
            Text(tagItem.name)
            Spacer()
            Button(action: { tempSelectedTagIds.remove(tagItem.id) }) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            }
        }
    }
    
    private func newTagRow(tagName: String) -> some View {
        HStack {
            Text(tagName)
            Image(systemName: "star.fill").foregroundColor(.orange).font(.caption) // Indicate new
            Spacer()
            Button(action: { tempNewTagNames.removeAll { $0 == tagName } }) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            }
        }
    }
    
    private func availableTagRow(tagItem: TagItem) -> some View {
        Button(action: { tempSelectedTagIds.insert(tagItem.id) }) {
            HStack {
                Text(tagItem.name)
                Spacer()
                Image(systemName: "plus.circle").foregroundColor(.blue)
            }
        }
        // Disable if already selected or pending creation
        .disabled(tempSelectedTagIds.contains(tagItem.id) || tempNewTagNames.contains(tagItem.name))
        .foregroundColor(tempSelectedTagIds.contains(tagItem.id) || tempNewTagNames.contains(tagItem.name) ? .gray : .primary)
    }
    
    // ---- Logic ----
    
    // Gets TagItem objects for currently selected IDs, sorted
    private func getSortedSelectedTagItems() -> [TagItem] {
        viewModel.metadataManager.tags
            .filter { tempSelectedTagIds.contains($0.id) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    // Gets available tags (not selected or pending), sorted
    private func getSortedAvailableTags() -> [TagItem] {
        viewModel.metadataManager.tags
            .filter { !tempSelectedTagIds.contains($0.id) && !tempNewTagNames.contains($0.name) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    // Adds the current input to the temporary new tag list
    private func addNewTagToList() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              !tempNewTagNames.contains(trimmedName),
              !viewModel.metadataManager.tags.contains(where: { $0.name == trimmedName }) else {
            // Maybe show an alert if tag exists or is already pending?
            newTagName = "" // Clear input even if not added
            return
        }
        tempNewTagNames.append(trimmedName)
        newTagName = ""
    }
    
    // Updates the ViewModel with the selections made in this sheet
    private func saveTagChanges() {
        print("🏷️ SaveTagsEditView - Beginning tag save...")
        print("   - Current tags in tempSelectedTagIds: \(tempSelectedTagIds.count)")
        print("   - Current tags in tempNewTagNames: \(tempNewTagNames.count)")
        
        // First, update the selected tag IDs in both the ViewModel and MetadataManager
        viewModel.selectedTagIds = tempSelectedTagIds
        viewModel.metadataManager.selectedTagIds = tempSelectedTagIds
        
        // Clear any previously pending tags from the manager and add the new ones
        viewModel.metadataManager.clearPendingTags()
        
        // Add new tags to the pending list
        for tagName in tempNewTagNames {
            print("   - Adding pending tag: \(tagName)")
            // Add to pending, ViewModel/Manager handles actual creation later
            if let tagId = viewModel.metadataManager.addPendingTag(name: tagName) {
                print("     ✓ Created pending tag ID: \(tagId)")
                
                // Also add the pending tag ID to the selected IDs
                viewModel.selectedTagIds.insert(tagId)
                viewModel.metadataManager.selectedTagIds.insert(tagId)
            }
        }
        
        // Force view model to update its state
        viewModel.objectWillChange.send()
        
        print("🏷️ SaveTagsEditView saved. Final state:")
        print("   - VM selectedTagIds: \(viewModel.selectedTagIds.count)")
        print("   - MM selectedTagIds: \(viewModel.metadataManager.selectedTagIds.count)")
        print("   - Pending tags: \(viewModel.metadataManager.pendingTagNamesById.count)")
    }
}

// Preview requires providing a mock ScanViewModel
struct SaveTagsEditView_Previews: PreviewProvider {
    
    static var previews: some View {
        // Create real services for preview (assuming simple initializers)
        // Adjust if AppServices/SubscriptionManager require complex setup
        let previewAppServices = AppServices(persistenceController: PersistenceController.preview) // Provide persistenceController
        let previewSubManager = SubscriptionManager() 
        
        // Create a mock ScanViewModel using the real services
        let mockViewModel = ViewModels_Scan.ScanViewModel(
            appServices: previewAppServices, 
            subscriptionManager: previewSubManager
        )
        
        // Populate preview data
        let context = previewAppServices.persistenceController.container.viewContext // Use context from real services
        let tag1 = Tag(context: context)
        tag1.id = UUID()
        tag1.name = "Important"
        let tag2 = Tag(context: context)
        tag2.id = UUID()
        tag2.name = "Receipt"
        
        // Manually set the tags in the manager for the preview
        mockViewModel.metadataManager.tags = [ 
            TagItem(id: tag1.id!, name: tag1.name!), 
            TagItem(id: tag2.id!, name: tag2.name!)
        ]
        
        // Pre-select one tag in the ViewModel
        mockViewModel.selectedTagIds = [tag1.id!]

        return SaveTagsEditView(viewModel: mockViewModel)
    }
}

// Helper extension if needed for preview
extension Tag {
    func toTagItem() -> TagItem {
        return TagItem(id: self.id ?? UUID(), name: self.name ?? "Unknown Tag")
    }
}

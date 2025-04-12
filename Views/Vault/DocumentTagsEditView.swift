import SwiftUI
import CoreData

// View for editing document tags
struct DocumentTagsEditView: View {
    @ObservedObject var viewModel: DocumentViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var newTagName = ""
    
    // Track temporary tag selections
    @State private var tempSelectedTags: Set<Tag> = []
    @State private var tempNewTags: [String] = []
    
    init(viewModel: DocumentViewModel) {
        self.viewModel = viewModel
        
        // Initialize with current tags
        if let currentTags = viewModel.document?.tags as? Set<Tag> {
            _tempSelectedTags = State(initialValue: currentTags)
        }
    }
    
    var body: some View {
        List {
            // CURRENT TAGS section
            Section(header: Text("CURRENT TAGS")) {
                if tempSelectedTags.isEmpty && tempNewTags.isEmpty {
                    Text("No tags")
                        .italic()
                        .foregroundColor(.gray)
                } else {
                    // Show existing tags
                    ForEach(Array(tempSelectedTags), id: \.id) { tag in
                        HStack {
                            Text(tag.name ?? "")
                            Spacer()
                            Button(action: {
                                // Remove tag from temp selection
                                tempSelectedTags.remove(tag)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Show newly added tags
                    ForEach(tempNewTags, id: \.self) { tagName in
                        HStack {
                            Text(tagName)
                            Spacer()
                            Button(action: {
                                // Remove from temp new tags
                                tempNewTags.removeAll { $0 == tagName }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            // ADD NEW TAG section
            Section(header: Text("ADD NEW TAG")) {
                HStack {
                    TextField("Tag Name", text: $newTagName)
                    
                    Button(action: {
                        if !newTagName.isEmpty {
                            // Just add to the temp new tags list, don't create in database yet
                            tempNewTags.append(newTagName)
                            newTagName = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newTagName.isEmpty)
                }
            }
            
            // AVAILABLE TAGS section
            Section(header: Text("AVAILABLE TAGS")) {
                ForEach(viewModel.availableTags) { tag in
                    Button(action: {
                        // Find the actual Tag object
                        if let tagEntity = findTagEntity(withId: tag.id) {
                            // Add to temporary selection
                            tempSelectedTags.insert(tagEntity)
                        }
                    }) {
                        HStack {
                            Text(tag.name)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                    }
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
                Button("Save") {
                    // Save changes to the document
                    saveTagChanges()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    // Helper to find Tag entity by ID
    private func findTagEntity(withId id: UUID) -> Tag? {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let context = PersistenceController.shared.container.viewContext
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Error finding tag: \(error)")
            return nil
        }
    }
    
    // Save all tag changes
    private func saveTagChanges() {
        // First remove all existing tags
        if let existingTags = viewModel.document?.tags as? Set<Tag>, !existingTags.isEmpty {
            viewModel.document?.removeFromTags(existingTags as NSSet)
        }
        
        // Add all selected tags
        for tag in tempSelectedTags {
            viewModel.document?.addToTags(tag)
        }
        
        // Create and add all new tags
        for tagName in tempNewTags {
            viewModel.createAndAddTag(name: tagName)
        }
        
        // Mark document as changed and save
        viewModel.hasChanges = true
        viewModel.saveTags(sendNotification: false)
    }
} 
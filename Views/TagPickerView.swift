import SwiftUI
import CoreData

struct TagPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext

    @Binding var selectedTagIDs: Set<UUID>
    var onDismiss: (() -> Void)? // Optional callback when dismissed

    // Fetch request for all tags
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default)
    private var tags: FetchedResults<Tag>

    // State for creating a new tag
    @State private var newTagName: String = ""

    var body: some View {
        NavigationView {
            List {
                // Section for creating new tags
                Section("Create New Tag") {
                    HStack {
                        TextField("New Tag Name", text: $newTagName)
                        Button("Create") {
                            createNewTag()
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                // Section for selecting existing tags
                Section("Select Tags") {
                    ForEach(tags) { tag in
                        HStack {
                            Text(tag.name ?? "Unnamed Tag")
                            Spacer()
                            if selectedTagIDs.contains(tag.id!) { // Force unwrap ID
                                Image(systemName: "checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(for: tag.id!) // Force unwrap ID
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                        onDismiss?() // Call dismiss handler
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                        onDismiss?() // Call dismiss handler
                    }
                }
            }
        }
         // Pass environment objects if needed by subviews
         .environment(\.managedObjectContext, viewContext)
    }

    // Toggle selection for a tag ID
    private func toggleSelection(for tagId: UUID) {
        if selectedTagIDs.contains(tagId) {
            selectedTagIDs.remove(tagId)
        } else {
            selectedTagIDs.insert(tagId)
        }
    }

    // Create a new tag
    private func createNewTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Check if tag already exists (case-insensitive)
        if let existingTag = tags.first(where: { $0.name?.lowercased() == trimmedName.lowercased() }) {
             // Select existing tag if not already selected
             if !selectedTagIDs.contains(existingTag.id!) {
                 selectedTagIDs.insert(existingTag.id!)
             }
        } else {
            // Create new tag
            let newTag = Tag(context: viewContext)
            newTag.id = UUID() // Assign a new UUID
            newTag.name = trimmedName
            newTag.createdAt = Date() // Set creation date

            do {
                try viewContext.save()
                selectedTagIDs.insert(newTag.id!) // Select the newly created tag
                print(" New tag created and selected: \(trimmedName)")
            } catch {
                // Handle the Core Data save error
                print(" Error saving new tag: \(error.localizedDescription)")
                // Optionally: Remove the failed tag object from context if needed
                 viewContext.delete(newTag)
            }
        }
        // Clear the input field
        newTagName = ""
    }
}

// Basic Preview
struct TagPickerView_Previews: PreviewProvider {
    @State static var previewSelectedTagIDs: Set<UUID> = []

    static var previews: some View {
        TagPickerView(selectedTagIDs: $previewSelectedTagIDs) {
            print("Preview dismissed. Selected IDs: \(previewSelectedTagIDs)")
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

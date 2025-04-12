import SwiftUI
import CoreData

// Document Details Sheet for editing document metadata
struct DocumentDetailsSheet: View {
    @ObservedObject var viewModel: DocumentViewModel
    @State private var showTagPicker = false
    @State private var showFolderPicker = false
    @State private var editedTitle: String
    @State private var editedComments: String
    @Environment(\.presentationMode) var presentationMode
    
    init(viewModel: DocumentViewModel) {
        self.viewModel = viewModel
        _editedTitle = State(initialValue: viewModel.document?.title ?? "")
        _editedComments = State(initialValue: viewModel.document?.comments ?? "")
    }
    
    // Add this computed property to handle the page count logic
    private var pageCount: Int {
        if viewModel.documentPages.isEmpty {
            return viewModel.previewImage != nil ? 1 : 0
        } else {
            return viewModel.documentPages.count
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                titleSection
                folderSection
                tagsSection
                commentsSection
                documentInfoSection
            }
            .navigationTitle("Document Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
            }
            .sheet(isPresented: $showTagPicker) {
                tagPickerSheet
            }
            .sheet(isPresented: $showFolderPicker, onDismiss: {
                viewModel.refreshFolderName()
            }) {
                folderPickerSheet
            }
        }
    }
    
    // Navigation bar buttons
    private var cancelButton: some View {
        Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private var saveButton: some View {
        Button("Save") {
            saveDocumentChanges()
        }
    }
    
    // Sheet contents
    private var tagPickerSheet: some View {
        NavigationView {
            DocumentTagsEditView(viewModel: viewModel)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var folderPickerSheet: some View {
        NavigationView {
            DocumentFolderEditView(viewModel: viewModel)
        }
    }
    
    // Save action method
    private func saveDocumentChanges() {
        print("💾 Saving document with title: \(editedTitle)")
        
        // Update values in the view model
        viewModel.titleEdit = editedTitle
        viewModel.comments = editedComments
        
        // Save changes without sending ANY notifications
        viewModel.saveLocallyWithoutNotifications()
        
        // Dismiss the sheet first
        presentationMode.wrappedValue.dismiss()
        
        // Temporarily disable notification handling
        NotificationCenter.default.post(
            name: NSNotification.Name("PauseDocumentNotifications"),
            object: nil,
            userInfo: ["pauseDuration": 3.0]
        )
    }
    
    // Title section
    private var titleSection: some View {
        Section(header: Text("Title")) {
            TextField("Document Title", text: $editedTitle)
        }
    }
    
    // Folder section
    private var folderSection: some View {
        Section(header: Text("Folder")) {
            HStack {
                Text(viewModel.folderName ?? "No Folder Assigned")
                Spacer()
                Button("Change") {
                    showFolderPicker = true
                }
            }
        }
    }
    
    // Tags section
    private var tagsSection: some View {
        Section(header: Text("Tags")) {
            if let tags = viewModel.document?.tags as? Set<Tag>, !tags.isEmpty {
                ForEach(Array(tags), id: \.id) { tag in
                    tagRow(tag: tag)
                }
            } else {
                Text("No tags")
                    .italic()
                    .foregroundColor(.gray)
            }
            
            Button("Add Tags") {
                showTagPicker = true
            }
        }
    }
    
    // Helper for tag row
    private func tagRow(tag: Tag) -> some View {
        HStack {
            Text(tag.name ?? "")
            Spacer()
            Button(action: {
                viewModel.removeTag(tag)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    // Comments section
    private var commentsSection: some View {
        Section(header: Text("Comments")) {
            TextEditor(text: $editedComments)
                .frame(minHeight: 100)
        }
    }
    
    // Document info section
    private var documentInfoSection: some View {
        Section(header: Text("Document Information")) {
            // Pages row
            HStack {
                Text("Pages:")
                Spacer()
                Text("\(pageCount)")
            }
            
            // Created date
            createdDateRow
            
            // Modified date if available
            if let updatedAt = viewModel.document?.updatedAt {
                modifiedDateRow(date: updatedAt)
            }
        }
    }
    
    // Date rows as separate properties
    private var createdDateRow: some View {
        HStack {
            Text("Created:")
            Spacer()
            Text(formattedCreationDate)
                .foregroundColor(.gray)
        }
    }
    
    private func modifiedDateRow(date: Date) -> some View {
        HStack {
            Text("Last Modified:")
            Spacer()
            Text(date.formatted(date: .long, time: .shortened))
                .foregroundColor(.gray)
        }
    }
    
    // Helper for formatted creation date
    private var formattedCreationDate: String {
        viewModel.document?.createdAt?.formatted(date: .long, time: .shortened) ?? ""
    }
} 
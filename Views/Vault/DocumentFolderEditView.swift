import SwiftUI
import CoreData

// View for selecting document folder
struct DocumentFolderEditView: View {
    @ObservedObject var viewModel: DocumentViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var newFolderName = ""
    @State private var selectedFolderId: UUID?
    @State private var showNewFolderField = false
    
    // Break complex expression into simpler parts
    var body: some View {
        List {
            // No Folder option
            Section(header: Text("NO FOLDER")) {
                noFolderButton
            }
            
            // Existing folders section
            Section(header: Text("FOLDERS")) {
                // Create new folder option
                if !showNewFolderField {
                    createNewFolderButton
                } else {
                    newFolderField
                }
                
                // List existing folders
                foldersList
            }
        }
        .onAppear {
            // Initialize selected folder
            selectedFolderId = viewModel.document?.folderId
        }
        .navigationTitle("Select Folder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                cancelButton
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                saveButton
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
            // Use setFolder method instead of updateFolder
            viewModel.setFolder(id: selectedFolderId, name: getSelectedFolderName())
            viewModel.saveFolder(sendNotification: false)
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // Helper to get folder name from id
    private func getSelectedFolderName() -> String? {
        guard let id = selectedFolderId else { return nil }
        return viewModel.allFolders.first(where: { $0.id == id })?.name
    }
    
    // No folder option
    private var noFolderButton: some View {
        Button(action: {
            selectedFolderId = nil
        }) {
            HStack {
                Text("No Folder Assigned")
                    .foregroundColor(.primary)
                Spacer()
                if selectedFolderId == nil {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // Create new folder button
    private var createNewFolderButton: some View {
        Button("Create New Folder") {
            showNewFolderField = true
        }
        .foregroundColor(.blue)
    }
    
    // New folder field
    private var newFolderField: some View {
        HStack {
            TextField("Folder Name", text: $newFolderName)
            
            Button(action: {
                if !newFolderName.isEmpty {
                    createNewFolder()
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
            .disabled(newFolderName.isEmpty)
            
            Button(action: {
                // Cancel new folder creation
                showNewFolderField = false
                newFolderName = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    // Folders list
    private var foldersList: some View {
        ForEach(viewModel.allFolders, id: \.id) { folder in
            Button(action: {
                selectedFolderId = folder.id
            }) {
                HStack {
                    Text(folder.name)
                        .foregroundColor(.primary)
                    Spacer()
                    if selectedFolderId == folder.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    // Create a new folder
    private func createNewFolder() {
        // Create a new folder in the context
        let context = PersistenceController.shared.container.viewContext
        let newFolder = Folder(context: context)
        newFolder.id = UUID()
        newFolder.name = newFolderName
        newFolder.createdAt = Date()
        
        // Save the context
        do {
            try context.save()
            
            // Reload folders using existing method
            viewModel.reloadData()
            
            // Select the new folder
            selectedFolderId = newFolder.id
            
            // Reset UI
            showNewFolderField = false
            newFolderName = ""
        } catch {
            print("Error creating new folder: \(error)")
        }
    }
} 
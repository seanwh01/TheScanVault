import SwiftUI
import CoreData

// View for selecting document folder during save process
struct SaveFolderEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel // Use fully qualified name
    @State private var newFolderName = ""
    @State private var showNewFolderField = false
    @State private var showingCreateFolderAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // No Folder option
                Section(header: Text("NO FOLDER")) {
                    Button(action: {
                        viewModel.selectedFolderId = nil
                        dismiss()
                    }) {
                        HStack {
                            Text("No Folder")
                            Spacer()
                            if viewModel.selectedFolderId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundColor(.primary) // Ensure it looks tappable
                }
                
                // Existing folders section
                Section {
                    // Ensure folders is accessed correctly from the viewModel's metadataManager
                    // Also ensure FolderItem conforms to Identifiable if not already
                    ForEach(viewModel.metadataManager.folders) { folder in // Use manager's folders
                        Button(action: {
                            // Assign the folder's ID directly to the ViewModel's property
                            viewModel.selectedFolderId = folder.id
                            dismiss()
                        }) {
                            HStack {
                                // Display the folder name correctly
                                Text(folder.name)
                                Spacer()
                                if viewModel.selectedFolderId == folder.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .foregroundColor(.primary) // Ensure text color is appropriate
                        }
                    }
                } header: {
                    Text("FOLDERS")
                }
                
                // Section for creating a new folder
                Section(header: Text("CREATE NEW FOLDER")) {
                    // Create new folder option
                    if !showNewFolderField {
                        createNewFolderButton
                    } else {
                        newFolderField
                    }
                }
            }
            .onAppear {
                print("SaveFolderEditView appeared. ViewModel selected folder ID: \(viewModel.selectedFolderId?.uuidString ?? "nil")")
            }
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // This view already dismisses when a selection is made,
                        // but having a Done button provides consistency with other sheets
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Navigation bar buttons
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }
    
    private var saveButton: some View {
        Button("Save") {
            // No need to update viewModel here, selection buttons do it directly
            dismiss()
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
                    if let newFolder = viewModel.metadataManager.createFolder(name: newFolderName) {
                        viewModel.selectedFolderId = newFolder.id
                        dismiss()
                    } else {
                        showingCreateFolderAlert = true
                    }
                    showNewFolderField = false
                    newFolderName = ""
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
            .disabled(newFolderName.isEmpty)
            
            Button(action: {
                showNewFolderField = false
                newFolderName = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

// Preview Requires Mock ViewModel
struct SaveFolderEditView_Previews: PreviewProvider {
    static var previews: some View {
        // Create real services for preview
        let previewAppServices = AppServices(persistenceController: PersistenceController.preview)
        let previewSubManager = SubscriptionManager()
        
        // Create a mock ScanViewModel using the real services
        let mockViewModel = ViewModels_Scan.ScanViewModel(
            appServices: previewAppServices, 
            subscriptionManager: previewSubManager
        )
        
        // Populate preview data (folders)
        let context = previewAppServices.persistenceController.container.viewContext
        let folder1 = Folder(context: context)
        folder1.id = UUID()
        folder1.name = "Work Documents"
        let folder2 = Folder(context: context)
        folder2.id = UUID()
        folder2.name = "Home Stuff"
        
        // Manually set the folders in the manager for the preview
        // NOTE: This requires `folders` setter in ScanMetadataManager to be accessible
        // If it's `private(set)`, this needs adjustment or removal.
        mockViewModel.metadataManager.folders = [
            FolderItem(id: folder1.id!, name: folder1.name!),
            FolderItem(id: folder2.id!, name: folder2.name!)
        ]
        
        // Pre-select one folder in the ViewModel
        mockViewModel.selectedFolderId = folder1.id!
        
        return SaveFolderEditView(viewModel: mockViewModel)
    }
}

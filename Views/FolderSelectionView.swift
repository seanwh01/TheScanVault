import SwiftUI
import CoreData

struct FolderSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var folderViewModel = FolderViewModel()
    @Binding var selectedFolderId: UUID?
    @Binding var folderName: String?
    @State private var tempSelectedFolderId: UUID?
    @State private var tempFolderName: String?
    @State private var newFolderName = ""
    @State private var showInvalidNameAlert = false
    @State private var invalidNameMessage = ""
    var onSave: () -> Void
    
    // Reserved folder names that shouldn't be used
    private let reservedFolderNames = ["No Folder", "No Folder Assigned"]
    
    init(selectedFolderId: Binding<UUID?>, folderName: Binding<String?>, onSave: @escaping () -> Void = {}) {
        self._selectedFolderId = selectedFolderId
        self._folderName = folderName
        self.onSave = onSave
        
        // Initialize temporary selection with current values
        _tempSelectedFolderId = State(initialValue: selectedFolderId.wrappedValue)
        _tempFolderName = State(initialValue: folderName.wrappedValue)
    }
    
    var body: some View {
        List {
            Section(header: Text("Add New Folder")) {
                HStack {
                    TextField("Folder Name", text: $newFolderName)
                    
                    Button(action: {
                        if !newFolderName.isEmpty {
                            // Validate folder name
                            if reservedFolderNames.contains(newFolderName) {
                                invalidNameMessage = "'\(newFolderName)' is a reserved name and cannot be used as a folder name."
                                showInvalidNameAlert = true
                                return
                            }
                            
                            // Create new folder and select it temporarily
                            if let newFolder = folderViewModel.createFolder(name: newFolderName) {
                                tempSelectedFolderId = newFolder.id
                                tempFolderName = newFolder.name
                            }
                            newFolderName = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newFolderName.isEmpty)
                }
            }
            
            // Current folder section
            Section(header: Text("CURRENT FOLDER")) {
                HStack {
                    if let currentName = folderName {
                        Text(currentName)
                    } else {
                        Text("No Folder Assigned")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // No folder option
            Section(header: Text("No Folder Option")) {
                Button(action: {
                    // Only update temp selection to represent no folder
                    tempSelectedFolderId = nil
                    tempFolderName = nil
                }) {
                    HStack {
                        Text("No Folder Assigned")
                        Spacer()
                        if tempSelectedFolderId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // All available folders
            Section(header: Text("Select Folder")) {
                ForEach(folderViewModel.folders) { folder in
                    Button(action: {
                        // Only update temporary selection
                        tempSelectedFolderId = folder.id
                        tempFolderName = folder.name
                    }) {
                        HStack {
                            Text(folder.name)
                            Spacer()
                            if tempSelectedFolderId == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Folder")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    // Dismiss without saving changes
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    // Update the actual bindings
                    selectedFolderId = tempSelectedFolderId
                    folderName = tempFolderName
                    
                    // Execute the save callback
                    onSave()
                    
                    // Dismiss the view
                    presentationMode.wrappedValue.dismiss()
                }
                .bold()
            }
        }
        .alert(isPresented: $showInvalidNameAlert) {
            Alert(
                title: Text("Invalid Folder Name"),
                message: Text(invalidNameMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // Load all folders when view appears
            folderViewModel.loadFolders()
        }
    }
} 
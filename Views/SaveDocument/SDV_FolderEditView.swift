import SwiftUI
import CoreData
import Combine

// Folder edit view for SaveDocumentView - extracted as part of refactoring
// This maintains the same UI patterns as DocumentDetailView for folder management
extension Views_SaveDocument {
    struct SDV_FolderEditView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Environment(\.presentationMode) private var presentationMode
        @EnvironmentObject private var appServices: AppServices
        
        @State private var newFolderName: String = ""
        @State private var folderError: String? = nil
        
        // Computed property for folder items that handles the type conversion
        private var folders: [FolderItem] {
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
            
            do {
                let folders = try context.fetch(fetchRequest)
                return folders.compactMap { folder -> FolderItem? in
                    guard let id = folder.id, let name = folder.name else { return nil }
                    return FolderItem(id: id, name: name)
                }
            } catch {
                print("Error loading folders: \(error)")
                return []
            }
        }
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    Form {
                        Section {
                            HStack {
                                TextField("New Folder", text: $newFolderName)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                Button(action: addFolder) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                                .disabled(newFolderName.isEmpty)
                            }
                            
                            if let error = folderError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        } header: {
                            Text("ADD FOLDER")
                        }
                        
                        Section {
                            // Option for no folder (matching the UI in the image)
                            HStack {
                                Text("No Folder Assigned")
                                    .foregroundColor(.gray)
                                Spacer()
                                Button(action: {
                                    clearFolderSelection()
                                }) {
                                    Image(systemName: viewModel.selectedFolderId == nil ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        } header: {
                            Text("NO FOLDER")
                        }
                        
                        Section {
                            ForEach(folders) { folder in
                                HStack {
                                    Text(folder.name)
                                    Spacer()
                                    Button(action: {
                                        selectFolder(folder)
                                    }) {
                                        Image(systemName: viewModel.selectedFolderId == folder.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        } header: {
                            Text("FOLDERS")
                        }
                    }
                }
                .navigationBarTitle("Manage Folders", displayMode: .inline)
                .navigationBarItems(
                    trailing: Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
        
        // MARK: - Actions
        
        private func addFolder() {
            guard !newFolderName.isEmpty else { return }
            
            // Check if the folder already exists
            let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if folders.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                folderError = "Folder already exists"
                return
            }
            
            // Reset error
            folderError = nil
            
            // Create and select the folder
            viewModel.createAndSelectFolder(name: trimmedName)
            
            // Clear input
            newFolderName = ""
            
            // Log for debugging
            print("✅ Added folder: \(trimmedName)")
        }
        
        private func selectFolder(_ folder: FolderItem) {
            // Update the selected folder
            viewModel.selectedFolderId = folder.id
            
            // Dismiss the sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                presentationMode.wrappedValue.dismiss()
            }
        }
        
        private func clearFolderSelection() {
            viewModel.selectedFolderId = nil
            viewModel.metadataManager.selectedFolderId = nil
            presentationMode.wrappedValue.dismiss()
        }
    }
}

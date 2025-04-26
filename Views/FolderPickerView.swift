import SwiftUI
import CoreData

@MainActor // Ensure UI updates are on the main thread
struct FolderPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var subscriptionManager: SubscriptionManager // Added based on SaveDocumentView usage
    @EnvironmentObject private var appServices: AppServices // Inject AppServices

    @Binding var selectedFolderId: UUID? // ID of the currently selected folder
    let onSelect: (UUID) -> Void // Callback when a folder is selected or created
    let showDefaultFolder: Bool // Whether to show the default folder option
    let createFolderAction: (String) -> FolderItem? // Action to create a new folder

    @State private var folders: [FolderItem] = []
    @State private var selectedFolderIdInternal: UUID? = nil
    @State private var showingAddFolderAlert = false
    @State private var newFolderName = ""

    // Fetch request for folders (adjust predicate as needed)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.name, ascending: true)],
        animation: .default)
    private var foldersCoreData: FetchedResults<Folder>

    init(selectedFolderId: Binding<UUID?>, onSelect: @escaping (UUID) -> Void, showDefaultFolder: Bool, createFolderAction: @escaping (String) -> FolderItem?) {
        _selectedFolderId = selectedFolderId
        self.onSelect = onSelect
        self.showDefaultFolder = showDefaultFolder
        self.createFolderAction = createFolderAction
        _selectedFolderIdInternal = State(initialValue: selectedFolderId.wrappedValue)
    }

    var body: some View {
        NavigationView {
            List {
                // Option for "No Folder"
                if showDefaultFolder {
                    HStack {
                        Text("No Folder")
                        Spacer()
                        if selectedFolderIdInternal == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle()) // Make entire row tappable
                    .onTapGesture {
                        selectedFolderIdInternal = nil
                    }
                }

                // Existing Folders
                ForEach(foldersCoreData) { folder in
                    HStack {
                        Image(systemName: "folder") // Show icon
                        Text(folder.name ?? "Unnamed Folder")
                        Spacer()
                        if selectedFolderIdInternal == folder.id {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFolderIdInternal = folder.id
                    }
                }
            }
            .navigationTitle("Select Folder")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSelect(selectedFolderIdInternal ?? UUID()) // Pass back the selected ID
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newFolderName = "" // Reset field
                        showingAddFolderAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add New Folder", isPresented: $showingAddFolderAlert) {
                TextField("Folder Name", text: $newFolderName)
                    .autocapitalization(.none)
                Button("Add") {
                    if !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Use the provided createFolderAction
                        if let createdFolderItem = createFolderAction(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)) {
                             // Extract the UUID from the FolderItem
                             let newFolderId = createdFolderItem.id
                             selectedFolderIdInternal = newFolderId // Select in picker
                             onSelect(newFolderId) // Update binding
                             presentationMode.wrappedValue.dismiss() // Close picker after adding and selecting
                         } else {
                             // Handle case where folder creation failed (e.g., duplicate name)
                             print("🚨 Folder creation failed or folder already exists.")
                             // Optionally show an error to the user
                         }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter the name for the new folder.")
            }
        }
        // Pass environment objects needed by the NavigationView or its contents
        .environment(\.managedObjectContext, viewContext)
        .environmentObject(subscriptionManager)
        .environmentObject(appServices)
    }
}

// Basic Preview
struct FolderPickerView_Previews: PreviewProvider {
    @State static var previewSelectedFolderId: UUID? = nil
    static let persistence = PersistenceController.preview // Use preview controller
    static let services = AppServices(persistenceController: persistence) // Create services

    static var previews: some View {
        NavigationView {
            FolderPickerView(
                selectedFolderId: $previewSelectedFolderId,
                onSelect: { id in print("Selected/Created Folder ID: \(id)") },
                showDefaultFolder: true,
                // Provide a dummy createFolderAction for the preview
                createFolderAction: { name in
                    print("Preview: Attempting to create folder named \(name)")
                    // Simulate success by returning a dummy FolderItem
                    let dummyId = UUID()
                    let dummyItem = FolderItem(id: dummyId, name: name)
                    // You could also simulate adding it to the preview AppServices manager if needed
                    // services.scanMetadataManager.folders.append(dummyItem) // Requires manager on AppServices
                    return dummyItem
                }
            )
            .environmentObject(services) // Pass services
        }
    }
}

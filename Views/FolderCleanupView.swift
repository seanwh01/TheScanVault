import SwiftUI
import CoreData

struct FolderCleanupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var unusedFolders: [Folder] = []
    @State private var isCleaning = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                if isCleaning {
                    HStack {
                        Spacer()
                        ProgressView("Cleaning up folders...")
                        Spacer()
                    }
                } else if unusedFolders.isEmpty {
                    Text("No unused folders found.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(unusedFolders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                            Text(folder.value(forKey: "name") as? String ?? "Unnamed Folder")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Folder Cleanup")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Clean Up") {
                    cleanupUnusedFolders()
                }
                .disabled(unusedFolders.isEmpty || isCleaning)
            )
            .onAppear {
                findUnusedFolders()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertTitle == "Success" {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func findUnusedFolders() {
        do {
            // Get all folders
            let folderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            let allFolders = try viewContext.fetch(folderFetchRequest)
            
            // Get all documents
            let documentFetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            let allDocuments = try viewContext.fetch(documentFetchRequest)
            
            // Collection of folder names actually in use
            var usedFolderNames = Set<String>()
            
            // Collect folder IDs that are actually referenced by documents
            for document in allDocuments {
                if let folderId = document.value(forKey: "folderId") as? String, !folderId.isEmpty {
                    usedFolderNames.insert(folderId)
                }
            }
            
            // Find unused folders
            unusedFolders = allFolders.filter { folder in
                let folderName = folder.value(forKey: "name") as? String ?? "unnamed"
                
                // Check if the folder name is used directly
                if usedFolderNames.contains(folderName) {
                    return false
                }
                
                // Check folder UUID
                if let folderUUID = folder.value(forKey: "id") as? UUID {
                    let uuidString = folderUUID.uuidString
                    if usedFolderNames.contains(uuidString) {
                        return false
                    }
                }
                
                // Extra safety check: look for partial matches or case-insensitive matches
                let caseInsensitiveMatch = usedFolderNames.contains { $0.lowercased() == folderName.lowercased() }
                if caseInsensitiveMatch {
                    return false
                }
                
                let partialMatch = usedFolderNames.contains { $0.contains(folderName) || folderName.contains($0) }
                if partialMatch {
                    return false
                }
                
                return true
            }
            
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to find unused folders: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func cleanupUnusedFolders() {
        isCleaning = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                for folder in unusedFolders {
                    viewContext.delete(folder)
                }
                
                try viewContext.save()
                
                alertTitle = "Success"
                alertMessage = "Successfully removed \(unusedFolders.count) unused folder(s)."
                showAlert = true
                
            } catch {
                alertTitle = "Error"
                alertMessage = "Failed to clean up folders: \(error.localizedDescription)"
                showAlert = true
            }
            
            isCleaning = false
        }
    }
} 
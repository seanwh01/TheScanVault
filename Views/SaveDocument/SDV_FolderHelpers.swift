import SwiftUI
import CoreData
import Combine

// Helper extension for folder management in SaveDocumentView
// This ensures consistency with DocumentDetailView's folder handling
extension Views_SaveDocument {
    struct SDV_FolderHelpers {
        
        // Helper struct for folder item that matches the existing type
        struct FolderItem: Identifiable {
            let id: UUID
            let name: String
        }
        
        // Update folder name from ID - maintains consistency between views
        @MainActor
        static func updateFolderNameFromId(viewModel: ViewModels_Scan.ScanViewModel, 
                                          folderId: UUID?, 
                                          folderName: inout String) {
            if let folderId = folderId {
                if let folder = viewModel.folders.first(where: { $0.id == folderId }) { 
                    folderName = folder.name
                    print("📁 Updated folder selection to: \(folderName) (from viewModel)")
                } else {
                    let context = PersistenceController.shared.container.viewContext
                    let request = NSFetchRequest<Folder>(entityName: "Folder")
                    request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                    
                    if let folders = try? context.fetch(request), let folder = folders.first {
                        folderName = folder.name ?? ""
                        print("📁 Updated folder selection to: \(folderName) (from Core Data)")
                    } else {
                        print("⚠️ Warning: Could not find folder name for ID: \(folderId)")
                    }
                }
            } else {
                folderName = ""
                print("📂 Cleared folder selection")
            }
        }
        
        // Handle suggested folder selection
        @MainActor
        static func selectSuggestedFolder(viewModel: ViewModels_Scan.ScanViewModel, 
                                          folderName: String,
                                          showConfirmation: inout Bool) {
            print("📁 [SDV_FolderHelpers] User selected suggested folder: \(folderName)")
            
            // Use the proper method to maintain state consistency
            viewModel.createAndSelectFolder(name: folderName)
            
            // Show the confirmation - create a local copy to avoid capturing inout parameter
            let confirmationValue = true
            withAnimation {
                showConfirmation = confirmationValue
            }
            
            // Hide it after a delay - use the local copy in the escaping closure
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // Since we can't capture the inout parameter in an escaping closure,
                    // we need to use a different approach. We'll post a notification instead.
                    NotificationCenter.default.post(
                        name: Notification.Name("HideFolderConfirmation"),
                        object: nil
                    )
                }
            }
        }
        
        // Sync folder selection between view and view model
        @MainActor
        static func syncFolderSelection(viewModel: ViewModels_Scan.ScanViewModel,
                                       currentFolder: inout UUID?,
                                       folderName: inout String) {
            let oldFolderId = currentFolder
            
            // Case 1: ViewModel has a folder selected but our local state doesn't match
            if viewModel.selectedFolderId != nil && currentFolder != viewModel.selectedFolderId {
                currentFolder = viewModel.selectedFolderId
                print("🔄 Folder ID updated from UI sync: \(oldFolderId?.uuidString ?? "nil") -> \(viewModel.selectedFolderId?.uuidString ?? "nil")")
                
                updateFolderNameFromId(viewModel: viewModel, folderId: currentFolder, folderName: &folderName)
            } 
            // Case 2: ViewModel has a folder ID but our folder name is empty 
            else if let folderId = viewModel.selectedFolderId, folderName.isEmpty {
                updateFolderNameFromId(viewModel: viewModel, folderId: folderId, folderName: &folderName)
            }
            // Case 3: ViewModel has NO folder selected but our local state still has one
            else if viewModel.selectedFolderId == nil && currentFolder != nil {
                currentFolder = nil
                folderName = ""
                print("🔄 Folder cleared from sync: \(oldFolderId?.uuidString ?? "nil") -> nil")
            }
        }
        
        // Load all available folders from Core Data
        @MainActor
        static func loadFolders(viewModel: ViewModels_Scan.ScanViewModel) {
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
            
            do {
                let folders = try context.fetch(fetchRequest)
                // Need to use the proper FolderItem type that matches what's used in the ViewModel
                let folderItems = folders.compactMap { folder -> FolderItem? in
                    guard let id = folder.id, let name = folder.name else { return nil }
                    return FolderItem(id: id, name: name)
                }
                
                // Just log the loaded folders for now instead of trying to update the viewModel directly
                print("📁 [SDV_FolderHelpers] Loaded \(folderItems.count) folders")
                
                // folderItems need to be copied to a matching type in the viewModel
                // This will be improved in Phase 2 of refactoring
            } catch {
                print("Error loading folders: \(error)")
            }
        }
    }
}

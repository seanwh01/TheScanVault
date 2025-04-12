import SwiftUI
import CoreData
import Combine

class FolderViewModel: ObservableObject {
    @Published var folders: [FolderItem] = []
    private let viewContext = PersistenceController.shared.container.viewContext
    
    func loadFolders() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let fetchedFolders = try viewContext.fetch(fetchRequest)
            folders = fetchedFolders.compactMap { folder in
                guard let id = folder.id, let name = folder.name else { return nil }
                return FolderItem(id: id, name: name)
            }
        } catch {
            print("Error loading folders: \(error)")
        }
    }
    
    func createFolder(name: String) -> FolderItem? {
        // Check for reserved names
        let reservedNames = ["No Folder", "No Folder Assigned"]
        if reservedNames.contains(name) {
            return nil
        }
        
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = name
        
        do {
            try viewContext.save()
            
            // Add to local array
            let newItem = FolderItem(id: newFolder.id!, name: name)
            folders.append(newItem)
            
            return newItem
        } catch {
            print("Error creating folder: \(error)")
            return nil
        }
    }
} 
import SwiftUI
import CoreData
import Combine

// Folder management view for SaveDocumentView - extracted as part of Phase 3 refactoring
// This ensures UI consistency with DocumentDetailView folder management
extension Views_SaveDocument {
    struct SDV_FolderView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Binding var selectedFolder: UUID?
        @Binding var selectedFolderName: String
        @Binding var showFolderConfirmation: Bool
        @Binding var showFolderEditSheet: Bool
        
        var body: some View {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(selectedFolderName.isEmpty ? "None Selected" : selectedFolderName)
                            .foregroundColor(selectedFolderName.isEmpty ? .gray : .primary)
                    }
                    Spacer()
                    Text("Select")
                        .foregroundColor(.blue)
                        .onTapGesture {
                            showFolderEditSheet = true
                        }
                }
                
                // Use suggestedFolderName for folder suggestions
                if let suggestedFolder = viewModel.aiSuggestions?.suggestedFolderName, !suggestedFolder.isEmpty {
                    Text("AI Suggestions:")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    
                    // Since it's a single suggestion, not an array, we don't need ForEach
                    HStack {
                        Text(suggestedFolder)
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                        Button("Use Folder") {
                            selectSuggestedFolder(suggestedFolder)
                        }
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                    }
                }
            } header: {
                Text("FOLDER")
            }
        }
        
        // Select a suggested folder with proper state flow
        private func selectSuggestedFolder(_ folderName: String) {
            print(" [SDV_FolderView] User selected suggested folder: \(folderName)")
            
            // Use the proper method to maintain state consistency
            viewModel.createAndSelectFolder(name: folderName)
            
            // Show the confirmation
            withAnimation {
                showFolderConfirmation = true
            }
            
            // Hide it after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // Use notification to avoid capturing binding in escaping closure
                    NotificationCenter.default.post(
                        name: Notification.Name("HideFolderConfirmation"),
                        object: nil
                    )
                }
            }
            
            // Sync the folder name after selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                updateFolderNameFromId()
            }
        }
        
        // Update folder name from ID - maintains consistency between views
        private func updateFolderNameFromId() {
            if let folderId = selectedFolder {
                if let folder = viewModel.folders.first(where: { $0.id == folderId }) { 
                    selectedFolderName = folder.name
                    print(" Updated folder selection to: \(selectedFolderName) (from viewModel)")
                } else {
                    let context = PersistenceController.shared.container.viewContext
                    let request = NSFetchRequest<Folder>(entityName: "Folder")
                    request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                    
                    if let folders = try? context.fetch(request), let folder = folders.first {
                        selectedFolderName = folder.name ?? ""
                        print(" Updated folder selection to: \(selectedFolderName) (from Core Data)")
                    } else {
                        print(" Warning: Could not find folder name for ID: \(folderId)")
                    }
                }
            } else {
                selectedFolderName = ""
                print(" Cleared folder selection")
            }
        }
    }
}

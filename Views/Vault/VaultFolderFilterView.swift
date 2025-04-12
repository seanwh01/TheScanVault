import SwiftUI

struct VaultFolderFilterView: View {
    @ObservedObject var viewModel: VaultViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Select/Deselect buttons
            HStack {
                Button(action: {
                    viewModel.selectAllFolders()
                }) {
                    Text("Select All")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.5))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    viewModel.deselectAllFolders()
                }) {
                    Text("Deselect All")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.5))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // Add padding between buttons and folder list
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 6)
            
            // "No Folder" option
            HStack {
                Image(systemName: viewModel.selectedFolderIds.contains(ViewModels_Vault.defaultNoFolderId) ? "checkmark.square.fill" : "square")
                    .foregroundColor(.white)
                    .font(.footnote)
                Text("< No Folder Assigned >")
                    .foregroundColor(.white)
                    .font(.footnote)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.selectedFolderIds.contains(ViewModels_Vault.defaultNoFolderId) {
                    viewModel.selectedFolderIds.remove(ViewModels_Vault.defaultNoFolderId)
                } else {
                    viewModel.selectedFolderIds.insert(ViewModels_Vault.defaultNoFolderId)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            // Actual folders
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.allFolders) { folder in
                        FolderRow(folder: folder, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 200)
        }
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }
}

struct FolderRow: View {
    let folder: ViewModels_Vault.FolderItem
    @ObservedObject var viewModel: VaultViewModel
    
    var body: some View {
        HStack {
            Image(systemName: viewModel.selectedFolderIds.contains(folder.id) ? "checkmark.square.fill" : "square")
                .foregroundColor(.white)
                .font(.footnote)
            Text(folder.name)
                .foregroundColor(.white)
                .font(.footnote)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.selectedFolderIds.contains(folder.id) {
                viewModel.selectedFolderIds.remove(folder.id)
            } else {
                viewModel.selectedFolderIds.insert(folder.id)
            }
        }
        .padding(.vertical, 4)
    }
} 
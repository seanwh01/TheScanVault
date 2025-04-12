import SwiftUI

extension Views_AIResearch {
    // Folder selection view
    struct AIFolderSelectionView: View {
        @ObservedObject var viewModel: AIResearchViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Top controls with Reset button
                HStack {
                    Button(action: {
                        viewModel.resetFolderSelection()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.footnote)
                            Text("Reset")
                                .font(.footnote)
                        }
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
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.vertical, 6)
                
                // No folder option
                AIFolderRow(folder: nil, viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                
                // Folder list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.allFolders, id: \.id) { folder in
                            AIFolderRow(folder: folder, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 8)
            }
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        }
    }

    // Individual folder row
    struct AIFolderRow: View {
        // Use the correct type that the viewModel works with
        let folder: FolderItem?
        @ObservedObject var viewModel: AIResearchViewModel
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.white)
                
                Text(folder?.name ?? "No Folder Assigned")
                    .foregroundColor(.white)
                    .font(.footnote)
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleFolderSelection()
            }
        }
        
        private var isSelected: Bool {
            if let folder = folder {
                // For specific folder, check if it's selected in the multiple folder mode
                return viewModel.folderSelectionMode == .selectedFolders && 
                       viewModel.selectedFolderIds.contains(folder.id)
            } else {
                // For no folder option
                return viewModel.folderSelectionMode == .noFolder
            }
        }
        
        private func toggleFolderSelection() {
            if let folder = folder {
                // Handle specific folder selection
                if viewModel.selectedFolderIds.contains(folder.id) {
                    viewModel.selectedFolderIds.remove(folder.id)
                    if viewModel.selectedFolderIds.isEmpty {
                        viewModel.folderSelectionMode = .allFolders
                    }
                } else {
                    viewModel.selectedFolderIds.insert(folder.id)
                    viewModel.folderSelectionMode = .selectedFolders
                }
            } else {
                // Handle no folder option
                viewModel.selectNoFolder()
            }
        }
    }
} 
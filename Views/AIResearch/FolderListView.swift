import SwiftUI

extension Views_AIResearch {
    // Empty state view
    struct EmptyFolderView: View {
        var body: some View {
            Text("No folders found")
                .foregroundColor(.gray)
                .padding()
        }
    }

    // View for displaying folders when they exist
    struct FolderListView: View {
        let folderGroups: [FolderGroup]
        let currentPage: Int
        let foldersPerPage: Int
        let expandedFolders: Set<String>
        @ObservedObject var viewModel: AIResearchViewModel
        let onToggleExpansion: (String) -> Void
        
        var body: some View {
            let startIndex = (currentPage - 1) * foldersPerPage
            let endIndex = min(startIndex + foldersPerPage, folderGroups.count)
            
            VStack(spacing: 0) {
                if startIndex < folderGroups.count && startIndex < endIndex {
                    ForEach(folderGroups[startIndex..<endIndex]) { folderGroup in
                        FolderItemView(
                            folderGroup: folderGroup,
                            isExpanded: expandedFolders.contains(folderGroup.key),
                            viewModel: viewModel,
                            onToggleExpansion: onToggleExpansion
                        )
                    }
                } else {
                    Text("No items to display on this page")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
    }

    // Individual folder view
    struct FolderItemView: View {
        let folderGroup: FolderGroup
        let isExpanded: Bool
        @ObservedObject var viewModel: AIResearchViewModel
        let onToggleExpansion: (String) -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack {
                    let folderId = folderGroup.id
                    
                    CheckboxView(
                        isChecked: folderId != nil ? viewModel.areAllFolderDocumentsSelected(folderId!) : 
                                    viewModel.areAllDocumentsWithoutFolderSelected(),
                        partiallySelected: folderId != nil ? 
                                          (viewModel.areFolderDocumentsSelected(folderId!) && !viewModel.areAllFolderDocumentsSelected(folderId!)) :
                                          (viewModel.areDocumentsWithoutFolderSelected() && !viewModel.areAllDocumentsWithoutFolderSelected())
                    )
                    .customTapAction(haptic: .medium, action: {
                        if let fId = folderId {
                            viewModel.toggleFolderInSelection(fId)
                        } else {
                            viewModel.toggleNoFolderSelection()
                        }
                    })
                    
                    Text(folderGroup.key)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                    
                    Spacer()
                    
                    Text("\(folderGroup.documents.count) items")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.trailing, 4)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture { _ in
                    onToggleExpansion(folderGroup.key)
                }
                
                // Documents
                if isExpanded {
                    ForEach(folderGroup.documents) { document in
                        DocumentRowWithCheckbox(
                            document: document,
                            folderName: folderGroup.id.flatMap { folderId in viewModel.getFolderName(for: document) },
                            tagsText: viewModel.getTagsText(for: document),
                            isSelected: viewModel.isDocumentSelected(document.id),
                            onToggle: { viewModel.toggleDocumentSelection(document.id) }
                        )
                        .padding(.leading, 8)
                        .padding(.bottom, 1)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // Replace the PaginationControlView with this centered version
    struct PaginationControlView: View {
        let currentPage: Int
        let totalPages: Int
        let onPrevious: () -> Void
        let onNext: () -> Void
        let onPageSelected: (Int) -> Void
        
        var body: some View {
            // Center the entire pagination control
            HStack {
                Spacer()
                
                // Scrollable container for the page numbers
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(getPageNumbersToShow(), id: \.self) { pageNumber in
                            if pageNumber == -1 {
                                // Show ellipsis for skipped pages
                                Text("...")
                                    .foregroundColor(.gray)
                                    .frame(width: 30, height: 30)
                            } else {
                                // Page number button
                                Button(action: {
                                    onPageSelected(pageNumber)
                                }) {
                                    Text("\(pageNumber)")
                                        .frame(width: 30, height: 30)
                                        .background(currentPage == pageNumber ? Color.blue : Color.blue.opacity(0.3))
                                        .foregroundColor(.white)
                                        .cornerRadius(15)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                // Limit the ScrollView width to ensure it stays centered
                .frame(maxWidth: min(CGFloat(getPageNumbersToShow().count * 38), UIScreen.main.bounds.width * 0.8))
                
                Spacer()
            }
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        }
        
        // Helper function to determine which page numbers to show
        private func getPageNumbersToShow() -> [Int] {
            var result: [Int] = []
            
            // Logic for showing page numbers with ellipses for large page counts
            if totalPages <= 7 {
                // If 7 or fewer pages, show all page numbers
                result = Array(1...totalPages)
            } else {
                // Always include page 1
                result.append(1)
                
                // Determine the range of pages to show around current page
                let beforeCurrentPage = max(2, currentPage - 1)
                let afterCurrentPage = min(totalPages - 1, currentPage + 1)
                
                // Add ellipsis if there's a gap between 1 and beforeCurrentPage
                if beforeCurrentPage > 2 {
                    result.append(-1) // -1 represents an ellipsis
                }
                
                // Add the range of pages around current page
                result.append(contentsOf: Array(beforeCurrentPage...afterCurrentPage))
                
                // Add ellipsis if there's a gap between afterCurrentPage and totalPages
                if afterCurrentPage < totalPages - 1 {
                    result.append(-1) // -1 represents an ellipsis
                }
                
                // Always include the last page
                result.append(totalPages)
            }
            
            return result
        }
    }
} 
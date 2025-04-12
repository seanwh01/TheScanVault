import SwiftUI

extension Views_AIResearch {
    // Structure to hold folder groups
    struct FolderGroup: Identifiable {
        let id: UUID?
        let key: String
        let documents: [AIDocumentItem]
    }

    // Search Results View for AI Research
    struct AISearchResultsView: View {
        @ObservedObject var viewModel: AIResearchViewModel
        @Binding var isPresented: Bool
        @Environment(\.presentationMode) var presentationMode
        @State private var showLoadingTimeout = false
        @State private var expandedFolders: Set<String> = Set()
        @State private var showAIQueryView = false
        @State private var currentFolderPage: Int = 1
        private let foldersPerPage = 10
        
        var body: some View {
            NavigationView {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 0) {
                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.documents.isEmpty {
                            emptyStateView
                        } else {
                            // Select/Deselect buttons
                            HStack(spacing: 20) {
                                Button(action: {
                                    viewModel.selectAllDocuments()
                                }) {
                                    Text("Select All")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.blue.opacity(0.5))
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    viewModel.unselectAllDocuments()
                                }) {
                                    Text("Deselect All")
                                        .font(.footnote)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.blue.opacity(0.5))
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            
                            // Document count
                            HStack {
                                Text("\(viewModel.documents.count) documents found")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            
                            // Document list
                            ScrollView {
                                VStack(spacing: 0) {
                                    documentSections
                                    
                                    // Add pagination controls
                                    if !viewModel.documents.isEmpty {
                                        paginationControls
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Continue button at bottom
                            VStack(spacing: 5) {
                                Button {
                                    if !viewModel.selectedDocumentIds.isEmpty {
                                        showAIQueryView = true
                                    }
                                } label: {
                                    Text("Select Documents for AI Research")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .foregroundColor(.white)
                                        .background(viewModel.selectedDocumentIds.isEmpty ? Color.gray : Color.green)
                                        .cornerRadius(12)
                                }
                                .disabled(viewModel.selectedDocumentIds.isEmpty)
                                
                                // Display token count
                                Text("\(viewModel.selectedDocumentIds.count) documents selected (\(viewModel.totalSelectedTokens) tokens)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .navigationTitle("Search Results for AI")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                    
                    // Add this new ToolbarItem for the ellipsis menu
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                expandAllFolders()
                            }) {
                                Label("Expand All", systemImage: "rectangle.expand.vertical")
                            }
                            
                            Button(action: {
                                collapseAllFolders()
                            }) {
                                Label("Collapse All", systemImage: "rectangle.compress.vertical")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .fullScreenCover(isPresented: $showAIQueryView) {
                    AIResearchQueryView(
                        viewModel: viewModel,
                        isPresented: $showAIQueryView,
                        onDismiss: {
                            isPresented = false
                        }
                    )
                }
            }
        }
        
        // Loading view
        private var loadingView: some View {
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Loading documents...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top)
                    
                if showLoadingTimeout {
                    Text("This is taking longer than expected.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                Button("Cancel") {
                    isPresented = false
                }
                .padding(.top, 20)
                .foregroundColor(.blue)
                Spacer()
            }
            .onAppear {
                // Show timeout message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if viewModel.isLoading {
                        showLoadingTimeout = true
                    }
                }
            }
        }
        
        // Empty state view
        private var emptyStateView: some View {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.blue.opacity(0.6))
                
                Text("No Documents Found")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Try adjusting your search filters or try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Back to Search")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(8)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .padding()
        }
        
        // Document sections from grouped documents
        @ViewBuilder
        private var documentSections: some View {
            let folderGroups = groupDocumentsByFolder()
            
            if folderGroups.isEmpty {
                EmptyFolderView()
            } else {
                FolderListView(
                    folderGroups: folderGroups,
                    currentPage: currentFolderPage, 
                    foldersPerPage: foldersPerPage,
                    expandedFolders: expandedFolders,
                    viewModel: viewModel,
                    onToggleExpansion: toggleFolderExpansion
                )
            }
        }
        
        // Add this method to toggle folder expansion
        private func toggleFolderExpansion(_ folderName: String) {
            if expandedFolders.contains(folderName) {
                expandedFolders.remove(folderName)
            } else {
                expandedFolders.insert(folderName)
            }
        }
        
        // Inside the AISearchResultsView struct, update the paginationControls
        private var paginationControls: some View {
            let folderGroups = groupDocumentsByFolder()
            let totalPages = max(1, (folderGroups.count + foldersPerPage - 1) / foldersPerPage)
            
            return PaginationControlView(
                currentPage: currentFolderPage,
                totalPages: totalPages,
                onPrevious: {
                    if currentFolderPage > 1 {
                        withAnimation {
                            currentFolderPage -= 1
                        }
                    }
                },
                onNext: {
                    if currentFolderPage < totalPages {
                        withAnimation {
                            currentFolderPage += 1
                        }
                    }
                },
                onPageSelected: { page in
                    withAnimation {
                        currentFolderPage = page
                    }
                }
            )
        }
        
        private func groupDocumentsByFolder() -> [FolderGroup] {
            var groups: [UUID?: [AIDocumentItem]] = [:]
            var noFolderDocuments: [AIDocumentItem] = []
            
            // First pass: Group documents by folder, but collect "No Folder" documents separately
            for document in viewModel.documents {
                let folderId = document.folderId
                
                // If folderId is nil or not found in allFolders, add to noFolderDocuments
                if folderId == nil || (folderId != nil && viewModel.allFolders.first(where: { $0.id == folderId }) == nil) {
                    noFolderDocuments.append(document)
                } else {
                    // Normal folder case
                    if groups[folderId] == nil {
                        groups[folderId] = []
                    }
                    groups[folderId]?.append(document)
                }
            }
            
            // Create FolderGroup array for valid folders
            var result = groups.compactMap { folderId, documents -> FolderGroup? in
                guard let id = folderId, let folder = viewModel.allFolders.first(where: { $0.id == id }) else {
                    // Skip invalid folders - we'll handle them separately
                    return nil
                }
                return FolderGroup(id: id, key: folder.name, documents: documents)
            }
            
            // Sort only the regular folders alphabetically
            result.sort { $0.key < $1.key }
            
            // Add the "No Folder Assigned" group at the beginning always
            if !noFolderDocuments.isEmpty {
                result.insert(FolderGroup(id: nil, key: "No Folder Assigned", documents: noFolderDocuments), at: 0)
            }
            
            return result
        }
        
        // Expand all folders
        private func expandAllFolders() {
            let folderGroups = groupDocumentsByFolder()
            for folderGroup in folderGroups {
                expandedFolders.insert(folderGroup.key)
            }
        }
        
        // Collapse all folders
        private func collapseAllFolders() {
            expandedFolders.removeAll()
        }
    }
}
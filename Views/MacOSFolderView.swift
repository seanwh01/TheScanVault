import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct MacOSFolderView: View {
    @ObservedObject var viewModel: AIResearchViewModel
    @State private var selectedFolderId: UUID?
    @State private var draggingDocument: AIDocumentItem?
    
    private let noFolderOptionId: UUID? = UUID.defaultNoFolderId
    
    var body: some View {
        NavigationView {
            // MARK: - Left sidebar with folders
            List {
                // Define special folders without tag/selection
                VStack {
                    // "All Folders" link
                    Button {
                        selectedFolderId = nil
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text("All Folders")
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(selectedFolderId == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                    
                    // "No Folder Assigned" link
                    Button {
                        selectedFolderId = UUID.defaultNoFolderId
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.questionmark")
                            Text("No Folder Assigned")
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(selectedFolderId == UUID.defaultNoFolderId ? Color.accentColor.opacity(0.2) : Color.clear)
                }
                
                // Divider between special and regular folders
                Divider()
                
                // Regular folders
                ForEach(viewModel.allFolders) { folder in
                    NavigationLink(
                        destination: DocumentsListView(
                            viewModel: viewModel,
                            folderName: folder.name,
                            documents: viewModel.documents.filter { $0.folderId == folder.id }
                        ),
                        tag: folder.id,
                        selection: $selectedFolderId
                    ) {
                        Label(folder.name, systemImage: "folder.fill")
                            .foregroundColor(.primary)
                    }
                    .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                        handleDrop(providers: providers, targetFolderId: folder.id)
                        return true
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 220)
            
            // Default view when no folder is selected
            Text("Select a folder to view documents")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Documents")
    }
    
    private func handleDrop(providers: [NSItemProvider], targetFolderId: UUID) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { (data, error) in
                guard let data = data as? Data,
                      let documentIdString = String(data: data, encoding: .utf8),
                      let documentId = UUID(uuidString: documentIdString) else {
                    return
                }
                
                // Update the document's folder ID
                DispatchQueue.main.async {
                    viewModel.moveDocument(documentId: documentId, toFolderId: targetFolderId)
                }
            }
        }
    }
}

// MARK: - Documents List View
struct DocumentsListView: View {
    @ObservedObject var viewModel: AIResearchViewModel
    let folderName: String
    let documents: [AIDocumentItem]
    
    var body: some View {
        VStack {
            // Header with folder name and document count
            HStack {
                Text(folderName)
                    .font(.headline)
                
                Spacer()
                
                Text("\(documents.count) documents")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding()
            
            // Documents list
            List {
                ForEach(documents) { document in
                    DocumentRowWithDrag(
                        document: document,
                        folderName: viewModel.getFolderName(for: document),
                        tagsText: viewModel.getTagsText(for: document)
                    )
                }
            }
        }
        .navigationTitle(folderName)
    }
}

// MARK: - Draggable Document Row
struct DocumentRowWithDrag: View {
    let document: AIDocumentItem
    let folderName: String?
    let tagsText: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(document.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let folderName = folderName {
                        Text("•")
                            .foregroundColor(.gray)
                        Text(folderName)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                if !tagsText.isEmpty {
                    Text(tagsText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .draggable(document.id.uuidString) {
            // Preview while dragging
            Text(document.title)
                .frame(width: 200, height: 40)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
    }
}

// MARK: - Helper Extension
extension UUID {
    // Special UUID for "No Folder Assigned" option
    static let defaultNoFolderId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
} 
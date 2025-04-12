import SwiftUI

// Tags selection view for VaultView
struct TagsSelectionView: View {
    @ObservedObject var viewModel: VaultViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Select/Deselect buttons
            HStack {
                Button(action: {
                    // Use direct manipulation instead of non-existent method
                    viewModel.selectedTags = Set(viewModel.allTags.map { $0.id })
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
                    // Use direct manipulation instead of non-existent method
                    viewModel.selectedTags.removeAll()
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
            
            // Add padding between buttons and tag list
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 6)
            
            // Tag grid in two columns
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 4) {
                // No tags option
                HStack {
                    Image(systemName: viewModel.showNoTagsOption ? "checkmark.square.fill" : "square")
                        .foregroundColor(.white)
                        .font(.footnote)
                    Text("< no tags >")
                        .foregroundColor(.white)
                        .font(.footnote)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Toggle showNoTagsOption directly
                    viewModel.showNoTagsOption.toggle()
                }
                .padding(.vertical, 4)
                
                // All other tags
                ForEach(viewModel.allTags) { tag in
                    TagRow(tag: tag, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }
}

// Individual tag row for VaultView
struct TagRow: View {
    let tag: ViewModels_Vault.TagItem
    @ObservedObject var viewModel: VaultViewModel
    
    var body: some View {
        HStack {
            Image(systemName: viewModel.selectedTags.contains(tag.id) ? "checkmark.square.fill" : "square")
                .foregroundColor(.white)
                .font(.footnote)
            Text(tag.name)
                .foregroundColor(.white)
                .font(.footnote)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleTag(tag.id)
        }
        .padding(.vertical, 4)
    }
    
    // Toggle tag selection
    private func toggleTag(_ tagId: UUID) {
        if viewModel.selectedTags.contains(tagId) {
            viewModel.selectedTags.remove(tagId)
        } else {
            viewModel.selectedTags.insert(tagId)
        }
    }
} 
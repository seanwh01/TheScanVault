import SwiftUI

// Search fields section
struct VaultSearchFieldsView: View {
    @ObservedObject var viewModel: VaultViewModel
    @Binding var showDateRangeOptions: Bool
    @Binding var showTagsOptions: Bool
    @Binding var showFolderOptions: Bool
    let cornerRadius: CGFloat
    @FocusState var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Title search field
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                TextField("Search by Title", text: $viewModel.searchTitle)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(cornerRadius)
            .padding(.horizontal)
            
            // OCR/Content search field
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                TextField("Search Document Content", text: $viewModel.searchOCRText)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(cornerRadius)
            .padding(.horizontal)
            
            // Make the folder selection consistent with other fields
            DisclosureGroup(
                isExpanded: $showFolderOptions,
                content: {
                    VaultFolderFilterView(viewModel: viewModel)
                        .padding(.horizontal, 4)
                },
                label: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.white)
                            .frame(width: 20)
                            
                        Text("Select Folder(s)")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: showFolderOptions ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            )
            .accentColor(.clear)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(cornerRadius)
            .padding(.horizontal)
            
            // Date range 
            DisclosureGroup(
                isExpanded: $showDateRangeOptions,
                content: {
                    DateRangeView(viewModel: viewModel)
                        .padding(.horizontal, 4)
                },
                label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.white)
                            .frame(width: 20)
                            
                        Text("Search by Date Range")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: showDateRangeOptions ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            )
            .accentColor(.clear)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(cornerRadius)
            .padding(.horizontal)
            
            // Tags
            DisclosureGroup(
                isExpanded: $showTagsOptions,
                content: {
                    TagsSelectionView(viewModel: viewModel)
                        .padding(.horizontal, 4)
                },
                label: {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.white)
                            .frame(width: 20)
                            
                        Text("Search by Tags")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: showTagsOptions ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            )
            .accentColor(.clear)
            .background(Color.blue.opacity(0.3))
            .cornerRadius(cornerRadius)
            .padding(.horizontal)
        }
    }
    
    private func dismissKeyboard() {
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 
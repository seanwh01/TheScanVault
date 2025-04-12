import SwiftUI

extension Views_AIResearch {
    // SearchFieldsView - modified from VaultView to support AIResearchViewModel
    struct AISearchFieldsView: View {
        @ObservedObject var viewModel: AIResearchViewModel
        @Binding var searchText: String
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
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isTextFieldFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(cornerRadius)
                .padding(.horizontal)
                
                // OCR text search field
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    TextField("Search Document Content", text: $viewModel.searchOCRText)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isTextFieldFocused)
                        .submitLabel(.search)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isTextFieldFocused = false
                                }
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(cornerRadius)
                .padding(.horizontal)
                
                // Folder selection 
                DisclosureGroup(
                    isExpanded: $showFolderOptions,
                    content: {
                        AIFolderSelectionView(viewModel: viewModel)
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
                        AIDateRangeView(viewModel: viewModel)
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
                        AITagsSelectionView(viewModel: viewModel)
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
    }
} 
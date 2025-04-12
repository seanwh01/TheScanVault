import SwiftUI
import CoreData

struct DocumentPreviewView: View {
    @ObservedObject var viewModel: DocumentViewModel
    @Binding var isPresented: Bool
    @State private var currentPageIndex = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Scrollable title at the top
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(viewModel.document?.title ?? "")
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(minWidth: UIScreen.main.bounds.width)
                    }
                    .background(Color.black)
                    
                    Spacer().frame(height: 15)
                    
                    // Document content area
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if !viewModel.documentPages.isEmpty {
                        // Multi-page document with swipe navigation
                        TabView(selection: $currentPageIndex) {
                            ForEach(0..<viewModel.pageCount, id: \.self) { index in
                                ZoomableScrollView {
                                    if index < viewModel.documentPages.count,
                                       let pageImage = viewModel.documentPages[safe: index],
                                       pageImage.size.width > 1 {
                                        Image(uiImage: pageImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: UIScreen.main.bounds.width)
                                    } else {
                                        ProgressView()
                                            .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: 200)
                                    }
                                }
                                .tag(index)
                                .onAppear {
                                    viewModel.loadPage(at: index)
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        
                        // Page counter at bottom
                        if viewModel.pageCount > 1 {
                            Text("Page \(currentPageIndex + 1) of \(viewModel.pageCount)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        }
                    } else if let previewImage = viewModel.previewImage {
                        // Single page document
                        ZoomableScrollView {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: UIScreen.main.bounds.width)
                        }
                        
                        // Still show page counter for single pages
                        Text("Page 1 of 1")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 8)
                    } else {
                        // No document content available
                        VStack {
                            Image(systemName: "doc.text")
                                .font(.system(size: 70))
                                .foregroundColor(.gray)
                            
                            Text("No preview available")
                                .foregroundColor(.gray)
                                .padding(.top)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
            .onChange(of: currentPageIndex) { newIndex in
                viewModel.setCurrentPage(newIndex)
            }
        }
    }
} 
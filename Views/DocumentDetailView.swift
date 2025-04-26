import SwiftUI
import CoreData
import PDFKit

struct DocumentDetailView: View {
    @ObservedObject var viewModel: DocumentViewModel
    let documentId: UUID
    @State private var showingDetailsSheet = false
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingActionSheet = false
    @State private var currentPageIndex = 0
    @State private var showAIQuerySheet = false
    @State private var aiQuery = ""
    @State private var aiResponse = ""
    @State private var isProcessingQuery = false
    @State private var aiUsageStats: OpenAIService.TokenUsage? = nil
    @State private var requestIds: [UUID] = []  // Store the last request IDs
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Add extra padding between navigation bar and title
            Spacer()
                .frame(height: 20)
            
            // Title at the top, scrollable if too long
            if let title = viewModel.document?.title, !title.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: UIScreen.main.bounds.width)
                }
                .background(Color(UIColor.systemBackground))
                
                // Add extra padding after the title
                Spacer()
                    .frame(height: 15)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.documentPages.isEmpty {
                VStack(spacing: 0) {
                    // Fixed container for the multi-page PDF
                    ZStack {
                        // Background frame that won't change
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: UIScreen.main.bounds.height * 0.65)
                            
                        // TabView with fixed size
                        TabView(selection: $currentPageIndex) {
                            ForEach(0..<viewModel.pageCount, id: \.self) { index in
                                // Image-based rendering for all documents using improved quality
                                ZoomableScrollView {
                                    if index < viewModel.documentPages.count,
                                       let pageImage = viewModel.documentPages[safe: index],
                                       pageImage.size.width > 1 { // Check for non-placeholder images
                                        Image(uiImage: pageImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: UIScreen.main.bounds.width)
                                    } else {
                                        // Show loading indicator for pages that aren't loaded yet
                                        ProgressView()
                                            .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: 200)
                                    }
                                }
                                .frame(maxWidth: UIScreen.main.bounds.width)
                                .frame(height: UIScreen.main.bounds.height * 0.65)
                                .clipped() // Enforce clipping at the boundaries
                                .tag(index)
                                .onAppear {
                                    // Trigger loading when this page appears
                                    viewModel.loadPage(at: index)
                                }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.65)
                    
                    // Scan date and page info directly below the fixed document container
                    HStack {
                        if let createdAt = viewModel.document?.createdAt {
                            Text("Scanned: \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if viewModel.pageCount > 1 {
                            Text("Page \(currentPageIndex + 1) of \(viewModel.pageCount)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Add document type indicator
                    if viewModel.documentType == .nativePDF {
                        Text("Native PDF")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                    } else if viewModel.documentType == .scannedPDF {
                        Text("Scanned PDF")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                    }
                }
            } else if let previewImage = viewModel.previewImage {
                // Single page document with scan date directly below
                VStack(spacing: 0) {
                    // Use strict fixed frame for scroll view container
                    ZStack {
                        // Background frame that won't change
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: UIScreen.main.bounds.height * 0.65)
                            
                        // Fixed size container for the scrollable content
                        ZoomableScrollView {
                            // Image with fixed width to prevent container expansion
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: UIScreen.main.bounds.width)
                        }
                        .frame(maxWidth: UIScreen.main.bounds.width)
                        .frame(height: UIScreen.main.bounds.height * 0.65)
                        .clipped() // Enforce clipping at the boundaries
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.65)
                    
                    // Add date and page info
                    HStack {
                        if let createdAt = viewModel.document?.createdAt {
                            Text("Scanned: \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Always show page count for single page documents too
                        Text("Page 1 of 1")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
            } else {
                // No document preview available
                VStack {
                    Spacer()
                    
                    Image(systemName: "doc.text")
                        .font(.system(size: 70))
                        .foregroundColor(.gray)
                    
                    Text("No preview available")
                        .foregroundColor(.gray)
                        .padding(.top)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)   
            }
            
            Spacer()
            
            // Bottom buttons row
            HStack {
                // AI Query button on the left
                Button(action: {
                    showAIQuerySheet = true
                }) {
                    Text("AI Query")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                
                Spacer()
                
                // View / Edit Details button on the right
                Button(action: {
                    showingDetailsSheet = true
                }) {
                    Text("View / Edit Details")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
        }
        .navigationTitle("") 
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button(action: {
            showingActionSheet = true
        }) {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        })
        .sheet(isPresented: $showingDetailsSheet) {
            DocumentDetailsSheet(viewModel: viewModel)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(title: Text("Document Actions"), message: nil, buttons: [
                .default(Text("Share Document")) { showingShareSheet = true },
                .default(Text("Edit Details")) { showingDetailsSheet = true },
                .destructive(Text("Delete Document")) { showingDeleteAlert = true },
                .cancel()
            ])
        }
        .sheet(isPresented: $showAIQuerySheet) {
            // Pass document title to AI Query view
            AIQueryView(
                isPresented: $showAIQuerySheet,
                query: $aiQuery,
                response: $aiResponse,
                isProcessing: $isProcessingQuery,
                usageStats: $aiUsageStats,
                requestIds: $requestIds,
                onSubmit: sendQueryToOpenAI,
                documentTitle: viewModel.document?.title ?? "Document"
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let documentData = viewModel.document?.documentData {
                DocumentShareSheet(activityItems: [documentData]) {
                    self.showingShareSheet = false
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Document"),
                message: Text("Are you sure you want to delete this document? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    // Delete the document and dismiss the view
                    viewModel.deleteDocument { success in
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Request the first page to load
            viewModel.prepareForDisplaying(page: 0)
        }
        .onChange(of: currentPageIndex) { _, newIndex in
            // Tell the view model to prepare the current page with higher quality
            viewModel.prepareForDisplaying(page: newIndex)
        }
        .onDisappear {
            // Notify that document may have been updated
            if viewModel.hasChanges {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DocumentUpdated"),
                    object: nil,
                    userInfo: ["documentId": documentId]
                )
            }
        }
    }
    
    // Method to save request ID
    private func saveRequestId(_ requestId: UUID) {
        // Add the request ID to the requestIds array
        requestIds.append(requestId)
        
        // Ensure the array doesn't exceed 5 items
        if requestIds.count > 5 {
            requestIds.removeFirst()
        }
    }
    
    // Add a method to get the last two request IDs
    func getLastTwoRequestIds() -> [String] {
        var result: [String] = []
        
        // Get last ID if available
        if let lastId = requestIds.last?.uuidString {
            result.append("Latest Request ID: \(lastId)")
        }
        
        // Get second-to-last ID if available
        if requestIds.count > 1 {
            let secondLastId = requestIds[requestIds.count - 2].uuidString
            result.append("Previous Request ID: \(secondLastId)")
        }
        
        // If no IDs available
        if result.isEmpty {
            result.append("No request IDs available yet")
        }
        
        return result
    }
    
    // Function to send the query to OpenAI
    private func sendQueryToOpenAI() {
        guard let document = viewModel.document,
              let text = document.text,
              !text.isEmpty,
              !aiQuery.isEmpty else {
            aiResponse = "Error: Document text is not available or query is empty."
            isProcessingQuery = false
            return
        }
        
        // Set processing state
        isProcessingQuery = true
        
        // In a real implementation, this would call the OpenAI API
        // For now, we'll just set a simple response with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.aiResponse = "This is a simulated response to your query: \(self.aiQuery)"
            self.isProcessingQuery = false
            
            // Generate a fake request ID
            let requestId = UUID()
            self.saveRequestId(requestId)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Create a view for the AI query sheet
struct AIQueryView: View {
    @Binding var isPresented: Bool
    @Binding var query: String
    @Binding var response: String
    @Binding var isProcessing: Bool
    @Binding var usageStats: OpenAIService.TokenUsage?
    @Binding var requestIds: [UUID]  // Add binding for request IDs
    let onSubmit: () -> Void
    
    // Add document title parameter
    let documentTitle: String
    
    // Add FocusState for controlling the keyboard
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.95).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Left justify the instruction text and add colon
                    HStack {
                        Text("Ask a question about this document:")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    TextEditor(text: $query)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .frame(height: 120)
                        .focused($isTextFieldFocused)
                    
                    Button(action: {
                        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !query.isEmpty {
                            // Dismiss keyboard
                            isTextFieldFocused = false
                            onSubmit()
                        }
                    }) {
                        Text("Submit Question")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.white)
                            .background(query.isEmpty ? Color.gray : Color.green)
                            .cornerRadius(12)
                    }
                    .disabled(query.isEmpty || isProcessing)
                    
                    if isProcessing {
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding()
                            
                            Text("Processing your question...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if !response.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(response)
                                    .padding(12)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Display API usage statistics if available
                                if let usage = usageStats {
                                    Divider()
                                        .background(Color.gray.opacity(0.5))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AI Usage Statistics")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.cyan)
                                        
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Total: \(usage.totalTokens) tokens")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                
                                                Text("Prompt: \(usage.promptTokens) | Completion: \(usage.completionTokens)")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            Text("$\(String(format: "%.4f", usage.estimatedCost))")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .fontWeight(.medium)
                                        }
                                        
                                        // Determine model name
                                        let modelName = usage.modelUsed ?? UserDefaults.standard.string(forKey: "AIModelPreference") ?? "gpt-3.5-turbo"
                                        
                                        Text("Model: \(modelName)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        // Show Request ID if available
                                        if !requestIds.isEmpty {
                                            Text("Request ID: \(requestIds.last?.uuidString ?? "Unknown")")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                                .onTapGesture {
                                                    // Copy to clipboard
                                                    UIPasteboard.general.string = requestIds.last?.uuidString
                                                }
                                            
                                            // Show previous request ID if available (second to last)
                                            if requestIds.count > 1 {
                                                let index = requestIds.count - 2
                                                let secondLastId = requestIds[index]
                                                Text("Previous ID: \(secondLastId.uuidString)")
                                                    .font(.caption)
                                                    .foregroundColor(.orange.opacity(0.7))
                                                    .onTapGesture {
                                                        // Copy to clipboard
                                                        UIPasteboard.general.string = secondLastId.uuidString
                                                    }
                                            }
                                        }
                                        
                                        // Display pricing info based on model
                                        if modelName.contains("gpt-4-turbo") {
                                            Text("Rate: $10.00/million input, $30.00/million output tokens")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        } else if modelName.contains("gpt-4o") {
                                            Text("Rate: $2.50/million input, $10.00/million output tokens")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        } else if modelName.contains("gpt-4") {
                                            Text("Rate: $10.00/million input, $30.00/million output tokens")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        } else {
                                            Text("Rate: $0.50/million input, $1.50/million output tokens")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 12)
                                }
                            }
                            .background(Color(.systemGray6).opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                // Add tap gesture to dismiss keyboard when tapping on background
                .contentShape(Rectangle()) // Make entire area tappable
                .onTapGesture {
                    isTextFieldFocused = false
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Clear") {
                    query = ""
                    response = ""
                    usageStats = nil
                }
                .disabled(query.isEmpty && response.isEmpty)
            )
            .navigationBarTitle(documentTitle, displayMode: .inline)
        }
    }
}

// Create a basic ShareSheet wrapper
struct DocumentShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let callback: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            callback?()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to do here
    }
}

import SwiftUI
import Combine
import UIKit
import Foundation

struct AIResearchResultsView: View {
    @ObservedObject var viewModel: AIResearchViewModel
    @Binding var isPresented: Bool
    
    @State private var query = ""
    @State private var response = ""
    @State private var isProcessing = false
    @State private var showFullDocument = false
    @State private var selectedDocumentForViewing: (UUID, String, String)? = nil
    @State private var usageStats: OpenAIService.TokenUsage? = nil
    @State private var responseId = UUID() // For scroll position identification
    
    @FocusState private var isTextFieldFocused: Bool
    
    // Cancel any in-flight API calls when view disappears
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Moved content to a separate view to reduce complexity
                AIResearchContent(
                    query: $query,
                    response: $response,
                    isProcessing: $isProcessing,
                    isTextFieldFocused: $isTextFieldFocused,
                    usageStats: $usageStats,
                    selectedDocumentForViewing: $selectedDocumentForViewing,
                    showFullDocument: $showFullDocument,
                    responseId: responseId,
                    viewModel: viewModel,
                    performQuery: { self.performQuery() }
                )
            }
            .sheet(isPresented: $showFullDocument) {
                if let doc = selectedDocumentForViewing {
                    DocumentPreviewSheet(title: doc.1, content: doc.2, isPresented: $showFullDocument)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        // Try to use the custom brain icon, but fall back to a system icon if not available
                        if UIImage(named: "BrainIcon") != nil {
                            Image("BrainIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 28)
                                .foregroundColor(.white)
                        } else {
                            // Use system brain icon as fallback
                            Image(systemName: "brain")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 24)
                                .foregroundColor(.cyan)
                        }
                        
                        Text("AI Research")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Clear response
                        response = ""
                        usageStats = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .opacity(response.isEmpty ? 0 : 1)
                }
            }
            .onDisappear {
                // Clean up any subscriptions
                cancellables.forEach { $0.cancel() }
                cancellables.removeAll()
            }
        }
    }
    
    private func performQuery(timeoutSeconds: Double = 60) {
        guard !query.isEmpty else { return }
        
        isProcessing = true
        response = "Processing query, please wait..."
        usageStats = nil
        
        let requestId = UUID()
        print("🔍 Starting AI query \(requestId.uuidString)")
        
        // Set up system role and prompts
        let systemRole = "You are an intelligent research assistant analyzing documents. Be concise but thorough in your responses."
        let prompt = buildDetailedPrompt()
        
        // Set timeout handler
        let timeoutWorkItem = DispatchWorkItem {
            if self.isProcessing {
                print("⏱️ Query \(requestId) timed out after \(timeoutSeconds) seconds")
                self.isProcessing = false
                self.response = "Request timed out. Please try again."
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)
        
        // Use the ViewModel's researchWithAI method to track the model
        viewModel.researchWithAI(prompt: prompt, systemRole: systemRole)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    // Cancel the timeout handler
                    timeoutWorkItem.cancel()
                    
                    switch completion {
                    case .failure(let error):
                        self.isProcessing = false
                        print("❌ Query \(requestId) failed: \(error.localizedDescription)")
                        
                        // The enhanced error messages now come from OpenAIService
                        self.response = error.localizedDescription
                        
                    case .finished:
                        self.isProcessing = false
                        print("✅ Query \(requestId) completed successfully")
                    }
                },
                receiveValue: { result in
                    print("📥 Query \(requestId) received response: \(result.text.prefix(100))...")
                    self.response = result.text
                    self.usageStats = result.usage
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadDocumentForPreview(id: UUID) {
        let documentContents = viewModel.getSelectedDocumentContents()
        if let doc = documentContents.first(where: { $0.0 == id }) {
            selectedDocumentForViewing = doc
            showFullDocument = true
        }
    }
    
    // Method to build the detailed prompt
    private func buildDetailedPrompt() -> String {
        // Get selected document contents
        let documentContents = viewModel.getSelectedDocumentContents()
        
        // Create context from document contents with document IDs for traceability
        let context = documentContents.map { id, title, text in
            """
            Document ID: \(id)
            Document Title: \(title)
            Content:
            \(text)
            ---
            """
        }.joined(separator: "\n\n")
        
        // Build the complete prompt
        return """
        Documents:
        \(context)
        
        Question: \(query)
        """
    }
}

// Extract the main content view to a separate component
struct AIResearchContent: View {
    @Binding var query: String
    @Binding var response: String
    @Binding var isProcessing: Bool
    @FocusState.Binding var isTextFieldFocused: Bool
    @Binding var usageStats: OpenAIService.TokenUsage?
    @Binding var selectedDocumentForViewing: (UUID, String, String)?
    @Binding var showFullDocument: Bool
    let responseId: UUID
    let viewModel: AIResearchViewModel
    let performQuery: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Query input field
                        QueryInputView(
                            query: $query,
                            response: $response,
                            isProcessing: isProcessing,
                            isTextFieldFocused: $isTextFieldFocused,
                            responseId: responseId,
                            viewModel: viewModel,
                            performQuery: performQuery,
                            scrollProxy: scrollProxy
                        )
                        
                        // Documents in scope
                        DocumentsScopeView(
                            viewModel: viewModel,
                            selectedDocumentForViewing: $selectedDocumentForViewing,
                            showFullDocument: $showFullDocument
                        )
                        
                        // Response area
                        if !response.isEmpty || isProcessing {
                            ResponseAreaView(
                                response: response,
                                isProcessing: isProcessing,
                                usageStats: usageStats,
                                responseId: responseId,
                                viewModel: viewModel
                            )
                        }
                    }
                }
                .onChange(of: response) { _, _ in
                    // When response changes and isn't empty, scroll to it
                    if !response.isEmpty && !isProcessing {
                        withAnimation {
                            scrollProxy.scrollTo(responseId, anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

// Query input view component
struct QueryInputView: View {
    @Binding var query: String
    @Binding var response: String
    let isProcessing: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    let responseId: UUID
    let viewModel: AIResearchViewModel
    let performQuery: () -> Void
    let scrollProxy: ScrollViewProxy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask a question about the selected documents")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)
            
            TextEditor(text: $query)
                .focused(isTextFieldFocused)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(8)
                .foregroundColor(.white)
            
            // Submit button
            Button {
                performQuery()
                // Set a small delay to allow the response view to be created
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        scrollProxy.scrollTo(responseId, anchor: .top)
                    }
                }
            } label: {
                Text("Submit Question")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                    .background(query.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(12)
            }
            .disabled(query.isEmpty || isProcessing)
            
            // Token count
            Text("Context: \(viewModel.totalSelectedTokens) tokens")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Show warning for large context sizes
            LargeContextWarningView(
                count: viewModel.selectedDocumentIds.count, 
                viewModel: viewModel, 
                response: $response
            )
        }
        .padding(.horizontal)
    }
}

// Documents scope view component
struct DocumentsScopeView: View {
    let viewModel: AIResearchViewModel
    @Binding var selectedDocumentForViewing: (UUID, String, String)?
    @Binding var showFullDocument: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documents in Scope:")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 8)
            
            ForEach(viewModel.getSelectedDocuments()) { document in
                AIDocumentListItemView(
                    document: document,
                    viewModel: viewModel,
                    selectedDocumentForViewing: $selectedDocumentForViewing,
                    showFullDocument: $showFullDocument
                )
            }
        }
        .padding(.horizontal)
    }
}

// Document list item view
struct AIDocumentListItemView: View {
    let document: AIDocumentItem
    let viewModel: AIResearchViewModel
    @Binding var selectedDocumentForViewing: (UUID, String, String)?
    @Binding var showFullDocument: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text(document.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("\(document.estimatedTokens) tokens")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button {
                // Get full text for this document
                loadDocumentForPreview(id: document.id)
            } label: {
                Image(systemName: "eye")
                    .foregroundColor(.blue)
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func loadDocumentForPreview(id: UUID) {
        let documentContents = viewModel.getSelectedDocumentContents()
        if let doc = documentContents.first(where: { $0.0 == id }) {
            selectedDocumentForViewing = doc
            showFullDocument = true
        }
    }
}

// Large context warning view
struct LargeContextWarningView: View {
    let count: Int
    let viewModel: AIResearchViewModel
    @Binding var response: String
    
    var body: some View {
        if count > 12 || viewModel.totalSelectedTokens > 25000 {
            VStack(alignment: .center, spacing: 10) {
                Text("⚠️ \(count) documents selected (\(viewModel.totalSelectedTokens) tokens)")
                    .font(.subheadline)
                    .foregroundColor(.yellow)
                
                Text("Large context may cause slow responses or timeouts")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button {
                    reduceDocumentCount()
                } label: {
                    Text("Use only 5 documents for better performance")
                        .font(.caption)
                        .padding(8)
                        .background(Color.blue.opacity(0.5))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        } else {
            EmptyView()
        }
    }
    
    // Helper function to reduce document count
    private func reduceDocumentCount(to targetCount: Int = 5) {
        // Get all selected document IDs
        let selectedDocumentIds = viewModel.selectedDocumentIds
        
        // Only proceed if we have more than the target
        if selectedDocumentIds.count > targetCount {
            // Keep only the first 'targetCount' documents
            let keptDocumentIds = Array(selectedDocumentIds.prefix(targetCount))
            
            // Create a new set
            let newSelection = Set(keptDocumentIds)
            
            // Update the view model
            viewModel.selectedDocumentIds = newSelection
            
            // Show a confirmation message
            response = "Reduced selected documents from \(selectedDocumentIds.count) to \(targetCount) to improve performance. You can now try your question again."
        }
    }
}

// Response area view component
struct ResponseAreaView: View {
    let response: String
    let isProcessing: Bool
    let usageStats: OpenAIService.TokenUsage?
    let responseId: UUID
    let viewModel: AIResearchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Response:")
                .font(.headline)
                .foregroundColor(.white)
                .id(responseId) // Mark for scrolling
            
            if isProcessing {
                ProcessingView(viewModel: viewModel)
            } else {
                ResponseContentView(response: response, usageStats: usageStats, viewModel: viewModel)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
}

// Processing view component
struct ProcessingView: View {
    let viewModel: AIResearchViewModel
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding()
                
                Text("Processing your question...")
                    .foregroundColor(.white)
                    .font(.headline)
                
                // Show estimated time based on token count
                let estimatedSeconds = max(10, viewModel.totalSelectedTokens / 100) // More realistic estimate: ~100 tokens per second
                Text("Estimated time: ~\(estimatedSeconds) seconds")
                    .foregroundColor(.gray)
                    .font(.caption)
                
                Text("Context size: \(viewModel.totalSelectedTokens) tokens")
                    .foregroundColor(.gray)
                    .font(.caption)
                
                Text("Please wait while AI processes your documents")
                    .foregroundColor(.gray)
                    .font(.caption)
                    .padding(.top, 5)
            }
            .padding()
            Spacer()
        }
        .frame(minHeight: 200)
        .background(Color(.systemGray6).opacity(0.2))
        .cornerRadius(8)
    }
}

// Response content view
struct ResponseContentView: View {
    let response: String
    let usageStats: OpenAIService.TokenUsage?
    let viewModel: AIResearchViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(response)
                    .padding(12)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Usage statistics
                if let usage = usageStats {
                    Divider()
                        .background(Color.gray.opacity(0.5))
                    
                    APIUsageStatsView(usage: usage, viewModel: viewModel)
                }
            }
            .background(Color(.systemGray6).opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// API usage stats view
struct APIUsageStatsView: View {
    let usage: OpenAIService.TokenUsage
    let viewModel: AIResearchViewModel
    
    // Move modelName determination to a computed property
    private var modelName: String {
        if let modelUsed = viewModel.modelUsed, !modelUsed.isEmpty {
            return modelUsed
        } else {
            return UserDefaults.standard.string(forKey: "AIModelPreference") ?? "gpt-3.5-turbo"
        }
    }
    
    var body: some View {
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
            
            Text("Model: \(modelName)")
                .font(.caption)
                .foregroundColor(.blue)
            
            // Show Request ID if available
            if !viewModel.requestIds.isEmpty {
                HStack {
                    Text("Request ID: \(viewModel.requestIds.last?.uuidString ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .onTapGesture {
                    // Copy to clipboard
                    UIPasteboard.general.string = viewModel.requestIds.last?.uuidString
                    // Provide haptic feedback (subtle)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                
                // Show previous request ID if available (second to last)
                if viewModel.requestIds.count > 1 {
                    let index = viewModel.requestIds.count - 2
                    let secondLastId = viewModel.requestIds[index]
                    HStack {
                        Text("Previous ID: \(secondLastId.uuidString)")
                            .font(.caption)
                            .foregroundColor(.orange.opacity(0.7))
                        
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .onTapGesture {
                        // Copy to clipboard
                        UIPasteboard.general.string = secondLastId.uuidString
                        // Provide haptic feedback (subtle)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
            }
            
            // Model pricing info using Group for conditional views
            Group {
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
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

struct DocumentPreviewSheet: View {
    let title: String
    let content: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(content)
                        .padding()
                }
            }
            .navigationTitle(title)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// Add a struct to hold response data with token usage
struct AIResearchResponse {
    let text: String
    let usage: OpenAIService.TokenUsage
}

// Network availability check
private func isNetworkAvailable() -> Bool {
    // More robust network check that pings an actual destination
    let semaphore = DispatchSemaphore(value: 0)
    var isAvailable = false
    
    // Use Apple's network connectivity check page
    guard let url = URL(string: "https://apple.com/library/test/success.html") else { 
        return false 
    }
    
    let task = URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 3)) { _, response, _ in
        if let httpResponse = response as? HTTPURLResponse, 
           httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
            isAvailable = true
        }
        semaphore.signal()
    }
    
    task.resume()
    
    // Wait with short timeout
    _ = semaphore.wait(timeout: .now() + 3)
    print("🌐 Network availability check: \(isAvailable ? "Connected" : "Disconnected")")
    
    return isAvailable
} 
import SwiftUI
import Combine

extension Views_AIResearch {
    // AI Query View for entering research queries
    struct AIResearchQueryView: View {
        @ObservedObject var viewModel: AIResearchViewModel
        @Binding var isPresented: Bool
        var onDismiss: () -> Void
        
        @State private var queryText = ""
        @State private var isLoading = false
        @State private var showResult = false
        @State private var aiResponse = ""
        @State private var showError = false
        @State private var errorMessage = ""
        
        // Predefined queries that users can select
        private let exampleQueries = [
            "Summarize these documents",
            "What are the key topics?",
            "Find important dates mentioned",
            "Extract contact information",
            "What are the main action items?"
        ]
        
        var body: some View {
            NavigationView {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 12) {
                        // Selected documents info
                        HStack {
                            Text("\(viewModel.selectedDocumentIds.count) documents selected")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(viewModel.totalSelectedTokens) tokens")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        // Query text editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter your research query:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $queryText)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(12)
                                .frame(minHeight: 150)
                                .padding(.bottom, 8)
                            
                            Text("Examples:")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            // Example queries
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(exampleQueries, id: \.self) { query in
                                        Button {
                                            queryText = query
                                        } label: {
                                            Text(query)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.3))
                                                .cornerRadius(8)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Submit button
                        Button {
                            if !queryText.isEmpty {
                                submitQuery()
                            }
                        } label: {
                            Text(isLoading ? "Processing..." : "Submit Query")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundColor(.white)
                                .background(queryText.isEmpty ? Color.gray : Color.green)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        .disabled(queryText.isEmpty || isLoading)
                        .padding(.bottom, 20)
                    }
                }
                .navigationTitle("AI Research Query")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            isPresented = false
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
                .sheet(isPresented: $showResult) {
                    AIResearchResultView(
                        response: aiResponse,
                        query: queryText,
                        viewModel: viewModel,
                        isPresented: $showResult,
                        onDismiss: {
                            onDismiss()
                        }
                    )
                }
                .onChange(of: showResult) { _, newValue in
                    if !newValue {
                        queryText = ""
                    }
                }
            }
        }
        
        private func submitQuery() {
            guard !queryText.isEmpty else { return }
            
            isLoading = true
            
            // Get the document contents
            let selectedDocuments = viewModel.getSelectedDocumentContents()
            
            // Format the documents for the prompt
            var documentsText = ""
            for (index, doc) in selectedDocuments.enumerated() {
                documentsText += "DOCUMENT \(index + 1): \(doc.1)\n\n\(doc.2)\n\n"
            }
            
            // The system prompt that guides the AI's behavior
            let systemPrompt = """
            You are an AI research assistant analyzing multiple documents.
            Respond to the user's query based ONLY on the provided documents' content.
            Format your response clearly using Markdown.
            If you can't answer the query based on the provided documents, clearly state so.
            """
            
            // The user's prompt with documents and query
            let userPrompt = """
            The following are the documents to analyze:
            
            \(documentsText)
            
            QUERY: \(queryText)
            
            Please provide a comprehensive analysis based on the query and the documents above.
            """
            
            // Send the query to OpenAI
            viewModel.researchWithAI(prompt: userPrompt, systemRole: systemPrompt)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        isLoading = false
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            showError = true
                            errorMessage = "Error processing your query: \(error.localizedDescription)"
                        }
                    },
                    receiveValue: { result in
                        isLoading = false
                        aiResponse = result.text
                        viewModel.lastUsage = result.usage
                        showResult = true
                    }
                )
                .store(in: &viewModel.cancellables)
        }
    }
}
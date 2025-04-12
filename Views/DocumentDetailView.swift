import SwiftUI
import CoreData

struct DocumentDetailView: View {
    @ObservedObject var viewModel: DocumentViewModel
    let documentId: UUID
    @State private var showingDetailsSheet = false
    @State private var showingShareSheet = false
    @State private var showDeleteAlert = false
    @State private var currentPageIndex = 0
    @State private var showAIQuerySheet = false
    @State private var aiQuery = ""
    @State private var aiResponse = ""
    @State private var isProcessingQuery = false
    @State private var aiUsageStats: OpenAIService.TokenUsage? = nil
    @State private var requestIds: [UUID] = []  // Store the last request IDs
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Document viewing area
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
                                    ZoomableScrollView {
                                        // Use a placeholder while the page loads
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
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
                        .padding(.horizontal, 10)
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
            }
            
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
        .navigationBarItems(
            trailing: HStack(spacing: 20) {
                // Share button
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                
                // Delete button
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        )
        .edgesIgnoringSafeArea([.horizontal, .bottom])
        .sheet(isPresented: $showingDetailsSheet) {
            DocumentDetailsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingShareSheet) {
            shareContent
        }
        .sheet(isPresented: $showAIQuerySheet) {
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
        .alert("Delete Document", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteDocument { success in
                    if success {
                        // Post notification that document was deleted
                        NotificationCenter.default.post(
                            name: NSNotification.Name("DocumentDeleted"),
                            object: nil,
                            userInfo: [
                                "documentId": documentId,
                                "forceFullRefresh": true  // Add this flag
                            ]
                        )
                        
                        // To ensure view updates, add a small delay before dismissing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this document? This action cannot be undone.")
        }
        .onAppear {
            // The document is already loaded in the DocumentViewModel initializer
            // No need to call loadDocument here
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
        .onChange(of: currentPageIndex) { newIndex in
            // Notify view model of page change and trigger loading adjacent pages
            viewModel.setCurrentPage(newIndex)
        }
    }
    
    private var shareContent: some View {
        Group {
            if let pdfData = viewModel.documentPDFData {
                createShareView(for: pdfData)
            } else if let firstImage = viewModel.documentPages.first {
                ShareSheet(items: [firstImage])
            } else if let previewImage = viewModel.previewImage {
                ShareSheet(items: [previewImage])
            } else {
                // Empty view with side effect
                Color.clear
                    .onAppear {
                        DispatchQueue.main.async {
                            showingShareSheet = false
                        }
                    }
            }
        }
        .onAppear {
            logShareInfo()
        }
    }
    
    private func createShareView(for pdfData: Data) -> some View {
        let tempURL = createTemporaryURL(for: pdfData, withName: "\(viewModel.document?.title ?? "Document").pdf")
        
        if let url = tempURL {
            return AnyView(ShareSheet(items: [url]))
        } else {
            return AnyView(ShareSheet(items: [pdfData]))
        }
    }
    
    private func logShareInfo() {
        if let pdfData = viewModel.documentPDFData {
            print("📤 Sharing PDF data: \(pdfData.count) bytes")
            
            let tempURL = createTemporaryURL(for: pdfData, withName: "\(viewModel.document?.title ?? "Document").pdf")
            if let url = tempURL {
                print("📤 Created temporary URL: \(url.path)")
            } else {
                print("⚠️ Failed to create temporary URL, falling back to data sharing")
            }
        } else if viewModel.documentPages.first != nil {
            print("📤 Sharing first document page as image")
        } else if viewModel.previewImage != nil {
            print("📤 Sharing preview image")
        } else {
            print("❌ No content available to share")
        }
    }
    
    private func createTemporaryURL(for data: Data, withName fileName: String) -> URL? {
        // Use the documents directory instead of temporary directory for better persistence
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            // Remove any existing file first
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            try data.write(to: fileURL, options: .atomic)
            print("✅ Successfully wrote file to: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Error creating file: \(error.localizedDescription)")
            return nil
        }
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
        
        // Log the query attempt
        print("🤖 Sending AI query for document \(document.id?.uuidString ?? "unknown")")
        print("🤖 Document text length: \(text.count) characters")
        print("🤖 Query length: \(aiQuery.count) characters")
        
        isProcessingQuery = true
        
        // Get API key from UserDefaults (matching AIResearchViewModel approach)
        guard let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"), !apiKey.isEmpty else {
            // Try keychain as fallback
            if let keychainKey = KeychainManager.shared.getAPIKey(service: "OpenAI", account: "DocumentClassification") {
                print("✅ Found API key in keychain, will use it for this query")
                useOpenAIAPI(with: keychainKey, document: document, text: text)
            } else {
                aiResponse = "Error: OpenAI API key not found. Please set up your API key in Settings."
                isProcessingQuery = false
            }
            return
        }
        
        // Use the API key from UserDefaults
        print("✅ Using API key from UserDefaults")
        useOpenAIAPI(with: apiKey, document: document, text: text)
    }
    
    // Helper method to keep the code DRY
    private func useOpenAIAPI(with apiKey: String, document: Document, text: String) {
        // Verify API key format (basic check)
        if !apiKey.hasPrefix("sk-") {
            print("❌ API key format appears invalid (doesn't start with 'sk-')")
            aiResponse = "Error: Your OpenAI API key appears to be invalid. Please check your API key in Settings."
            isProcessingQuery = false
            return
        }
        
        // Check network connectivity
        if !isNetworkAvailable() {
            print("❌ Network appears to be unavailable")
            aiResponse = "Error: Network connection appears to be unavailable. Please check your internet connection and try again."
            isProcessingQuery = false
            return
        }
        
        // Use the full document text without any character limit
        // NOTE: Previously this was limited to 4000 characters, but that limit has been removed
        // to allow processing of entire documents regardless of size
        let documentText = text
        
        // Create OpenAI service
        let openAIService = OpenAIService(apiKey: apiKey)
        
        print("🤖 Sending request to OpenAI with API key: \(apiKey.prefix(10))...\(apiKey.suffix(5))")
        print("🤖 Using model: \(UserDefaults.standard.string(forKey: "AIModelPreference") ?? "unknown")")
        
        // Cancel existing subscriptions to prevent memory leaks
        viewModel.cancellables.removeAll()
        
        // Test connection first
        testOpenAIConnection(apiKey: apiKey) { connectionSuccess in
            if !connectionSuccess {
                DispatchQueue.main.async {
                    self.aiResponse = "Error: Could not connect to OpenAI API. Please check your API key and internet connection."
                    self.isProcessingQuery = false
                }
                return
            }
            
            print("✅ OpenAI connection test succeeded, proceeding with main request")
            
            // Create the prompt and instructions
            let prompt = """
            Document text:
            \(documentText)
            
            Question: \(self.aiQuery)
            """
            
            let systemRole = "You are a helpful assistant that analyzes documents and answers questions based on their content. Provide accurate, concise responses based solely on the document information provided. Format your response as JSON."
            
            let instructions = """
            {
              "answer": "Your detailed answer to the question based on the document content"
            }
            
            Return your response as valid JSON matching the format above.
            """
            
            // Use Task to call the async method
            Task {
                do {
                    // Use the async/await method instead of the Combine-based one
                    print("🚀 Starting async request to OpenAI...")
                    let response = try await openAIService.generateStructuredResponse(
                        prompt: prompt,
                        instructions: instructions,
                        systemRole: systemRole,
                        modelName: UserDefaults.standard.string(forKey: "AIModelPreference"),
                        maxTokens: 1000,
                        temperature: 0.7,
                        includeUsage: true
                    )
                    
                    // Handle the response on the main thread
                    await MainActor.run {
                        if let content = response.content {
                            print("✅ OpenAI response received successfully")
                            
                            // First try direct JSON parsing
                            if let jsonData = content.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let answer = json["answer"] as? String {
                                self.aiResponse = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                // Fall back to general cleanup if JSON parsing fails
                                let cleanedResponse = self.cleanupResponse(content)
                                self.aiResponse = cleanedResponse
                            }
                            
                            // Update the usage statistics
                            self.aiUsageStats = response.usage
                            
                            // Save the request ID (keep last 5 max)
                            self.saveRequestId(response.requestId)
                            
                            // Log usage if available
                            if let usage = response.usage {
                                print("📊 Token usage - Prompt: \(usage.promptTokens), Completion: \(usage.completionTokens), Total: \(usage.totalTokens)")
                                print("🔍 OpenAI Request ID: \(response.requestId.uuidString) - save this for checking logs")
                            }
                        } else {
                            self.aiResponse = "Error: Received empty response from OpenAI."
                        }
                        
                        self.isProcessingQuery = false
                    }
                } catch {
                    // Handle errors on the main thread
                    await MainActor.run {
                        print("❌ Async OpenAI request failed with error: \(error.localizedDescription)")
                        self.aiResponse = "Error: \(error.localizedDescription)"
                        self.isProcessingQuery = false
                    }
                }
            }
        }
    }
    
    // Helper method to clean up malformed responses
    private func cleanupResponse(_ rawResponse: String) -> String {
        // First, try to parse as JSON and extract the 'answer' field
        do {
            if let jsonData = rawResponse.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let answer = json["answer"] as? String {
                return answer.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Failed to parse JSON response: \(error). Falling back to text cleanup")
            // If JSON parsing fails, continue with text-based cleanup
        }
        
        // If JSON parsing failed, try to extract JSON using regex
        if let extractedJson = extractJsonFromText(rawResponse) {
            do {
                if let json = try JSONSerialization.jsonObject(with: extractedJson) as? [String: Any],
                   let answer = json["answer"] as? String {
                    return answer.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                print("Failed to parse extracted JSON: \(error)")
            }
        }
        
        // Fall back to general cleanup
        var cleanedText = rawResponse
        
        // Remove XML/HTML-like tags
        let tagPattern = "<[^>]+>"
        cleanedText = cleanedText.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)
        
        // Remove markdown code block markers
        cleanedText = cleanedText.replacingOccurrences(of: "```[a-zA-Z]*\n", with: "", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")
        
        // Remove any JSON field names and braces
        cleanedText = cleanedText.replacingOccurrences(of: #"^\s*\{\s*"answer"\s*:\s*"(.*?)"\s*\}\s*$"#, with: "$1", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: #"^\s*\{\s*"answer"\s*:\s*"#, with: "", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: #""\s*\}\s*$"#, with: "", options: .regularExpression)
        
        // Remove extra quotes that might appear at beginning/end
        if cleanedText.hasPrefix("\"") && cleanedText.hasSuffix("\"") {
            cleanedText = String(cleanedText.dropFirst().dropLast())
        }
        
        // Clean up any escaped quotes or slashes
        cleanedText = cleanedText.replacingOccurrences(of: "\\\"", with: "\"")
        cleanedText = cleanedText.replacingOccurrences(of: "\\\\", with: "\\")
        
        // Clean up any XML/JSON artifacts
        cleanedText = cleanedText.replacingOccurrences(of: "\\n", with: "\n")
        cleanedText = cleanedText.replacingOccurrences(of: "&quot;", with: "\"")
        cleanedText = cleanedText.replacingOccurrences(of: "&amp;", with: "&")
        cleanedText = cleanedText.replacingOccurrences(of: "&lt;", with: "<")
        cleanedText = cleanedText.replacingOccurrences(of: "&gt;", with: ">")
        
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Helper method to extract JSON from text using regex
    private func extractJsonFromText(_ text: String) -> Data? {
        let jsonPattern = "\\{[\\s\\S]*\\}"
        let jsonRegex = try? NSRegularExpression(pattern: jsonPattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        guard let match = jsonRegex?.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        
        let jsonString = String(text[matchRange])
        return jsonString.data(using: .utf8)
    }
    
    // Simple network availability check
    private func isNetworkAvailable() -> Bool {
        guard let url = URL(string: "https://www.apple.com") else { return false }
        
        let semaphore = DispatchSemaphore(value: 0)
        var isAvailable = false
        
        let task = URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 5)) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                isAvailable = true
            }
            semaphore.signal()
        }
        
        task.resume()
        
        // Wait with timeout
        _ = semaphore.wait(timeout: .now() + 5)
        
        return isAvailable
    }
    
    // Test OpenAI API connection with minimal request
    private func testOpenAIConnection(apiKey: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ Invalid OpenAI API URL")
            completion(false)
            return
        }
        
        // Create a minimal request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Minimal payload to test connection
        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo-0125",
            "messages": [
                ["role": "user", "content": "Hello"]
            ],
            "max_tokens": 5
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("❌ Error serializing test request: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        // Make a test request
        print("🔍 Testing OpenAI API connection...")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI connection test failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OpenAI connection test failed: Invalid response")
                completion(false)
                return
            }
            
            // Log the response status and data
            print("📡 OpenAI API test response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📡 OpenAI API test response: \(responseString.prefix(100))...")
            }
            
            // Check for success
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                print("✅ OpenAI connection test successful")
                completion(true)
            } else {
                print("❌ OpenAI connection test failed with status: \(httpResponse.statusCode)")
                completion(false)
            }
        }
        
        task.resume()
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

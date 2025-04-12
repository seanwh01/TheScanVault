import Foundation
import Combine
import Network // For network availability checks

// References to DocumentClassifierService.DocumentSuggestions will be used

class OpenAIService {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private var currentModelCache: String?
    private var cancellables = Set<AnyCancellable>()
    private var isRequestAuthorized = false
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    // Retry configuration
    private let maxRetryAttempts = 3
    private let initialRetryDelay: TimeInterval = 2.0
    
    // Add constants for available models
    private struct Models {
        static let gpt35Turbo = "gpt-3.5-turbo-0125"
        static let gpt4o = "gpt-4o"
        static let gpt4Turbo = "gpt-4-turbo"
    }
    
    // Add a helper method to get the current model preference
    private func getCurrentModel() -> String {
        // Check if we have a cached value first
        if let cached = currentModelCache {
            return cached
        }
        
        // Otherwise fetch from UserDefaults and cache it
        let model = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? Models.gpt35Turbo
        currentModelCache = model
        print("🔄 OpenAIService using model: \(model)")
        return model
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
        
        print("Key length: \(apiKey.count) characters")
        print("First few chars: \(apiKey.prefix(10))")
        print("Last few chars: \(apiKey.suffix(10))")
        print("Contains whitespace? \(apiKey.contains(" "))")

        // Print full Authorization header for debugging
        let authHeader = "Bearer \(apiKey)"
        print("Authorization header length: \(authHeader.count) characters")
        
        // Add observer for model preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(modelPreferenceChanged),
            name: NSNotification.Name("AIModelPreferenceChanged"),
            object: nil
        )
        
        // Start monitoring network availability
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                print("🌐 Network availability changed: \(path.status == .satisfied ? "Connected" : "Disconnected")")
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        networkMonitor.cancel()
    }
    
    @objc private func modelPreferenceChanged() {
        // Clear the cache so we fetch the new value next time
        currentModelCache = nil
        let newModel = getCurrentModel()
        print("📣 OpenAIService detected model change to: \(newModel)")
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    struct ChatCompletionRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Float
        let max_tokens: Int
    }
    
    struct ChatCompletionResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let message: Message
        }
        
        struct Usage: Codable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
        
        let choices: [Choice]
        let usage: Usage
    }
    
    // Model for returning both content and token usage
    struct CompletionResult {
        let content: String
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
    
    // Structure to hold token usage information
    struct TokenUsage {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        let estimatedCost: Double
        let modelUsed: String? // Add property to track the model used
        
        init(promptTokens: Int, completionTokens: Int, totalTokens: Int, estimatedCost: Double? = nil, model: String? = nil) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
            self.modelUsed = model
            
            // Calculate cost based on model - corrected rates to match actual OpenAI pricing
            let isGpt4o = model?.contains("gpt-4o") ?? false
            let isGpt4Turbo = model?.contains("gpt-4-turbo") ?? false
            let isGpt4 = (model?.contains("gpt-4") ?? false) && !isGpt4Turbo && !isGpt4o
            
            // Debug model detection
            print("💰 Cost calculation for model: \(model ?? "unknown")")
            print("💰 Is GPT-4o model detected? \(isGpt4o ? "YES" : "NO")")
            print("💰 Is GPT-4 model detected? \(isGpt4 ? "YES" : "NO")")
            print("💰 Is GPT-4-turbo model detected? \(isGpt4Turbo ? "YES" : "NO")")
            
            // Updated rates (per token):
            // GPT-4o: $2.50/million input ≈ 0.0000025 per token, $10.00/million output ≈ 0.00001 per token
            // GPT-4-turbo: $10.00/million input ≈ 0.00001 per token, $30.00/million output ≈ 0.00003 per token
            // GPT-4: $10.00/million input ≈ 0.00001 per token, $30.00/million output ≈ 0.00003 per token
            // GPT-3.5: $0.50/million input ≈ 0.0000005 per token, $1.50/million output ≈ 0.0000015 per token
            
            let promptRate: Double
            let completionRate: Double
            
            if isGpt4o {
                promptRate = 0.0000025 // $2.50 per million tokens
                completionRate = 0.00001 // $10.00 per million tokens
            } else if isGpt4Turbo {
                promptRate = 0.00001 // $10.00 per million tokens
                completionRate = 0.00003 // $30.00 per million tokens
            } else if isGpt4 {
                promptRate = 0.00001 // $10.00 per million tokens
                completionRate = 0.00003 // $30.00 per million tokens
            } else {
                promptRate = 0.0000005 // $0.50 per million tokens
                completionRate = 0.0000015 // $1.50 per million tokens
            }
            
            let promptCost = Double(promptTokens) * promptRate
            let completionCost = Double(completionTokens) * completionRate
            self.estimatedCost = estimatedCost ?? (promptCost + completionCost)
            
            // Debug detailed cost breakdown
            print("💰 Token breakdown - Prompt: \(promptTokens) tokens × \(String(format: "%.8f", promptRate)) = $\(String(format: "%.4f", promptCost))")
            print("💰 Token breakdown - Completion: \(completionTokens) tokens × \(String(format: "%.8f", completionRate)) = $\(String(format: "%.4f", completionCost))")
            print("💰 Total estimated cost: $\(String(format: "%.4f", self.estimatedCost))")
        }
    }
    
    // Structure for AI Research responses with usage statistics
    struct AIResearchResponse {
        let text: String
        let usage: TokenUsage
        let modelUsed: String? // Add model information
        let requestId: UUID    // Add request ID for tracking
        
        init(text: String, usage: TokenUsage, modelUsed: String? = nil, requestId: UUID) {
            self.text = text
            self.usage = usage
            self.modelUsed = modelUsed
            self.requestId = requestId
        }
    }
    
    // Structure to hold JSON responses from OpenAI
    struct JSONResponse {
        let content: String?
        let usage: TokenUsage?
        let requestId: UUID      // Add request ID for tracking
        
        init(content: String?, usage: TokenUsage?, requestId: UUID) {
            self.content = content
            self.usage = usage
            self.requestId = requestId
        }
    }
    
    // MARK: - Document Classifier Response Types
    
    // Simple struct to represent document classification suggestions
    struct DocumentSuggestions {
        let suggestedTitle: String
        let suggestedFolderName: String?
        let suggestedTags: [String]
        let confidence: Double
        let tokenUsage: TokenUsage?
        let folderConfidences: [String: Double]?
    }
    
    // MARK: - Request Tracking and Logging
    
    // Track in-flight requests and their statuses
    private var requestTracker = [UUID: RequestStatus]()
    
    private enum RequestStatus {
        case inProgress(attempt: Int, startTime: Date)
        case completed(duration: TimeInterval)
        case failed(error: Error, attempt: Int)
    }
    
    private func logRequestStart(id: UUID, attempt: Int) {
        let status = RequestStatus.inProgress(attempt: attempt, startTime: Date())
        requestTracker[id] = status
        
        let attemptStr = attempt > 1 ? " (attempt \(attempt)/\(maxRetryAttempts))" : ""
        print("🚀 OpenAI request \(id.uuidString)\(attemptStr) starting")
    }
    
    private func logRequestComplete(id: UUID, startTime: Date) {
        let duration = Date().timeIntervalSince(startTime)
        requestTracker[id] = .completed(duration: duration)
        print("✅ OpenAI request \(id.uuidString) completed in \(String(format: "%.2f", duration))s")
    }
    
    private func logRequestFailed(id: UUID, error: Error, attempt: Int) {
        requestTracker[id] = .failed(error: error, attempt: attempt)
        print("❌ OpenAI request \(id.uuidString) failed on attempt \(attempt): \(error.localizedDescription)")
    }
    
    // MARK: - Network Verification
    
    private func verifyNetworkAvailability() -> Bool {
        if !isNetworkAvailable {
            print("⚠️ Network appears to be unavailable")
            return false
        }
        return true
    }
    
    // Dump request details for verification
    private func logRequestDetails(id: UUID, urlRequest: URLRequest) {
        guard let httpBody = urlRequest.httpBody else {
            print("⚠️ Request \(id.uuidString) has no HTTP body")
            return
        }
        
        print("📤 Request \(id.uuidString) details:")
        print("   URL: \(urlRequest.url?.absoluteString ?? "unknown")")
        print("   HTTP method: \(urlRequest.httpMethod ?? "unknown")")
        print("   Headers: \(urlRequest.allHTTPHeaderFields?.keys.joined(separator: ", ") ?? "none")")
        print("   Body size: \(httpBody.count) bytes")
        
        // Log excerpt of the request body
        if let json = try? JSONSerialization.jsonObject(with: httpBody) as? [String: Any],
           let messages = json["messages"] as? [[String: Any]] {
            
            print("   Messages count: \(messages.count)")
            
            // Log system prompts and excerpt of user prompts
            for (index, message) in messages.enumerated() {
                let role = message["role"] as? String ?? "unknown"
                if let content = message["content"] as? String {
                    if role == "system" {
                        print("   Message \(index) [\(role)]: \(content)")
                    } else {
                        let excerpt = content.count > 100 ? content.prefix(100) + "..." : content
                        print("   Message \(index) [\(role)]: \(excerpt) (total length: \(content.count) chars)")
                    }
                }
            }
        }
    }
    
    // MARK: - Private API Call Variables
    
    // Add these properties to control API calls
    private var callCounter = 0
    
    func resetCallCounter() {
        print("🔄 OpenAI call counter was \(callCounter), now reset to 0")
        callCounter = 0
        isRequestAuthorized = false
    }
    
    // Helper method to parse the AI's JSON response
    private func parseSuggestions(from jsonString: String) throws -> DocumentSuggestions {
        // Extract JSON from the potential text response
        let jsonPattern = "\\{[\\s\\S]*\\}"
        let jsonRegex = try NSRegularExpression(pattern: jsonPattern)
        let range = NSRange(location: 0, length: jsonString.utf16.count)
        
        guard let match = jsonRegex.firstMatch(in: jsonString, options: [], range: range),
              let matchRange = Range(match.range, in: jsonString) else {
            throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not extract JSON from response"])
        }
        
        let jsonData = String(jsonString[matchRange]).data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Extract the values
        let title = json["title"] as? String ?? "Untitled Document"
        let folder = json["folder"] as? String ?? "Miscellaneous"
        let rawTags = json["tags"] as? [String] ?? []
        let confidence = json["confidence"] as? Double ?? 0.5
        
        // Extract folder confidences if available
        let folderConfidences = json["folderConfidences"] as? [String: Double]
        
        // Log folder confidences if available
        if let confidences = folderConfidences {
            print("📊 Found folder confidence scores during initial parsing:")
            for (folderName, score) in confidences.sorted(by: { $0.value > $1.value }) {
                let percentScore = Int(score * 100)
                print("   - \(folderName): \(percentScore)%")
            }
        } else {
            print("⚠️ No folderConfidences found in AI response during initial parsing")
        }
        
        // Normalize and filter empty tags
        let tags = rawTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return DocumentSuggestions(
            suggestedTitle: title,
            suggestedFolderName: folder,
            suggestedTags: tags,
            confidence: confidence,
            tokenUsage: nil,
            folderConfidences: folderConfidences
        )
    }
    
    // MARK: - Retry Logic
    
    private func runWithRetry<T>(
        id: UUID,
        attemptNumber: Int = 1,
        retryableOperation: @escaping () -> AnyPublisher<T, Error>,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Verify network availability
        guard verifyNetworkAvailability() else {
            let networkError = NSError(
                domain: "OpenAIService",
                code: -1009, // NSURLErrorNotConnectedToInternet
                userInfo: [NSLocalizedDescriptionKey: "No network connection available"]
            )
            logRequestFailed(id: id, error: networkError, attempt: attemptNumber)
            completion(.failure(networkError))
            return
        }
        
        logRequestStart(id: id, attempt: attemptNumber)
        
        retryableOperation()
            .sink(
                receiveCompletion: { [weak self] result in
                    guard let self = self else { return }
                    
                    if case .failure(let error) = result {
                        self.logRequestFailed(id: id, error: error, attempt: attemptNumber)
                        
                        // Check if we should retry
                        if self.shouldRetry(error: error, attemptNumber: attemptNumber) {
                            let delay = self.calculateBackoff(attemptNumber: attemptNumber)
                            print("🔄 Retrying request \(id.uuidString) in \(String(format: "%.1f", delay))s (attempt \(attemptNumber+1)/\(self.maxRetryAttempts))")
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self.runWithRetry(
                                    id: id,
                                    attemptNumber: attemptNumber + 1,
                                    retryableOperation: retryableOperation,
                                    completion: completion
                                )
                            }
                        } else {
                            // We've exhausted our retries or encountered a non-retryable error
                            let finalError = self.enhanceError(error)
                            completion(.failure(finalError))
                        }
                    } else {
                        // Success case is handled in receiveValue
                    }
                },
                receiveValue: { [weak self] value in
                    guard let self = self,
                          let status = self.requestTracker[id],
                          case .inProgress(_, let startTime) = status else {
                        completion(.success(value))
                        return
                    }
                    
                    self.logRequestComplete(id: id, startTime: startTime)
                    completion(.success(value))
                }
            )
            .store(in: &cancellables)
    }
    
    private func shouldRetry(error: Error, attemptNumber: Int) -> Bool {
        // Don't retry if we've reached max attempts
        guard attemptNumber < maxRetryAttempts else {
            return false
        }
        
        let nsError = error as NSError
        
        // Retry on network/timeout errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorDNSLookupFailed:
                return true
            default:
                break
            }
        }
        
        // Retry on server errors (5xx)
        if nsError.domain == "OpenAIService" && (500...599).contains(nsError.code) {
            return true
        }
        
        // Retry on rate limits (429)
        if nsError.domain == "OpenAIService" && nsError.code == 429 {
            return true
        }
        
        return false
    }
    
    private func calculateBackoff(attemptNumber: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let backoff = initialRetryDelay * pow(2.0, Double(attemptNumber - 1))
        let jitter = Double.random(in: 0...0.3) * backoff
        return backoff + jitter
    }
    
    private func enhanceError(_ error: Error) -> Error {
        let nsError = error as NSError
        var userInfo = nsError.userInfo
        
        // Add more context to the error
        let enhancedDescription: String
        
        switch nsError.code {
        case NSURLErrorTimedOut:
            enhancedDescription = """
            Request timed out after multiple attempts. This could be due to:
            
            1. Network instability
            2. Large document size overwhelming the API
            3. OpenAI service is experiencing high load
            
            Try with fewer or smaller documents, or try again later.
            """
        case NSURLErrorNotConnectedToInternet:
            enhancedDescription = "No network connection available. Please check your internet connection and try again."
        case 429:
            enhancedDescription = "Rate limit exceeded after multiple attempts. Please wait a few minutes before trying again."
        case 400...499:
            enhancedDescription = "API request error: \(nsError.localizedDescription). Please check your API key and request format."
        case 500...599:
            enhancedDescription = "OpenAI server error after multiple attempts. The service may be experiencing issues. Please try again later."
        default:
            enhancedDescription = "Error: \(nsError.localizedDescription)"
        }
        
        userInfo[NSLocalizedDescriptionKey] = enhancedDescription
        
        return NSError(
            domain: nsError.domain,
            code: nsError.code,
            userInfo: userInfo
        )
    }
    
    // MARK: - Public Methods
    
    /// Sends a chat query to OpenAI and returns the response as a string
    /// - Parameters:
    ///   - prompt: The user prompt to send to the model
    ///   - systemRole: System role instructions
    ///   - modelName: OpenAI model to use (defaults to the user's preference)
    ///   - maxTokens: Maximum tokens for the response
    ///   - temperature: Temperature for response creativity (0-1)
    /// - Returns: A publisher that will provide the response text or an error
    func sendChatQuery(
        prompt: String,
        systemRole: String = "You are a helpful assistant.",
        modelName: String? = nil,
        maxTokens: Int = 2000,
        temperature: Float = 0.7
    ) -> AnyPublisher<String, Error> {
        return Future<String, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(
                    domain: "OpenAIService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Service instance was deallocated"]
                )))
                return
            }
            
            // Generate a unique ID for this request
            let requestId = UUID()
            
            // Define the operation that can be retried
            let operation = {
                // Capture self strongly here since we're inside a Future that already weakly captures self
                self.executeChatQuery(
                    requestId: requestId,
                    prompt: prompt,
                    systemRole: systemRole,
                    modelName: modelName,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
            }
            
            // Execute with retry logic
            self.runWithRetry(
                id: requestId,
                retryableOperation: operation
            ) { result in
                switch result {
                case .success(let response):
                    promise(.success(response))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Sends a chat query to OpenAI and returns both the response text and token usage statistics
    /// - Parameters:
    ///   - prompt: The user's prompt/question
    ///   - systemRole: System role instructions
    ///   - modelName: OpenAI model to use (defaults to the user's preference)
    ///   - maxTokens: Maximum tokens for the response
    ///   - temperature: Temperature for response creativity (0-1)
    /// - Returns: A publisher that will provide the response with token usage statistics or an error
    func sendChatQueryWithStats(
        prompt: String,
        systemRole: String = "You are a helpful assistant.",
        modelName: String? = nil,
        maxTokens: Int = 2000,
        temperature: Float = 0.7
    ) -> AnyPublisher<AIResearchResponse, Error> {
        return Future<AIResearchResponse, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(
                    domain: "OpenAIService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Service instance was deallocated"]
                )))
                return
            }
            
            // Generate a unique ID for this request
            let requestId = UUID()
            
            // Define the operation that can be retried
            let operation = {
                // Capture self strongly here since we're inside a Future that already weakly captures self
                self.executeChatQueryWithStats(
                    requestId: requestId,
                    prompt: prompt,
                    systemRole: systemRole,
                    modelName: modelName,
                    maxTokens: maxTokens,
                    temperature: temperature
                )
            }
            
            // Execute with retry logic
            self.runWithRetry(
                id: requestId,
                retryableOperation: operation
            ) { result in
                switch result {
                case .success(let response):
                    promise(.success(response))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Internal implementation that will be retried
    private func executeChatQuery(
        requestId: UUID,
        prompt: String,
        systemRole: String,
        modelName: String?,
        maxTokens: Int,
        temperature: Float
    ) -> AnyPublisher<String, Error> {
        return Future<String, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(
                    domain: "OpenAIService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Service instance was deallocated"]
                )))
                return
            }
            
            // Create messages array
            let messages = [
                ChatMessage(role: "system", content: systemRole),
                ChatMessage(role: "user", content: prompt)
            ]
            
            // Use the specified model or fall back to user preference
            let modelToUse = modelName ?? self.getCurrentModel()
            print("🤖 Using AI model for chat query: \(modelToUse)")
            
            // Create request
            let request = ChatCompletionRequest(
                model: modelToUse,
                messages: messages,
                temperature: temperature,
                max_tokens: maxTokens
            )
            
            // Set up HTTP request
            var urlRequest = URLRequest(url: self.baseURL)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue(requestId.uuidString, forHTTPHeaderField: "X-Request-ID")
            
            // Add timeout
            urlRequest.timeoutInterval = 120.0 // 120 seconds timeout for large document processing
            
            do {
                urlRequest.httpBody = try JSONEncoder().encode(request)
                print("🌐 Sending chat query to OpenAI (request size: \(urlRequest.httpBody?.count ?? 0) bytes)")
                
                // Log detailed request information
                self.logRequestDetails(id: requestId, urlRequest: urlRequest)
            } catch {
                print("❌ JSON encoding error: \(error.localizedDescription)")
                promise(.failure(error))
                return
            }
            
            // Create a completion handler to ensure we release the timeout timer
            let sendRequest = { [weak self] in
                guard let self = self else { return }
                
                // Send the request
                URLSession.shared.dataTaskPublisher(for: urlRequest)
                    .tryMap { data, response -> Data in
                        // Check for HTTP errors
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw NSError(
                                domain: "OpenAIService",
                                code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
                            )
                        }
                        
                        print("🔄 Received response for OpenAI request \(requestId.uuidString) with status: \(httpResponse.statusCode)")
                        
                        // Log response headers for debugging
                        print("📥 Response headers: \(httpResponse.allHeaderFields)")
                        
                        if !(200...299).contains(httpResponse.statusCode) {
                            // Try to parse error message from response
                            var errorMessage = "Server returned status code \(httpResponse.statusCode)"
                            var errorData: [String: Any]? = nil
                            
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let error = json["error"] as? [String: Any],
                                   let message = error["message"] as? String {
                                    errorMessage = message
                                    errorData = error
                                }
                                
                                // Print the full error response
                                print("❌ OpenAI API error response: \(json)")
                            } else if let errorText = String(data: data, encoding: .utf8) {
                                print("❌ OpenAI API error (non-JSON): \(errorText)")
                            }
                            
                            // Create a comprehensive error object
                            var userInfo: [String: Any] = [NSLocalizedDescriptionKey: errorMessage]
                            if let errorData = errorData {
                                userInfo["OpenAIErrorDetails"] = errorData
                            }
                            
                            throw NSError(
                                domain: "OpenAIService",
                                code: httpResponse.statusCode,
                                userInfo: userInfo
                            )
                        }
                        
                        // For successful responses, log a sample of the data
                        if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("✅ Response for \(requestId.uuidString) received with structure: \(jsonObj.keys.joined(separator: ", "))")
                            if let usage = jsonObj["usage"] as? [String: Any] {
                                print("📊 Token usage: \(usage)")
                            }
                        }
                        
                        return data
                    }
                    .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
                    .map { response in
                        // Extract response text
                        guard let choice = response.choices.first else {
                            return "No response generated"
                        }
                        
                        // Log token usage
                        print("📊 OpenAI tokens: prompt=\(response.usage.prompt_tokens), completion=\(response.usage.completion_tokens), total=\(response.usage.total_tokens)")
                        
                        return choice.message.content
                    }
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print("❌ OpenAI request \(requestId.uuidString) failed: \(error.localizedDescription)")
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { responseText in
                            print("✅ OpenAI request \(requestId.uuidString) completed with response")
                            promise(.success(responseText))
                        }
                    )
                    .store(in: &self.cancellables)
            }
            
            // Execute immediately
            sendRequest()
        }
        .eraseToAnyPublisher()
    }
    
    // Internal implementation that will be retried
    private func executeChatQueryWithStats(
        requestId: UUID,
        prompt: String,
        systemRole: String,
        modelName: String?,
        maxTokens: Int,
        temperature: Float
    ) -> AnyPublisher<AIResearchResponse, Error> {
        return Future<AIResearchResponse, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(
                    domain: "OpenAIService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Service instance was deallocated"]
                )))
                return
            }
            
            // Create messages array
            let messages = [
                ChatMessage(role: "system", content: systemRole),
                ChatMessage(role: "user", content: prompt)
            ]
            
            // Use the specified model or fall back to user preference
            let modelToUse = modelName ?? self.getCurrentModel()
            print("🤖 Using AI model for chat query: \(modelToUse)")
            
            // Create request
            let request = ChatCompletionRequest(
                model: modelToUse,
                messages: messages,
                temperature: temperature,
                max_tokens: maxTokens
            )
            
            // Set up HTTP request
            var urlRequest = URLRequest(url: self.baseURL)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue(requestId.uuidString, forHTTPHeaderField: "X-Request-ID")
            
            // Add timeout
            urlRequest.timeoutInterval = 120.0 // 120 seconds timeout for large document processing
            
            do {
                urlRequest.httpBody = try JSONEncoder().encode(request)
                print("🌐 Sending chat query to OpenAI (request size: \(urlRequest.httpBody?.count ?? 0) bytes)")
                
                // Log detailed request information
                self.logRequestDetails(id: requestId, urlRequest: urlRequest)
            } catch {
                print("❌ JSON encoding error: \(error.localizedDescription)")
                promise(.failure(error))
                return
            }
            
            // Create a completion handler to ensure we release the timeout timer
            let sendRequest = { [weak self] in
                guard let self = self else { return }
                
                // Send the request
                URLSession.shared.dataTaskPublisher(for: urlRequest)
                    .tryMap { data, response -> Data in
                        // Check for HTTP errors
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw NSError(
                                domain: "OpenAIService",
                                code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
                            )
                        }
                        
                        print("🔄 Received response for OpenAI request \(requestId.uuidString) with status: \(httpResponse.statusCode)")
                        
                        // Log response headers for debugging
                        print("📥 Response headers: \(httpResponse.allHeaderFields)")
                        
                        if !(200...299).contains(httpResponse.statusCode) {
                            // Try to parse error message from response
                            var errorMessage = "Server returned status code \(httpResponse.statusCode)"
                            var errorData: [String: Any]? = nil
                            
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let error = json["error"] as? [String: Any],
                                   let message = error["message"] as? String {
                                    errorMessage = message
                                    errorData = error
                                }
                                
                                // Print the full error response
                                print("❌ OpenAI API error response: \(json)")
                            } else if let errorText = String(data: data, encoding: .utf8) {
                                print("❌ OpenAI API error (non-JSON): \(errorText)")
                            }
                            
                            // Create a comprehensive error object
                            var userInfo: [String: Any] = [NSLocalizedDescriptionKey: errorMessage]
                            if let errorData = errorData {
                                userInfo["OpenAIErrorDetails"] = errorData
                            }
                            
                            throw NSError(
                                domain: "OpenAIService",
                                code: httpResponse.statusCode,
                                userInfo: userInfo
                            )
                        }
                        
                        // For successful responses, log a sample of the data
                        if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("✅ Response for \(requestId.uuidString) received with structure: \(jsonObj.keys.joined(separator: ", "))")
                            if let usage = jsonObj["usage"] as? [String: Any] {
                                print("📊 Token usage: \(usage)")
                            }
                        }
                        
                        return data
                    }
                    .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
                    .map { response in
                        // Extract response text
                        guard let choice = response.choices.first else {
                            return AIResearchResponse(
                                text: "No response generated",
                                usage: TokenUsage(
                                    promptTokens: 0,
                                    completionTokens: 0,
                                    totalTokens: 0,
                                    model: nil
                                ),
                                modelUsed: nil,
                                requestId: requestId
                            )
                        }
                        
                        // Log token usage
                        print("📊 OpenAI tokens: prompt=\(response.usage.prompt_tokens), completion=\(response.usage.completion_tokens), total=\(response.usage.total_tokens)")
                        
                        // Create token usage object with estimated cost
                        let tokenUsage = TokenUsage(
                            promptTokens: response.usage.prompt_tokens,
                            completionTokens: response.usage.completion_tokens,
                            totalTokens: response.usage.total_tokens,
                            model: modelToUse
                        )
                        
                        return AIResearchResponse(
                            text: choice.message.content,
                            usage: tokenUsage,
                            modelUsed: modelToUse,
                            requestId: requestId
                        )
                    }
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                print("❌ OpenAI request \(requestId.uuidString) failed: \(error.localizedDescription)")
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { response in
                            print("✅ OpenAI request \(requestId.uuidString) completed with response")
                            promise(.success(response))
                        }
                    )
                    .store(in: &self.cancellables)
            }
            
            // Execute immediately
            sendRequest()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Async/Await Methods
    
    /// Generate a structured response from OpenAI in JSON format with retry support
    /// - Parameters as before
    func generateStructuredResponse(
        prompt: String,
        instructions: String,
        systemRole: String,
        modelName: String? = nil,
        maxTokens: Int = 800,
        temperature: Double = 0.3,
        includeUsage: Bool = false
    ) async throws -> JSONResponse {
        // Use specified model or fall back to preference
        let model = modelName ?? getCurrentModel()
        let requestId = UUID()
        
        // Retry loop
        var lastError: Error?
        for attempt in 1...maxRetryAttempts {
            do {
                let result = try await executeStructuredRequest(
                    requestId: requestId,
                    prompt: prompt,
                    instructions: instructions,
                    systemRole: systemRole,
                    model: model,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    includeUsage: includeUsage,
                    attempt: attempt
                )
                return result
            } catch let error {
                lastError = error
                
                // Log failure
                logRequestFailed(id: requestId, error: error, attempt: attempt)
                
                // Check if we should retry
                if shouldRetry(error: error, attemptNumber: attempt) {
                    let delay = calculateBackoff(attemptNumber: attempt)
                    print("🔄 Retrying structured request \(requestId.uuidString) in \(String(format: "%.1f", delay))s (attempt \(attempt+1)/\(maxRetryAttempts))")
                    
                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    throw enhanceError(error)
                }
            }
        }
        
        // If we get here, all retries failed
        throw enhanceError(lastError ?? NSError(
            domain: "OpenAIService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"]
        ))
    }
    
    private func executeStructuredRequest(
        requestId: UUID,
        prompt: String,
        instructions: String,
        systemRole: String,
        model: String,
        maxTokens: Int,
        temperature: Double,
        includeUsage: Bool,
        attempt: Int
    ) async throws -> JSONResponse {
        // Verify network is available
        guard verifyNetworkAvailability() else {
            throw NSError(
                domain: "OpenAIService",
                code: -1009, // NSURLErrorNotConnectedToInternet
                userInfo: [NSLocalizedDescriptionKey: "No network connection available"]
            )
        }
        
        // Log request start
        logRequestStart(id: requestId, attempt: attempt)
        
        // Construct the messages array
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemRole],
            ["role": "user", "content": prompt],
            ["role": "system", "content": "Format your response as: \(instructions)"]
        ]
        
        // Construct the request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "response_format": ["type": "json_object"]
        ]
        
        // Create the request
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue(requestId.uuidString, forHTTPHeaderField: "X-Request-ID")
        request.timeoutInterval = 120.0
        
        // Serialize request body to JSON
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Log detailed request information
        logRequestDetails(id: requestId, urlRequest: request)
        
        // Get start time from tracker
        let startTime: Date
        if let status = requestTracker[requestId], 
           case .inProgress(_, let time) = status {
            startTime = time
        } else {
            startTime = Date()
        }
        
        // Make the request with manual timeout handling
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            // Log response status
            print("📥 Response for \(requestId.uuidString) received: HTTP \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                // Try to get error message from response
                let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = (errorJson?["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                throw NSError(domain: "OpenAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            
            // Parse the response
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let choices = json?["choices"] as? [[String: Any]]
            let firstChoice = choices?.first
            let message = firstChoice?["message"] as? [String: Any]
            let content = message?["content"] as? String
            
            // Extract token usage if requested
            var usage: TokenUsage? = nil
            if includeUsage, let usageJson = json?["usage"] as? [String: Any] {
                usage = TokenUsage(
                    promptTokens: usageJson["prompt_tokens"] as? Int ?? 0,
                    completionTokens: usageJson["completion_tokens"] as? Int ?? 0,
                    totalTokens: usageJson["total_tokens"] as? Int ?? 0,
                    model: model
                )
                
                print("📊 OpenAI request \(requestId.uuidString) token usage - Prompt: \(usage?.promptTokens ?? 0), Completion: \(usage?.completionTokens ?? 0), Total: \(usage?.totalTokens ?? 0)")
            }
            
            // Log successful completion
            logRequestComplete(id: requestId, startTime: startTime)
            
            return JSONResponse(content: content, usage: usage, requestId: requestId)
        } catch {
            throw error
        }
    }
    
    // MARK: - Connectivity Check
    
    /// Checks if the OpenAI API is reachable with the current API key
    /// Returns a publisher that emits true if the API is reachable, false otherwise
    func checkAPIConnectivity() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { promise in
            // Verify network availability first
            guard self.verifyNetworkAvailability() else {
                print("⚠️ Network unavailable, API connectivity check failed")
                promise(.success(false))
                return
            }
            
            // Create a minimal request to check connectivity
            var request = URLRequest(url: self.baseURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 5.0 // Short timeout for connectivity check
            
            // Minimal payload
            let minimalPayload: [String: Any] = [
                "model": self.getCurrentModel(),
                "messages": [["role": "user", "content": "Test"]],
                "max_tokens": 1
            ]
            
            print("🔍 Testing OpenAI API connectivity with model: \(self.getCurrentModel())")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: minimalPayload)
            } catch {
                print("❌ Error creating connectivity test payload: \(error.localizedDescription)")
                promise(.success(false))
                return
            }
            
            print("🔍 Testing OpenAI API connectivity...")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ API connectivity check failed: \(error.localizedDescription)")
                    promise(.success(false))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ API connectivity check failed: Invalid response")
                    promise(.success(false))
                    return
                }
                
                let isConnected = (200...299).contains(httpResponse.statusCode)
                print(isConnected ? "✅ OpenAI API is reachable" : "❌ OpenAI API returned status: \(httpResponse.statusCode)")
                
                if !isConnected, let data = data, let errorText = String(data: data, encoding: .utf8) {
                    print("❌ OpenAI API error response: \(errorText)")
                }
                
                promise(.success(isConnected))
            }.resume()
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Document Analysis
    
    /// Analyzes a document and returns document suggestions
    /// - Parameters:
    ///   - text: The document text to analyze
    ///   - model: The specific model to use for document classification
    ///   - completion: A callback that will be called with the result
    func analyzeDocument(_ text: String, model: String? = nil, completion: @escaping (Result<DocumentSuggestions, Error>) -> Void) {
        // Reset counter first to ensure we start fresh for each document
        resetCallCounter()
        
        // Then increment the counter for this call
        callCounter += 1
        isRequestAuthorized = true
        print("🔢 OpenAI call counter: \(callCounter) - API Key ends with: \(apiKey.suffix(4))")
        
        // Generate a unique request ID for this analysis
        let requestId = UUID()
        print("🧠 Starting document analysis with request ID: \(requestId.uuidString)")
        
        // Create a prompt for GPT
        let prompt = "DOCUMENT CONTENT:\n\(text)\n\nAnalyze this document and suggest a title, folder, and tags. Format your response as JSON:\n{\n  \"title\": \"Suggested document title\",\n  \"folder\": \"Suggested folder name\",\n  \"tags\": [\"Tag1\", \"Tag2\", \"Tag3\"],\n  \"confidence\": 0.85,\n  \"folderConfidences\": {\n    \"Folder1\": 0.75,\n    \"Folder2\": 0.25\n  }\n}"
        
        // Use the explicitly provided model or fall back to the current model preference
        let modelToUse = model ?? self.getCurrentModel()
        print("🤖 Using AI model for document analysis: \(modelToUse)")
        
        // Define the retryable operation
        let operation = {
            return self.generateCompletion(
                prompt: prompt,
                systemPrompt: "You are an expert document classifier specialized in analyzing documents. Suggest a title, folder, and tags based on the document content. IMPORTANT: Include folder confidence scores in your response in the folderConfidences object.",
                model: modelToUse
            )
        }
        
        // Execute with retry logic
        runWithRetry(
            id: requestId,
            retryableOperation: operation
        ) { result in
            switch result {
            case .success(let completionResult):
                print("✅ Document analysis completed successfully")
                
                // Try to parse the JSON from the content
                do {
                    var suggestions = try self.parseSuggestions(from: completionResult.content)
                    
                    // Add token usage information
                    let tokenUsage = TokenUsage(
                        promptTokens: completionResult.promptTokens,
                        completionTokens: completionResult.completionTokens,
                        totalTokens: completionResult.totalTokens,
                        model: modelToUse
                    )
                    
                    // Extract folderConfidences from the parsed JSON if available
                    let folderConfidences = try? self.extractFolderConfidences(from: completionResult.content)
                    
                    // Log folder confidence scores if available
                    if let confidences = folderConfidences {
                        print("📊 Folder confidence scores from AI:")
                        for (folderName, score) in confidences.sorted(by: { $0.value > $1.value }) {
                            // Format score as percentage for readability
                            let percentScore = Int(score * 100)
                            print("   - \(folderName): \(percentScore)%")
                        }
                        
                        // Log the selected folder with its confidence score
                        if let suggestedFolderName = suggestions.suggestedFolderName, 
                           let selectedFolderScore = confidences[suggestedFolderName] {
                            let percentScore = Int(selectedFolderScore * 100)
                            print("📁 Selected folder \"\(suggestedFolderName)\" with confidence: \(percentScore)%")
                        }
                    } else {
                        print("⚠️ No folder confidence scores found in AI response")
                    }
                    
                    // Create a new suggestions object with token usage
                    suggestions = DocumentSuggestions(
                        suggestedTitle: suggestions.suggestedTitle,
                        suggestedFolderName: suggestions.suggestedFolderName,
                        suggestedTags: suggestions.suggestedTags,
                        confidence: suggestions.confidence,
                        tokenUsage: tokenUsage,
                        folderConfidences: folderConfidences
                    )
                    
                    // Generate synthetic folder confidences if needed
                    if suggestions.folderConfidences == nil || suggestions.folderConfidences?.isEmpty == true {
                        print("⚠️ AI didn't provide folder confidences in standard analysis - using basic synthetic ones")
                        
                        // For standard analysis without metadata context, just create a simple confidence
                        // for the suggested folder equal to the overall confidence
                        if let suggestedFolder = suggestions.suggestedFolderName {
                            let syntheticConfidences = [suggestedFolder: suggestions.confidence]
                            
                            print("📊 Simple synthetic folder confidence:")
                            let percentScore = Int(suggestions.confidence * 100)
                            print("   - \(suggestedFolder): \(percentScore)% (synthetic)")
                            
                            // Update suggestions with synthetic confidences
                            suggestions = DocumentSuggestions(
                                suggestedTitle: suggestions.suggestedTitle,
                                suggestedFolderName: suggestions.suggestedFolderName,
                                suggestedTags: suggestions.suggestedTags,
                                confidence: suggestions.confidence,
                                tokenUsage: suggestions.tokenUsage,
                                folderConfidences: syntheticConfidences
                            )
                        }
                    }
                    
                    completion(.success(suggestions))
                } catch {
                    print("❌ Failed to parse document analysis results: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                
            case .failure(let error):
                print("❌ Document analysis failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Analyzes a document with metadata context and returns enhanced document suggestions
    /// - Parameters:
    ///   - text: The document text to analyze
    ///   - metadata: Contextual metadata (existing titles, folders, tags)
    ///   - model: The model to use for classification
    ///   - completion: A callback with the result
    func analyzeDocumentWithMetadata(_ text: String, metadata: [String: Any], model: String? = nil, completion: @escaping (Result<DocumentSuggestions, Error>) -> Void) {
        // Create a unique request ID
        let requestId = UUID()
        print("🧠 Starting document analysis with request ID: \(requestId.uuidString)")
        
        // Create the enhanced prompt with metadata context
        let prompt = createDocumentPromptWithMetadata(text, metadata: metadata)
        
        // Use the explicitly provided model or fall back to the current model preference
        let modelToUse = model ?? self.getCurrentModel()
        print("🤖 Using AI model for metadata-aware document analysis: \(modelToUse)")
        
        // Enhanced system prompt for metadata-aware analysis
        let systemPrompt = """
        You are an expert document classifier specialized in analyzing documents.
        You will be given document text and metadata about existing items in the system.
        Follow these guidelines:
        
        1. For titles: CRITICAL - You must strictly adhere to the title format patterns from existing documents
           - Exactly match the capitalization style (ALL CAPS, Title Case, lowercase, etc.)
           - Follow the same length conventions (short vs. descriptive)
           - Use similar prefixes/suffixes if they exist in similar documents
           - Copy the same punctuation patterns and formatting standards
           - This consistency is EXTREMELY IMPORTANT for the user's document organization
        
        2. For folders: Use existing folders when relevant (≥30% confidence)
        3. For tags: Prioritize reusing existing tags, limit to max 4
        4. Include confidence scores for all existing folders
        5. CRITICAL: When assigning a document to a specific folder, ALWAYS include the common tags
           associated with that folder as specified in FOLDER TAG PATTERNS
        6. CRITICAL: NEVER suggest folders or tags marked as deleted in the metadata
        
        IMPORTANT: Always include a 'folderConfidences' object in your response with confidence values (0.0-1.0) for each existing folder mentioned in the prompt. This is critical for proper document classification.
        """
        
        // Define the retryable operation
        let operation = {
            return self.generateCompletion(
                prompt: prompt,
                systemPrompt: systemPrompt,
                model: modelToUse
            )
        }
        
        // Execute with retry logic
        runWithRetry(
            id: requestId,
            retryableOperation: operation
        ) { result in
            switch result {
            case .success(let completionResult):
                print("✅ Document analysis with metadata completed successfully")
                
                // Try to parse the JSON from the content
                do {
                    var suggestions = try self.parseSuggestions(from: completionResult.content)
                    
                    // Add token usage information
                    let tokenUsage = TokenUsage(
                        promptTokens: completionResult.promptTokens,
                        completionTokens: completionResult.completionTokens,
                        totalTokens: completionResult.totalTokens,
                        model: modelToUse
                    )
                    
                    // Extract folderConfidences from the parsed JSON if available
                    let folderConfidences = try? self.extractFolderConfidences(from: completionResult.content)
                    
                    // Log folder confidence scores if available
                    if let confidences = folderConfidences {
                        print("📊 Folder confidence scores from AI:")
                        for (folderName, score) in confidences.sorted(by: { $0.value > $1.value }) {
                            // Format score as percentage for readability
                            let percentScore = Int(score * 100)
                            print("   - \(folderName): \(percentScore)%")
                        }
                        
                        // Log the selected folder with its confidence score
                        if let suggestedFolderName = suggestions.suggestedFolderName, 
                           let selectedFolderScore = confidences[suggestedFolderName] {
                            let percentScore = Int(selectedFolderScore * 100)
                            print("📁 Selected folder \"\(suggestedFolderName)\" with confidence: \(percentScore)%")
                        }
                    } else {
                        print("⚠️ No folder confidence scores found in AI response")
                    }
                    
                    // Create a new suggestions object with token usage and folder confidences
                    suggestions = DocumentSuggestions(
                        suggestedTitle: suggestions.suggestedTitle,
                        suggestedFolderName: suggestions.suggestedFolderName,
                        suggestedTags: suggestions.suggestedTags,
                        confidence: suggestions.confidence,
                        tokenUsage: tokenUsage,
                        folderConfidences: folderConfidences
                    )
                    
                    // Use the document classifier service to enhance with synthetic confidence scores if needed
                    if suggestions.folderConfidences == nil || suggestions.folderConfidences?.isEmpty == true {
                        print("⚠️ AI didn't provide folder confidences - will generate synthetic ones")
                        
                        // We need the DocumentClassifierService to generate synthetic confidences
                        // This could be done through dependency injection, but for now let's check if synthetic confidence generation
                        // functionality exists in other places and call it if available
                        
                        if let existingFolders = metadata["existingFolders"] as? [String], !existingFolders.isEmpty {
                            // Generate synthetic confidences
                            var syntheticConfidences: [String: Double] = [:]
                            
                            // Make the suggested folder have the highest confidence (equal to overall confidence)
                            if let suggestedFolder = suggestions.suggestedFolderName {
                                syntheticConfidences[suggestedFolder] = suggestions.confidence
                                
                                // Give other folders lower confidences (descending)
                                let otherFolders = existingFolders.filter { $0 != suggestedFolder }
                                let maxOtherConfidence = max(0.1, suggestions.confidence * 0.5)
                                let minOtherConfidence = max(0.05, suggestions.confidence * 0.2)
                                
                                if !otherFolders.isEmpty {
                                    let step = (maxOtherConfidence - minOtherConfidence) / Double(otherFolders.count)
                                    for (index, folder) in otherFolders.enumerated() {
                                        let confidence = maxOtherConfidence - (Double(index) * step)
                                        syntheticConfidences[folder] = confidence
                                    }
                                }
                                
                                // Log synthetic confidences
                                print("📊 SYNTHETIC folder confidence scores:")
                                for (folderName, score) in syntheticConfidences.sorted(by: { $0.value > $1.value }) {
                                    let percentScore = Int(score * 100)
                                    print("   - \(folderName): \(percentScore)% (synthetic)")
                                }
                                
                                // Create updated suggestions with synthetic confidences
                                suggestions = DocumentSuggestions(
                                    suggestedTitle: suggestions.suggestedTitle,
                                    suggestedFolderName: suggestions.suggestedFolderName,
                                    suggestedTags: suggestions.suggestedTags,
                                    confidence: suggestions.confidence,
                                    tokenUsage: suggestions.tokenUsage,
                                    folderConfidences: syntheticConfidences
                                )
                            }
                        }
                    }
                    
                    completion(.success(suggestions))
                } catch {
                    print("❌ Failed to parse document analysis results: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                
            case .failure(let error):
                print("❌ Document analysis with metadata failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Generates a completion for a given prompt with retry support
    /// - Parameters:
    ///   - prompt: The prompt to send to the model
    ///   - systemPrompt: The system instructions
    ///   - model: The specific model to use
    /// - Returns: A publisher with the completion result
    func generateCompletion(prompt: String, systemPrompt: String = "You are a helpful assistant.", model: String? = nil) -> AnyPublisher<CompletionResult, Error> {
        return Future<CompletionResult, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(
                    domain: "OpenAIService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Service instance was deallocated"]
                )))
                return
            }
            
            let messages = [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: prompt)
            ]
            
            // Use the explicitly provided model or fall back to the current model preference
            let modelToUse = model ?? self.getCurrentModel()
            print("🤖 Using AI model: \(modelToUse)")
            
            let request = ChatCompletionRequest(
                model: modelToUse,
                messages: messages,
                temperature: 0.7,
                max_tokens: 1000
            )
            
            var urlRequest = URLRequest(url: self.baseURL)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Add timeout
            urlRequest.timeoutInterval = 120.0 // 120 seconds timeout for large document processing
            
            do {
                urlRequest.httpBody = try JSONEncoder().encode(request)
            } catch {
                let failureResult: Result<CompletionResult, Error> = .failure(error)
                promise(failureResult)
                return
            }
            
            URLSession.shared.dataTaskPublisher(for: urlRequest)
                .map(\.data)
                .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
                .map { response in
                    guard let choice = response.choices.first else {
                        return CompletionResult(
                            content: "No response generated",
                            promptTokens: 0,
                            completionTokens: 0,
                            totalTokens: 0
                        )
                    }
                    
                    return CompletionResult(
                        content: choice.message.content,
                        promptTokens: response.usage.prompt_tokens,
                        completionTokens: response.usage.completion_tokens,
                        totalTokens: response.usage.total_tokens
                    )
                }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            let failureResult: Result<CompletionResult, Error> = .failure(error)
                            promise(failureResult)
                        }
                    },
                    receiveValue: { value in
                        let successResult: Result<CompletionResult, Error> = .success(value)
                        promise(successResult)
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    // Helper method to extract folder confidence scores from JSON response
    private func extractFolderConfidences(from jsonString: String) throws -> [String: Double]? {
        // Extract JSON from the potential text response
        let jsonPattern = "\\{[\\s\\S]*\\}"
        let jsonRegex = try NSRegularExpression(pattern: jsonPattern)
        let range = NSRange(location: 0, length: jsonString.utf16.count)
        
        guard let match = jsonRegex.firstMatch(in: jsonString, options: [], range: range),
              let matchRange = Range(match.range, in: jsonString) else {
            throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not extract JSON from response"])
        }
        
        let jsonData = String(jsonString[matchRange]).data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // Extract the folder confidences if available
        if let folderConfidences = json["folderConfidences"] as? [String: Double] {
            return folderConfidences
        }
        
        return nil
    }
    
    // Create a document prompt with metadata context
    private func createDocumentPromptWithMetadata(_ text: String, metadata: [String: Any]) -> String {
        var prompt = "DOCUMENT CONTENT:\n\(text)\n\n"
        
        // Add existing titles as context if available
        if let existingTitles = metadata["existingTitles"] as? [String], !existingTitles.isEmpty {
            prompt += "EXISTING DOCUMENT TITLES IN THE SYSTEM:\n"
            prompt += existingTitles.prefix(10).joined(separator: "\n")
            prompt += "\n\n"
            prompt += "CRITICAL TITLE GUIDELINES - YOU MUST FOLLOW THESE EXACTLY:\n"
            prompt += "1. Study the existing titles above carefully - your suggested title MUST match their pattern.\n"
            prompt += "2. Match EXACTLY the same capitalization style (Title Case, UPPERCASE, lowercase, etc).\n"
            prompt += "3. Use the same typical length and specificity level as existing titles.\n"
            prompt += "4. Copy any common prefixes, suffixes, or bracketed patterns [like this] if they exist.\n"
            prompt += "5. Use identical punctuation conventions (hyphens, colons, etc.) as similar documents.\n"
            prompt += "6. The title consistency is one of the MOST IMPORTANT aspects of the document organization.\n\n"
        }
        
        // Add existing tags as context if available
        if let existingTags = metadata["existingTags"] as? [String], !existingTags.isEmpty {
            prompt += "EXISTING TAGS IN THE SYSTEM:\n"
            prompt += existingTags.joined(separator: ", ")
            prompt += "\n\n"
        }
        
        // Add existing folders as context if available
        if let existingFolders = metadata["existingFolders"] as? [String], !existingFolders.isEmpty {
            prompt += "EXISTING FOLDERS IN THE SYSTEM:\n"
            prompt += existingFolders.joined(separator: ", ")
            prompt += "\n\n"
        }
        
        // Add folder-tag patterns if available
        if let folderTagPatterns = metadata["folderTagPatterns"] as? [String: [String: Double]], !folderTagPatterns.isEmpty {
            prompt += "FOLDER TAG PATTERNS (Tags commonly used with each folder):\n"
            
            for (folderName, tagFrequencies) in folderTagPatterns {
                if !tagFrequencies.isEmpty {
                    // Sort tags by frequency (highest first)
                    let sortedTags = tagFrequencies.sorted { $0.value > $1.value }
                    let tagList = sortedTags.map { tag, frequency -> String in
                        let percentValue = Int(frequency * 100)
                        return "\(tag) (\(percentValue)%)"
                    }.joined(separator: ", ")
                    
                    prompt += "- \(folderName): \(tagList)\n"
                }
            }
            prompt += "\n"
            
            // Add specific guidance about folder-tag associations
            prompt += "IMPORTANT TAG GUIDANCE:\n"
            prompt += "1. When classifying a document in a specific folder, strongly prefer using the common tags associated with that folder listed above.\n"
            prompt += "2. For instance, if you determine a document belongs in 'Equity Research Reports' folder, you should include any high-percentage tags associated with that folder (like 'CFRA' if it's commonly used).\n"
            prompt += "3. This ensures consistency in tagging across similar documents.\n\n"
        }
        
        // Add information about previously deleted tags/folders if available
        if let deletedTags = metadata["deletedTags"] as? [String], !deletedTags.isEmpty {
            prompt += "DELETED TAGS (DO NOT SUGGEST THESE):\n"
            prompt += deletedTags.joined(separator: ", ")
            prompt += "\n\n"
        }
        
        if let deletedFolders = metadata["deletedFolders"] as? [String], !deletedFolders.isEmpty {
            prompt += "DELETED FOLDERS (DO NOT SUGGEST THESE):\n"
            prompt += deletedFolders.joined(separator: ", ")
            prompt += "\n\n"
        }
        
        // Add important rules about folder/tag selection
        prompt += """
        CRITICAL CLASSIFICATION RULES:
        1. ONLY suggest folders from the EXISTING FOLDERS list above
        2. NEVER suggest any folder that was listed in DELETED FOLDERS
        3. Prefer tags from the EXISTING TAGS list when appropriate
        4. NEVER suggest any tag that was listed in DELETED TAGS
        5. When suggesting a specific folder, STRONGLY PREFER using its commonly associated tags
        
        """
        
        // Add instructions for the output format
        prompt += """
        Format your response as JSON:
        {
          "title": "A descriptive document title",
          "folder": "A suggested folder (MUST be from the existing folders listed above)",
          "tags": ["Tag1", "Tag2", "Tag3"],
          "confidence": 0.85,
          "folderConfidences": {
            "Folder1": 0.85,
            "Folder2": 0.45,
            "Folder3": 0.20
          }
        }
        
        IMPORTANT: Include a folderConfidences object with confidence scores for each existing folder.
        """
        
        return prompt
    }
} 
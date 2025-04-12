import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Combine
import Vision

// WARNING: FOR DEVELOPMENT TESTING ONLY
// This service directly uses the OpenAI API for testing
// This approach should NOT be used in production

// Use the DocumentSuggestions directly instead of as a member type
// typealias DocumentSuggestions = OpenAIService.DocumentSuggestions

class TempDevDocumentAIService {
    static let shared = TempDevDocumentAIService()
    
    private init() {
        print("🧪 Initialized TempDevDocumentAIService (development mock)")
    }
    
    // Add a local model constant in case AIModelPreference is not available
    private let defaultModel = "gpt-3.5-turbo-0125"
    
    // Helper to safely get the current model
    private var currentModel: String {
        // Try to access from UserDefaults directly
        if let savedModel = UserDefaults.standard.string(forKey: "AI Classifier Model") {
            return savedModel
        }
        
        // Ultimate fallback
        return defaultModel
    }
    
    private var apiKey: String {
        return UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? ""
    }
    
    private var organizationId: String? {
        return UserDefaults.standard.string(forKey: "OpenAIOrganizationID")
    }
    
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private var cancellables = Set<AnyCancellable>()
    
    func analyzeDocument(withText text: String, image: PlatformImage? = nil) -> AnyPublisher<DocumentClassifierService.DocumentSuggestions, Error> {
        return Future<DocumentClassifierService.DocumentSuggestions, Error> { promise in
            // Validate inputs
            guard !text.isEmpty else {
                let error = NSError(domain: "DocumentClassifier", code: 1, 
                    userInfo: [NSLocalizedDescriptionKey: "Cannot perform AI analysis: missing text"])
                let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                promise(result)
                return
            }
            
            // Get API key with better error handling
            let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? ""
            guard !apiKey.isEmpty else {
                let error = NSError(domain: "DocumentClassifier", code: 2, 
                    userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured in Settings"])
                let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                promise(result)
                return
            }
            
            print("🔑 Using API key starting with: \(apiKey.prefix(5))...")
            
            // Create prompt
            let prompt = """
            Analyze this document text and suggest metadata:
            
            \(text)
            
            Format your response as JSON:
            {
              "title": "Suggested document title",
              "folder": "Suggested folder name",
              "tags": ["Tag1", "Tag2", "Tag3"],
              "confidence": 0.85
            }
            """
            
            // Send to OpenAI
            let messages = [
                ["role": "system", "content": "You are a document classification assistant."],
                ["role": "user", "content": prompt]
            ]
            
            // Get the model using our helper property
            let modelToUse = self.currentModel
            print("🤖 Using AI model: \(modelToUse)")
            
            let requestBody: [String: Any] = [
                "model": modelToUse,
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 1000
            ]
            
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let orgId = self.organizationId, !orgId.isEmpty {
                request.addValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
            }
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            } catch {
                print("❌ JSON serialization error: \(error.localizedDescription)")
                let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                promise(result)
                return
            }
            
            // Add better debugging
            print("🌐 Sending request to OpenAI...")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                    promise(result)
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received from OpenAI")
                    let error = NSError(domain: "OpenAIError", code: 3, 
                        userInfo: [NSLocalizedDescriptionKey: "No data received from API"])
                    let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                    promise(result)
                    return
                }
                
                // Log HTTP status
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 OpenAI response status: \(httpResponse.statusCode)")
                    
                    // If not successful, log response body for debugging
                    if httpResponse.statusCode != 200 {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ API Error: \(responseString)")
                        }
                        
                        let error = NSError(domain: "OpenAIError", code: httpResponse.statusCode, 
                            userInfo: [NSLocalizedDescriptionKey: "API returned status \(httpResponse.statusCode)"])
                        let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                        promise(result)
                        return
                    }
                }
                
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Raw OpenAI response: \(responseString)")
                }
                
                do {
                    // Parse the OpenAI response
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    guard let choices = json?["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let message = firstChoice["message"] as? [String: Any],
                          let content = message["content"] as? String,
                          let usage = json?["usage"] as? [String: Any],
                          let promptTokens = usage["prompt_tokens"] as? Int,
                          let completionTokens = usage["completion_tokens"] as? Int,
                          let totalTokens = usage["total_tokens"] as? Int else {
                        print("❌ Failed to parse OpenAI response structure")
                        let error = NSError(domain: "OpenAIParsingError", code: 1, 
                            userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response structure"])
                        let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                        promise(result)
                        return
                    }
                    
                    print("✅ Parsed OpenAI response content: \(content.prefix(100))...")
                    
                    // Extract JSON from content (more resilient approach)
                    if let jsonData = self.extractJSONFromString(content) {
                        do {
                            let parsedJSON = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                            
                            guard let title = parsedJSON?["title"] as? String,
                                  let folder = parsedJSON?["folder"] as? String,
                                  let tags = parsedJSON?["tags"] as? [String],
                                  let confidence = parsedJSON?["confidence"] as? Double else {
                                print("❌ Failed to extract required fields from JSON")
                                let error = NSError(domain: "OpenAIParsingError", code: 2, 
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to extract fields from JSON"])
                                let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                                promise(result)
                                return
                            }
                            
                            // Extract token usage data but don't use it
                            var promptTokens = 0
                            var completionTokens = 0
                            var totalTokens = 0
                            
                            // Get usage data from the OpenAI response
                            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let usage = jsonResponse["usage"] as? [String: Any] {
                                promptTokens = usage["prompt_tokens"] as? Int ?? 0
                                completionTokens = usage["completion_tokens"] as? Int ?? 0
                                totalTokens = usage["total_tokens"] as? Int ?? 0
                                
                                // Log token usage for debugging
                                print("🔢 Token usage - Prompt: \(promptTokens), Completion: \(completionTokens), Total: \(totalTokens)")
                            }
                            
                            // Create suggestions object without token usage
                            let suggestions = DocumentClassifierService.DocumentSuggestions(
                                suggestedTitle: title,
                                suggestedFolderName: folder,
                                suggestedTags: tags,
                                confidence: confidence
                            )
                            
                            print("✅ Successfully created suggestions object")
                            let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .success(suggestions)
                            promise(result)
                        } catch {
                            print("❌ JSON parsing error: \(error.localizedDescription)")
                            let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                            promise(result)
                        }
                    } else {
                        print("❌ Could not extract JSON from response")
                        let error = NSError(domain: "OpenAIParsingError", code: 3, 
                            userInfo: [NSLocalizedDescriptionKey: "Could not extract JSON from response"])
                        let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                        promise(result)
                    }
                } catch {
                    print("❌ Response parsing error: \(error.localizedDescription)")
                    let result: Result<DocumentClassifierService.DocumentSuggestions, Error> = .failure(error)
                    promise(result)
                }
            }.resume()
        }
        .eraseToAnyPublisher()
    }
    
    func testAPIKey() async -> (success: Bool, message: String) {
        guard let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"), !apiKey.isEmpty else {
            return (false, "No API key found in UserDefaults")
        }
        
        // Add detailed debugging
        print("API Key starts with: \(apiKey.prefix(10))")
        if apiKey.starts(with: "/") {
            return (false, "Error: API key appears to be a file path, not a valid OpenAI key")
        }
        if !apiKey.starts(with: "sk-") {
            return (false, "Error: API key should start with 'sk-', found '\(apiKey.prefix(3))' instead")
        }
        
        print("🔑 API Key to test: \(apiKey.prefix(5))...") // Only log the first few characters for security
        
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Invalid response type")
            }
            
            print("🌐 API Test Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                return (true, "Connection successful! API key is valid.")
            } else if httpResponse.statusCode == 401 {
                // Try to get more detailed error information
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorResponse["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    return (false, "Authentication failed: \(message)")
                }
                return (false, "Authentication failed (401): Invalid API key")
            } else {
                return (false, "Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch {
            return (false, "Connection error: \(error.localizedDescription)")
        }
    }
    
    // Add this method for testing your OpenAI API key
    func testOpenAIApiKey() {
        let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? ""
        if apiKey.isEmpty {
            print("⚠️ No API key found in UserDefaults")
            return
        }
        
        print("🔑 Testing API key: \(String(apiKey.prefix(5)))...")
        
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ API test failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 API response: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("✅ API key works correctly!")
                } else {
                    print("❌ API key validation failed with status: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                }
            }
        }.resume()
    }
    
    // Helper method to extract JSON from a string that might contain additional text
    private func extractJSONFromString(_ string: String) -> Data? {
        // Use regex to find content between curly braces, including nested structures
        let pattern = "\\{(?:[^{}]|\\{(?:[^{}]|\\{[^{}]*\\})*\\})*\\}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(string.startIndex..., in: string)
        
        if let match = regex?.firstMatch(in: string, options: [], range: range),
           let matchRange = Range(match.range, in: string) {
            let jsonString = String(string[matchRange])
            print("🔍 Extracted JSON: \(jsonString)")
            return jsonString.data(using: .utf8)
        }
        
        // Fallback method: Try to find JSON by looking for opening/closing braces
        if let startIndex = string.range(of: "{")?.lowerBound,
           let endIndex = string.range(of: "}", options: .backwards)?.upperBound {
            let jsonString = String(string[startIndex..<endIndex])
            print("🔍 Extracted JSON (fallback method): \(jsonString)")
            return jsonString.data(using: .utf8)
        }
        
        return nil
    }
    
    // Add the image+text version of analyzeDocument for compatibility
    func analyzeDocument(image: PlatformImage, ocrText: String, completion: @escaping (DocumentClassifierService.DocumentSuggestions) -> Void) {
        analyzeDocument(withText: ocrText, image: image)
            .sink(
                receiveCompletion: { completionStatus in
                    if case .failure(let error) = completionStatus {
                        print("❌ Error in analyzeDocument: \(error.localizedDescription)")
                        
                        // Return fallback suggestions on error
                        let fallback = self.generateMockAnalysis(for: ocrText)
                        completion(fallback)
                    }
                },
                receiveValue: { suggestions in
                    completion(suggestions)
                }
            )
            .store(in: &cancellables)
    }
    
    // Simplify this method to avoid conflicts
    func analyzeDocumentText(_ text: String) async -> DocumentClassifierService.DocumentSuggestions? {
        guard let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"), !apiKey.isEmpty else {
            print("⚠️ Cannot perform AI analysis: No API key found")
            return generateMockAnalysis(for: text)
        }
        
        print("🔑 Using API key starting with: \(apiKey.prefix(5))...")
        
        // DEBUGGING: Print complete request details
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Get the model using our helper property
        let modelToUse = self.currentModel
        print("🤖 Using AI model for async analysis: \(modelToUse)")
        
        // Simplified prompt for testing
        let requestBody: [String: Any] = [
            "model": modelToUse,
            "messages": [
                ["role": "system", "content": "You are a helpful document classifier."],
                ["role": "user", "content": "Classify this document (max 100 words):\n\(text)"]
            ],
            "max_tokens": 150
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Debug the request being sent
            print("🌐 Sending request to OpenAI with URL: \(url.absoluteString)")
            print("🌐 Request headers: \(request.allHTTPHeaderFields ?? [:])")
            print("🌐 Request body length: \(jsonData.count) bytes")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Debug the response received
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return nil
            }
            
            print("🌐 OpenAI response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                // Attempt to parse error response
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API Error: \(errorString)")
                }
                print("⚠️ AI analysis failed: API returned status \(httpResponse.statusCode)")
                return nil
            }
            
            // Print the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("✅ Raw API response: \(responseString.prefix(200))...")
            }
            
            // Create a simple response with the content
            do {
                let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                
                if let content = response.choices.first?.message.content {
                    // Return sample results for typical document types
                    var title = "Sample Document"
                    var folder = "General"
                    var tags = ["sample"]
                    
                    if text.lowercased().contains("invoice") {
                        title = "Sample Invoice"
                        folder = "Invoices"
                        tags = ["invoice", "bill", "payment"]
                    } else if text.lowercased().contains("receipt") {
                        title = "Store Receipt"
                        folder = "Receipts"
                        tags = ["receipt", "purchase", "store"]
                    } else if text.lowercased().contains("medical") {
                        title = "Medical Document"
                        folder = "Medical"
                        tags = ["health", "medical", "doctor"]
                    }
                    
                    // Create simple suggestions
                    let suggestions = DocumentClassifierService.DocumentSuggestions(
                        suggestedTitle: title,
                        suggestedFolderName: folder,
                        suggestedTags: tags,
                        confidence: 0.7
                    )
                    
                    return suggestions
                }
            } catch {
                print("❌ Failed to parse OpenAI response: \(error)")
            }
            
            return nil
        } catch {
            print("❌ OpenAI API error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Helper struct for JSON parsing
    struct OpenAIResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let message: Message
        }
        
        let choices: [Choice]
    }
    
    // This mock implementation provides an AI analysis method that doesn't rely on network calls
    func generateMockAnalysis(for text: String) -> DocumentClassifierService.DocumentSuggestions {
        // Return mock results for typical document types based on content
        var title = "Untitled Document"
        var folder = "General"
        var tags = ["document"]
        var confidence = 0.7
        
        // Basic document classification logic
        if text.lowercased().contains("invoice") {
            title = "Invoice Document"
            folder = "Invoices"
            tags = ["invoice", "bill", "payment"]
            confidence = 0.85
        } else if text.lowercased().contains("receipt") {
            title = "Store Receipt"
            folder = "Receipts" 
            tags = ["receipt", "purchase", "store"]
            confidence = 0.9
        } else if text.lowercased().contains("medical") {
            title = "Medical Document"
            folder = "Medical"
            tags = ["health", "medical", "doctor"]
            confidence = 0.8
        } else if text.lowercased().contains("tax") {
            title = "Tax Document"
            folder = "Taxes"
            tags = ["tax", "financial", "government"]
            confidence = 0.85
        }
        
        // Create simple suggestions
        let suggestions = DocumentClassifierService.DocumentSuggestions(
            suggestedTitle: title,
            suggestedFolderName: folder,
            suggestedTags: tags,
            confidence: confidence
        )
        
        return suggestions
    }
} 
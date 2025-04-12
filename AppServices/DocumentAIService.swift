import Foundation

class DocumentAIService {
    static let shared = DocumentAIService()
    
    private init() {}
    
    func analyzeDocument(text: String) async throws -> DocumentClassifierService.DocumentSuggestions {
        print("📄 Starting document analysis...")
        
        // Create the base prompt
        let basePrompt = getClassificationPrompt()
        
        // Enhance the prompt with adaptive learning
        let enhancedPrompt = AdaptiveLearningClassifier.shared.enhancePromptWithLearning(
            documentText: text,
            basePrompt: basePrompt
        )
        
        // Add the actual text to the prompt
        let fullPrompt = enhancedPrompt + "\n\n" + text
        
        // In a real implementation, this would call OpenAI or another AI service
        let modelName = UserDefaults.standard.string(forKey: "AI Classifier Model") ?? "gpt-3.5-turbo-0125"
        print("🤖 Using model for document analysis: \(modelName)")
        
        // Ensure folder gets a proper value based on document content
        let suggestedFolder = determineFolderFromText(text)
        print("📁 Determined folder: \(suggestedFolder)")
        
        // Generate a more relevant title based on text content
        var title = "Document"
        if let firstLine = text.components(separatedBy: .newlines).first, !firstLine.isEmpty {
            // Use first line if it's not too long, otherwise use a substring
            title = firstLine.count <= 40 ? firstLine : String(firstLine.prefix(37)) + "..."
        }
        
        // Generate tags based on text content
        var tags = ["document"]
        
        // Add category as a tag
        if suggestedFolder != "General" {
            tags.append(suggestedFolder.lowercased())
        }
        
        // Add additional tags based on content
        let lowercasedText = text.lowercased()
        if lowercasedText.contains("invoice") || lowercasedText.contains("payment") {
            tags.append("invoice")
            tags.append("payment")
        } else if lowercasedText.contains("receipt") {
            tags.append("receipt")
            tags.append("purchase")
        } else if lowercasedText.contains("medical") || lowercasedText.contains("health") {
            tags.append("medical")
            tags.append("healthcare")
        } else if lowercasedText.contains("tax") {
            tags.append("tax")
            tags.append("financial")
        }
        
        // Remove duplicates in tags
        tags = Array(Set(tags))
        
        // Create token usage for tracking
        let promptTokens = fullPrompt.count / 4  // Rough approximation of token count
        let completionTokens = 100  // Mock value
        let totalTokens = promptTokens + completionTokens
        
        let tokenUsage = DocumentClassifierService.DocumentSuggestions.TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            model: modelName
        )
        
        // Create the suggestions
        let suggestions = DocumentClassifierService.DocumentSuggestions(
            suggestedTitle: title,
            suggestedFolderName: suggestedFolder,
            suggestedTags: tags,
            confidence: 0.85,
            tokenUsage: tokenUsage
        )
        
        // Log the analysis result
        print("✅ Document analyzed:")
        print("   Title: \(suggestions.suggestedTitle)")
        print("   Folder: \(suggestions.suggestedFolderName ?? "None")")
        print("   Tags: \(suggestions.suggestedTags.joined(separator: ", "))")
        print("   Token Usage: \(tokenUsage.totalTokens) tokens")
        
        return suggestions
    }
    
    // Add this method to get the classification prompt
    private func getClassificationPrompt() -> String {
        return """
        Analyze the following document and suggest a title, folder name, and relevant tags.
        Return the response in JSON format with the following fields:
        - title: A concise document title based on the content
        - folder: A folder name that logically categorizes this document
        - tags: An array of 3-5 relevant tags
        - confidence: A value between 0 and 1 indicating your confidence in this classification

        DOCUMENT TEXT:
        """
    }
    
    // Helper method to determine folder from text
    private func determineFolderFromText(_ text: String) -> String {
        // Simple logic to guess a folder based on content
        // In a real implementation, this would be more sophisticated
        
        let lowercasedText = text.lowercased()
        
        if lowercasedText.contains("invoice") || lowercasedText.contains("payment") {
            return "Invoices"
        } else if lowercasedText.contains("receipt") || lowercasedText.contains("purchase") {
            return "Receipts"
        } else if lowercasedText.contains("medical") || lowercasedText.contains("health") {
            return "Medical"
        } else if lowercasedText.contains("tax") || lowercasedText.contains("irs") {
            return "Tax Documents"
        } else if lowercasedText.contains("utility") || lowercasedText.contains("bill") {
            return "Utilities"
        } else {
            return "General"
        }
    }
    
    // Find the method that calls OpenAI for document classification
    func classifyDocument(text: String, completion: @escaping (Result<DocumentClassifierService.DocumentSuggestions, Error>) -> Void) {
        // Skip empty text
        guard !text.isEmpty else {
            let error = NSError(domain: "DocumentClassifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot classify empty text"])
            completion(.failure(error))
            return
        }
        
        print("📄 Starting document classification...")
        
        // Check if we should use the adaptive learning system to enhance the prompt
        let basePrompt = getClassificationPrompt()
        
        // Apply adaptive learning enhancement
        let enhancedPrompt = AdaptiveLearningClassifier.shared.enhancePromptWithLearning(
            documentText: text,
            basePrompt: basePrompt
        )
        
        // Log if adaptively enhanced
        if basePrompt != enhancedPrompt {
            print("🧠 Using adaptively enhanced prompt based on learning patterns")
        }
        
        // For a real implementation, this would call OpenAI
        // In this mock version, we'll simulate different results based on text content
        let modelName = UserDefaults.standard.string(forKey: "AI Classifier Model") ?? "gpt-3.5-turbo-0125"
        print("🤖 Using model for classification: \(modelName)")
        
        // Use the helper method to determine a folder
        let folder = determineFolderFromText(text)
        
        // Generate a more relevant title based on text content
        var title = "Document"
        if let firstLine = text.components(separatedBy: .newlines).first, !firstLine.isEmpty {
            // Use first line if it's not too long, otherwise use a substring
            title = firstLine.count <= 40 ? firstLine : String(firstLine.prefix(37)) + "..."
        }
        
        // Generate tags based on text content
        var tags = ["document"]
        
        // Add category as a tag
        if folder != "General" {
            tags.append(folder.lowercased())
        }
        
        // Add additional tags based on content
        let lowercasedText = text.lowercased()
        if lowercasedText.contains("invoice") || lowercasedText.contains("payment") {
            tags.append("invoice")
            tags.append("payment")
        } else if lowercasedText.contains("receipt") {
            tags.append("receipt")
            tags.append("purchase")
        } else if lowercasedText.contains("medical") || lowercasedText.contains("health") {
            tags.append("medical")
            tags.append("healthcare")
        } else if lowercasedText.contains("tax") {
            tags.append("tax")
            tags.append("financial")
        }
        
        // Remove duplicates in tags
        tags = Array(Set(tags))
        
        // Create token usage for tracking
        let promptTokens = enhancedPrompt.count / 4  // Rough approximation of token count
        let completionTokens = 100  // Mock value
        let totalTokens = promptTokens + completionTokens
        
        let tokenUsage = DocumentClassifierService.DocumentSuggestions.TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            model: modelName
        )
        
        // Create the suggestions
        let mockSuggestion = DocumentClassifierService.DocumentSuggestions(
            suggestedTitle: title,
            suggestedFolderName: folder,
            suggestedTags: tags,
            confidence: 0.85,
            tokenUsage: tokenUsage
        )
        
        // Log the classification result
        print("✅ Document classified:")
        print("   Title: \(mockSuggestion.suggestedTitle)")
        print("   Folder: \(mockSuggestion.suggestedFolderName ?? "None")")
        print("   Tags: \(mockSuggestion.suggestedTags.joined(separator: ", "))")
        print("   Token Usage: \(tokenUsage.totalTokens) tokens")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(mockSuggestion))
        }
    }
    
    // Add this method to get OpenAI API key
    private func getOpenAIAPIKey() -> String? {
        return UserDefaults.standard.string(forKey: "OpenAIAPIKey")
    }
} 
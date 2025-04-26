import Foundation
import CoreML
import Vision
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import NaturalLanguage
import CoreData
import Combine
import Security // For KeychainManager usage

// MARK: - Document Classifier Service
class DocumentClassifierService {
    // Remove direct assignment, just declare type
    private let persistenceController: PersistenceController
    private var openAIService: OpenAIService?
    private var cancellables = Set<AnyCancellable>()
    private let documentAIService: DocumentAIService
    
    // Define DocumentSuggestions structure
    struct DocumentSuggestions {
        let suggestedTitle: String
        let suggestedFolderName: String?
        let suggestedTags: [String]
        let confidence: Double
        let tokenUsage: TokenUsage?
        let folderConfidences: [String: Double]?
        
        // Convenience property aliases for easier access
        var title: String { return suggestedTitle }
        var folder: String { return suggestedFolderName ?? "Uncategorized" }
        var tags: [String] { return suggestedTags }
        
        // Add TokenUsage struct to DocumentSuggestions
        struct TokenUsage {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int
            let estimatedCost: Double?
            let model: String?
            
            init(promptTokens: Int, completionTokens: Int, totalTokens: Int, estimatedCost: Double? = nil, model: String? = nil) {
                self.promptTokens = promptTokens
                self.completionTokens = completionTokens
                self.totalTokens = totalTokens
                self.estimatedCost = estimatedCost
                self.model = model
            }
        }
        
        // Default initializer with optional tokenUsage and folderConfidences
        init(suggestedTitle: String, suggestedFolderName: String?, suggestedTags: [String], confidence: Double, tokenUsage: TokenUsage? = nil, folderConfidences: [String: Double]? = nil) {
            self.suggestedTitle = suggestedTitle
            self.suggestedFolderName = suggestedFolderName
            self.suggestedTags = suggestedTags
            self.confidence = confidence
            self.tokenUsage = tokenUsage
            self.folderConfidences = folderConfidences
        }
    }
    
    // Remove the shared instance
    // static let shared = DocumentClassifierService()
    
    // Basic types of documents we might identify
    enum DocumentCategory: String {
        case invoice, receipt, statement, report, letter, medical, tax, utility, other
    }
    
    // Initialize with OpenAI API key - change to accept controller
    init(persistenceController: PersistenceController, documentAIService: DocumentAIService) {
        self.persistenceController = persistenceController // Assign injected controller
        self.documentAIService = documentAIService
        self.openAIService = OpenAIService(apiKey: getOpenAIAPIKey() ?? "")
        print("🔍 Document classifier service initialized with persistence controller")
    }
    
    // MARK: - Document Analysis
    
    /// Analyze document text and provide AI suggestions
    func analyzeDocument(withText text: String, image: PlatformImage? = nil) -> AnyPublisher<DocumentSuggestions, Error> {
        // This is a placeholder implementation
        // The real implementation would use AI services to analyze the document
        return Future<DocumentSuggestions, Error> { promise in
            Task {
                do {
                    // Call DocumentAIService to analyze the document
                    let suggestions = try await self.documentAIService.analyzeDocument(text: text)
                    promise(.success(suggestions))
                } catch {
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Text Analysis Methods
    
    private func analyzeDocumentText(_ text: String) -> [String: Any] {
        var analysis: [String: Any] = [:]
        
        // Check for empty text
        guard !text.isEmpty else {
            return ["category": DocumentCategory.other.rawValue, "confidence": 0.0]
        }
        
        // Extract key information
        analysis["entities"] = extractEntities(from: text)
        analysis["keywords"] = extractKeywords(from: text)
        analysis["dates"] = extractDates(from: text)
        analysis["amounts"] = extractAmounts(from: text)
        
        // Categorize document using patterns
        let (category, confidence) = categorizeDocument(text: text)
        analysis["category"] = category.rawValue
        analysis["confidence"] = confidence
        
        return analysis
    }
    
    private func extractEntities(from text: String) -> [String: String] {
        var entities: [String: String] = [:]
        
        // Use NLTagger to identify entities
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entity = String(text[range])
                
                switch tag {
                case .organizationName:
                    entities["organization"] = entity
                case .personalName:
                    entities["person"] = entity
                case .placeName:
                    entities["place"] = entity
                default:
                    break
                }
            }
            return true
        }
        
        // Simple regex for common entities like emails, phone numbers
        if let email = text.range(of: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", options: .regularExpression) {
            entities["email"] = String(text[email])
        }
        
        return entities
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // Extract most significant terms using TF-IDF-like approach
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 3 } // Filter out very short words
        
        let wordCounts = Dictionary(grouping: words, by: { $0 })
            .mapValues { $0.count }
        
        // Sort by frequency and return top 10
        return Array(wordCounts.sorted { $0.value > $1.value }.prefix(10).map { $0.key })
    }
    
    private func extractDates(from text: String) -> [Date] {
        var dates: [Date] = []
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        
        if let detector = detector {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            for match in matches {
                if let date = match.date {
                    dates.append(date)
                }
            }
        }
        
        return dates
    }
    
    private func extractAmounts(from text: String) -> [Double] {
        var amounts: [Double] = []
        
        // Match currency patterns like $123.45, 123.45 USD, etc.
        let pattern = "\\$?\\s*[0-9]{1,3}(?:,?[0-9]{3})*(?:\\.[0-9]{2})?"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            for match in matches {
                let range = match.range
                if let swiftRange = Range(range, in: text) {
                    let amountStr = text[swiftRange]
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    
                    if let amount = Double(amountStr) {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        return amounts
    }
    
    private func categorizeDocument(text: String) -> (DocumentCategory, Double) {
        let lowercaseText = text.lowercased()
        
        // Check for invoice patterns
        if lowercaseText.contains("invoice") || lowercaseText.contains("bill to") || lowercaseText.contains("payment due") {
            return (.invoice, 0.8)
        }
        
        // Check for receipt patterns
        if lowercaseText.contains("receipt") || lowercaseText.contains("thank you for your purchase") || 
           lowercaseText.contains("total:") || lowercaseText.contains("subtotal:") {
            return (.receipt, 0.8)
        }
        
        // Check for statement patterns
        if lowercaseText.contains("statement") || lowercaseText.contains("account summary") || 
           lowercaseText.contains("balance due") || lowercaseText.contains("transaction history") {
            return (.statement, 0.8)
        }
        
        // Check for report patterns
        if lowercaseText.contains("report") || lowercaseText.contains("analysis") || 
           lowercaseText.contains("summary of findings") {
            return (.report, 0.7)
        }
        
        // Check for medical document patterns
        if lowercaseText.contains("patient") || lowercaseText.contains("diagnosis") || 
           lowercaseText.contains("prescription") || lowercaseText.contains("medical") {
            return (.medical, 0.8)
        }
        
        // Check for tax document patterns
        if lowercaseText.contains("tax") || lowercaseText.contains("irs") || 
           lowercaseText.contains("form 1040") || lowercaseText.contains("w-2") || 
           lowercaseText.contains("income tax") {
            return (.tax, 0.9)
        }
        
        // Check for utility bill patterns
        if lowercaseText.contains("utility") || lowercaseText.contains("electric") || 
           lowercaseText.contains("water bill") || lowercaseText.contains("gas bill") || 
           lowercaseText.contains("service address") {
            return (.utility, 0.8)
        }
        
        // Default case with low confidence
        return (.other, 0.3)
    }
    
    // MARK: - Layout Analysis Methods
    
    private func analyzeDocumentLayout(image: PlatformImage) -> [String: Any] {
        // Simple layout analysis - could be expanded with Vision framework
        var analysis: [String: Any] = [:]
        
        // Detect if receipt-like (long and narrow)
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio < 0.7 {
            analysis["isReceiptShaped"] = true
        }
        
        // More sophisticated layout analysis could be added here
        
        return analysis
    }
    
    // MARK: - Context Methods
    
    private func fetchExistingDocumentsMetadata() -> [DocumentMetadata] {
        let context = persistenceController.container.viewContext
        let fetchRequest = NSFetchRequest<Document>(entityName: "Document")
        fetchRequest.predicate = NSPredicate(value: true) // Get all documents
        
        // Only fetch the fields we need
        fetchRequest.propertiesToFetch = ["title", "folderId", "text", "id"]
        
        do {
            let documents = try context.fetch(fetchRequest)
            
            // Convert to lightweight metadata objects
            return documents.compactMap { document in
                guard let id = document.id, let title = document.title else { return nil }
                
                // Fetch associated tags
                var tagNames: [String] = []
                if let tags = document.tags as? Set<Tag> {
                    tagNames = tags.compactMap { $0.name }
                }
                
                // Fetch folder name
                var folderName: String?
                if let folderId = document.folderId {
                    let folderRequest = NSFetchRequest<Folder>(entityName: "Folder")
                    folderRequest.predicate = NSPredicate(format: "entityId == %@", folderId as CVarArg)
                    folderRequest.fetchLimit = 1
                    
                    if let folders = try? context.fetch(folderRequest), let folder = folders.first {
                        folderName = folder.name
                    }
                }
                
                return DocumentMetadata(
                    id: id,
                    title: title,
                    text: document.text ?? "",
                    folderId: document.folderId,
                    folderName: folderName,
                    tagNames: tagNames
                )
            }
        } catch {
            print("Error fetching documents: \(error)")
            return []
        }
    }
    
    // Structure to hold document metadata
    struct DocumentMetadata {
        var id: UUID
        var title: String
        var text: String
        var folderId: UUID?
        var folderName: String?
        var tagNames: [String]
    }
    
    // MARK: - Suggestion Generation
    
    private func generateSuggestions(
        ocrText: String,
        textAnalysis: [String: Any],
        layoutAnalysis: [String: Any],
        existingDocuments: [DocumentMetadata]
    ) -> DocumentSuggestions {
        // Extract category and confidence
        let category = DocumentCategory(rawValue: textAnalysis["category"] as? String ?? "other") ?? .other
        let baseConfidence = textAnalysis["confidence"] as? Double ?? 0.3
        
        // Generate title based on entity extraction and document category
        let title = generateTitle(category: category, textAnalysis: textAnalysis)
        
        // Find the most appropriate folder
        let (folderId, folderName) = suggestFolder(
            category: category,
            textAnalysis: textAnalysis,
            existingDocuments: existingDocuments
        )
        
        // Suggest tags based on content and similar documents
        let suggestedTags = suggestTags(
            category: category,
            textAnalysis: textAnalysis,
            existingDocuments: existingDocuments
        )
        
        // Calculate final confidence score
        let confidence = calculateConfidence(
            baseConfidence: baseConfidence,
            title: title,
            hasFolderSuggestion: folderId != nil,
            tagCount: suggestedTags.count
        )
        
        return DocumentSuggestions(
            suggestedTitle: title,
            suggestedFolderName: folderName,
            suggestedTags: suggestedTags,
            confidence: confidence,
            tokenUsage: nil,
            folderConfidences: nil
        )
    }
    
    private func generateTitle(category: DocumentCategory, textAnalysis: [String: Any]) -> String {
        let entities = textAnalysis["entities"] as? [String: String] ?? [:]
        let dates = textAnalysis["dates"] as? [Date] ?? []
        let keywords = textAnalysis["keywords"] as? [String] ?? []
        
        var titleComponents: [String] = []
        
        // Add category as prefix
        titleComponents.append(category.rawValue.capitalized)
        
        // Add organization if available
        if let organization = entities["organization"] {
            titleComponents.append("- \(organization)")
        }
        
        // Add date in format MMM YYYY if available
        if let firstDate = dates.first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM yyyy"
            titleComponents.append("- \(dateFormatter.string(from: firstDate))")
        }
        
        // Add amount for financial documents
        if let amounts = textAnalysis["amounts"] as? [Double], let firstAmount = amounts.first,
           [.invoice, .receipt, .statement].contains(category) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .currency
            if let formattedAmount = numberFormatter.string(from: NSNumber(value: firstAmount)) {
                titleComponents.append("- \(formattedAmount)")
            }
        }
        
        // If we have a minimal title, add first keyword
        if titleComponents.count < 3, let firstKeyword = keywords.first {
            titleComponents.append("- \(firstKeyword.capitalized)")
        }
        
        return titleComponents.joined(separator: " ")
    }
    
    private func suggestFolder(
        category: DocumentCategory,
        textAnalysis: [String: Any],
        existingDocuments: [DocumentMetadata]
    ) -> (UUID?, String?) {
        // Create a document fingerprint from entities and keywords
        let entities = textAnalysis["entities"] as? [String: String] ?? [:]
        let keywords = textAnalysis["keywords"] as? [String] ?? []
        let documentFingerprint = Set(entities.values + keywords)
        
        // Find similar documents and check their folders
        var folderCounts: [UUID: (count: Int, name: String)] = [:]
        
        for document in existingDocuments {
            // Skip documents without folders
            guard let folderId = document.folderId, let folderName = document.folderName else { continue }
            
            // Create document fingerprint
            let docWords = document.text.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            let docFingerprint = Set(docWords)
            
            // Calculate similarity (Jaccard index)
            let intersection = documentFingerprint.intersection(docFingerprint).count
            let union = documentFingerprint.union(docFingerprint).count
            let similarity = union > 0 ? Double(intersection) / Double(union) : 0
            
            // If similar enough, count this folder
            if similarity > 0.15 {
                if let existing = folderCounts[folderId] {
                    folderCounts[folderId] = (existing.count + 1, existing.name)
                } else {
                    folderCounts[folderId] = (1, folderName)
                }
            }
        }
        
        // Get most common folder
        if let topFolder = folderCounts.max(by: { $0.value.count < $1.value.count }) {
            return (topFolder.key, topFolder.value.name)
        }
        
        // Fallback to category-based folder suggestion
        let suggestedFolderName: String
        
        switch category {
        case .invoice, .receipt:
            suggestedFolderName = "Financial"
        case .tax:
            suggestedFolderName = "Taxes"
        case .medical:
            suggestedFolderName = "Medical"
        case .utility:
            suggestedFolderName = "Utilities"
        case .letter:
            suggestedFolderName = "Correspondence"
        case .report:
            suggestedFolderName = "Reports"
        case .statement:
            suggestedFolderName = "Statements"
        case .other:
            suggestedFolderName = "Miscellaneous"
        }
        
        // Check if this folder already exists
        for doc in existingDocuments {
            if doc.folderName == suggestedFolderName, let id = doc.folderId {
                return (id, suggestedFolderName)
            }
        }
        
        // No folder ID, but suggest a name for a new folder
        return (nil, suggestedFolderName)
    }
    
    private func suggestTags(
        category: DocumentCategory,
        textAnalysis: [String: Any],
        existingDocuments: [DocumentMetadata]
    ) -> [String] {
        var suggestedTags: Set<String> = []
        
        // Add category tag
        suggestedTags.insert(category.rawValue.capitalized)
        
        // Add organization as tag if available
        if let organization = (textAnalysis["entities"] as? [String: String])?["organization"] {
            suggestedTags.insert(organization)
        }
        
        // Add year as tag if dates available
        if let dates = textAnalysis["dates"] as? [Date], let firstDate = dates.first {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: firstDate)
            suggestedTags.insert("\(year)")
        }
        
        // Add special case tags based on category
        switch category {
        case .invoice, .receipt:
            if let amounts = textAnalysis["amounts"] as? [Double], let amount = amounts.max() {
                if amount > 1000 {
                    suggestedTags.insert("High Value")
                }
            }
        case .tax:
            suggestedTags.insert("Important")
            suggestedTags.insert("Tax Documents")
        case .medical:
            suggestedTags.insert("Health")
        default:
            break
        }
        
        // Find common tags from similar documents (limit to 5 total tags)
        if suggestedTags.count < 5 {
            let keywords = textAnalysis["keywords"] as? [String] ?? []
            let documentFingerprint = Set(keywords)
            
            var tagCounts: [String: Int] = [:]
            
            for document in existingDocuments {
                // Skip documents without tags
                guard !document.tagNames.isEmpty else { continue }
                
                // Create document fingerprint
                let docWords = document.text.components(separatedBy: .whitespacesAndNewlines)
                    .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                let docFingerprint = Set(docWords)
                
                // Calculate similarity (Jaccard index)
                let intersection = documentFingerprint.intersection(docFingerprint).count
                let union = documentFingerprint.union(docFingerprint).count
                let similarity = union > 0 ? Double(intersection) / Double(union) : 0
                
                // If similar enough, count this document's tags
                if similarity > 0.1 {
                    for tag in document.tagNames {
                        tagCounts[tag, default: 0] += 1
                    }
                }
            }
            
            // Add most common tags until we reach limit
            let sortedTags = tagCounts.sorted { $0.value > $1.value }
            for (tag, _) in sortedTags {
                if suggestedTags.count < 5 && !suggestedTags.contains(tag) {
                    suggestedTags.insert(tag)
                }
            }
        }
        
        return Array(suggestedTags)
    }
    
    private func calculateConfidence(
        baseConfidence: Double,
        title: String,
        hasFolderSuggestion: Bool,
        tagCount: Int
    ) -> Double {
        var confidence = baseConfidence
        
        // Adjust based on title quality
        let titleComponents = title.components(separatedBy: " - ")
        confidence += Double(titleComponents.count) * 0.05
        
        // Adjust based on folder suggestion
        if hasFolderSuggestion {
            confidence += 0.1
        }
        
        // Adjust based on tag count
        confidence += Double(tagCount) * 0.05
        
        // Ensure confidence is in [0, 1] range
        return min(max(confidence, 0.0), 1.0)
    }
    
    // MARK: - OpenAI Integration
    
    private func getOpenAIAPIKey() -> String? {
        // First try to get the key from the keychain
        if let keychainKey = KeychainManager.shared.getAPIKey(service: "OpenAI", account: "DocumentClassification"), !keychainKey.isEmpty {
            return keychainKey
        }
        
        // If keychain access fails, try to get from UserDefaults as fallback
        if let userDefaultsKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"), !userDefaultsKey.isEmpty {
            print("🔑 Using API key from UserDefaults")
            return userDefaultsKey
        }
        
        return nil
    }
    
    // System role for the OpenAI model
    private var systemRole: String {
        return """
        You are an intelligent document analyzer that helps users classify and organize their documents.
        When analyzing a document, identify the most appropriate title, folder, and tags.
        Make titles concise but descriptive. Folder names should categorize the document type.
        Tags should include relevant keywords that help identify the document content.
        Return your analysis in the requested JSON format only.
        """
    }
    
    // JSON instructions for the OpenAI model
    private var jsonInstructions: String {
        return """
        {
          "title": "A concise but descriptive document title following existing patterns",
          "folder": "An existing folder name if 30%+ match, otherwise a logical new folder",
          "tags": ["Up to 4 tags maximum", "Prioritize existing tags", "Most relevant only"],
          "confidence": "A number between 0 and 1 indicating confidence in your analysis"
        }
        
        IMPORTANT: Include a folderConfidences object with confidence scores for each existing folder.
        """
    }
    
    // Parse the JSON response from OpenAI
    private func parseJsonResponse(_ jsonResponse: OpenAIService.JSONResponse, metadata: [String: Any]? = nil) throws -> DocumentSuggestions {
        // Check if we have a valid response
        guard let content = jsonResponse.content,
              let data = content.data(using: .utf8) else {
            throw NSError(domain: "DocumentClassifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"])
        }
        
        // Try to parse the JSON
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let json = json,
                  let title = json["title"] as? String,
                  let folder = json["folder"] as? String,
                  let tags = json["tags"] as? [String],
                  let confidence = json["confidence"] as? Double else {
                throw NSError(domain: "DocumentClassifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
            }
            
            // Extract folder confidence scores if available
            let folderConfidences = json["folderConfidences"] as? [String: Double]
            
            // Check for missing folder evaluations if we have metadata access
            if let confidences = folderConfidences, let metadata = metadata {
                let existingFolders = metadata["existingFolders"] as? [String] ?? []
                
                if !existingFolders.isEmpty {
                    // Check if all expected folders are included
                    let missingFolders = existingFolders.filter { !confidences.keys.contains($0) }
                    
                    if missingFolders.isEmpty {
                        print("✅ AI folder evaluation check: All \(existingFolders.count) folders properly evaluated")
                    } else {
                        print("⚠️ WARNING: AI evaluation is incomplete - missing \(missingFolders.count) folders:")
                        for (index, folder) in missingFolders.enumerated() {
                            print("   \(index+1). Missing evaluation for: \"\(folder)\"")
                        }
                    }
                }
            }
            
            // Log folder confidence scores if available
            if let confidences = folderConfidences {
                print("📊 Folder confidence scores:")
                for (folderName, score) in confidences.sorted(by: { $0.value > $1.value }) {
                    // Format score as percentage for readability
                    let percentScore = Int(score * 100)
                    print("   - \(folderName): \(percentScore)%")
                }
                
                // Log the selected folder with its confidence score
                if let selectedFolderScore = confidences[folder] {
                    let percentScore = Int(selectedFolderScore * 100)
                    print("📁 Selected folder \"\(folder)\" with confidence: \(percentScore)%")
                }
            }
            
            // Create token usage if available
            var tokenUsage: DocumentSuggestions.TokenUsage? = nil
            if let usage = jsonResponse.usage {
                tokenUsage = DocumentSuggestions.TokenUsage(
                    promptTokens: usage.promptTokens,
                    completionTokens: usage.completionTokens,
                    totalTokens: usage.totalTokens,
                    estimatedCost: usage.estimatedCost,
                    model: nil
                )
            }
            
            // Log the folder suggestion for debugging
            print("📁 Parsed folder suggestion: \"\(folder)\"")
            
            // Limit tags to 4 maximum as per our guidelines
            let limitedTags = Array(tags.prefix(4))
            print("🏷️ Limited tags to \(limitedTags.count)/\(tags.count) tags: \(limitedTags.joined(separator: ", "))")
            
            // Create DocumentSuggestions object with token usage and folder confidences
            return DocumentSuggestions(
                suggestedTitle: title,
                suggestedFolderName: folder,
                suggestedTags: limitedTags,
                confidence: confidence,
                tokenUsage: tokenUsage,
                folderConfidences: folderConfidences
            )
        } catch {
            print("❌ Error parsing JSON: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func enhanceSuggestionsWithOpenAI(
        ocrText: String,
        existingDocuments: [DocumentMetadata],
        completion: @escaping (DocumentSuggestions) -> Void
    ) {
        // This would be implemented to call OpenAI API with document context
        // For now, just return a placeholder implementation
        let suggestions = DocumentSuggestions(
            suggestedTitle: "AI Enhanced Document",
            suggestedFolderName: "AI Recommended",
            suggestedTags: ["AI", "Enhanced"],
            confidence: 0.8,
            tokenUsage: nil,
            folderConfidences: nil
        )
        
        completion(suggestions)
    }
    
    // Create a detailed prompt for GPT-3.5-Turbo
    private func createOpenAIPrompt(documentText: String, metadataContext: DocumentMetadataContext) -> String {
        // Create a more structured prompt
        var enrichedPrompt = "Analyze the following document and suggest metadata:\n\n"
        enrichedPrompt += documentText + "\n\n"
        
        // Add context about existing metadata
        if !metadataContext.titles.isEmpty {
            enrichedPrompt += "EXISTING DOCUMENT TITLES: " + metadataContext.titles.joined(separator: ", ") + "\n\n"
        }
        
        if !metadataContext.tags.isEmpty {
            enrichedPrompt += "EXISTING TAGS: " + metadataContext.tags.joined(separator: ", ") + "\n\n"
        }
        
        if !metadataContext.folders.isEmpty {
            enrichedPrompt += "EXISTING FOLDERS: " + metadataContext.folders.joined(separator: ", ") + "\n\n"
        }
        
        // Add instructions for the output format
        enrichedPrompt += """
        Format your response as JSON:
        {
          "title": "A descriptive document title",
          "folder": "A suggested folder (preferably one from the existing folders listed above)",
          "tags": ["Tag1", "Tag2", "Tag3"],
          "confidence": 0.85,
          "folderConfidences": {
            "existingFolder1": 0.85, // Example confidence score (0-1) for this folder
            "existingFolder2": 0.45, // Include confidence scores for all provided existing folders
            "...": "etc for each existing folder"
          }
        }
        
        IMPORTANT: Include a folderConfidences object with confidence scores for each existing folder.
        """
        
        return enrichedPrompt
    }
    
    func setupOpenAIAPIKey(_ apiKey: String) -> Bool {
        // Save to keychain for secure storage
        let success = KeychainManager.shared.saveAPIKey(key: apiKey, service: "OpenAI", account: "DocumentClassification")
        
        // Also save to UserDefaults for consistency with the AI Research feature
        // Note: This is less secure but ensures both features work with the same key
        UserDefaults.standard.set(apiKey, forKey: "OpenAIAPIKey")
        print("🔑 API key saved to both Keychain and UserDefaults for consistency")
        
        if success {
            self.openAIService = OpenAIService(apiKey: apiKey)
        }
        return success
    }
    
    // MARK: - Metadata Context
    
    public struct DocumentMetadataContext {
        let titles: [String]
        let tags: [String]
        let folders: [String]
    }
    
    // Fetch existing metadata for context
    private func fetchExistingMetadataContext() -> DocumentMetadataContext {
        // In a real implementation, this would fetch from CoreData
        // This is a placeholder implementation
        return DocumentMetadataContext(titles: [], tags: [], folders: [])
    }
    
    func classifyDocument(text: String, progressCallback: ((Double) -> Void)? = nil) async throws -> DocumentSuggestions {
        // Implement document classification logic using OpenAI
        progressCallback?(0.1)
        
        let prompt = createClassificationPrompt(text: text)
        progressCallback?(0.3)
        
        // Ensure OpenAI service is initialized
        guard let service = openAIService else {
            throw NSError(domain: "DocumentClassifier", code: 4, userInfo: [NSLocalizedDescriptionKey: "OpenAI service not initialized"])
        }
        
        // Get the model from UserDefaults instead of hardcoding
        let modelName = UserDefaults.standard.string(forKey: "AI Classifier Model") ?? "gpt-4-turbo"
        print("🤖 Using model for document classification: \(modelName)")
        
        let jsonResponse = try await service.generateStructuredResponse(
            prompt: prompt,
            instructions: jsonInstructions,
            systemRole: systemRole,
            modelName: modelName,
            maxTokens: 500,
            temperature: 0.0,
            includeUsage: true
        )
        
        // Parse the JSON response
        let aiSuggestions = try parseJsonResponse(jsonResponse, metadata: nil)
        
        // Use AdaptiveLearningClassifier directly instead of DocumentLearningService
        // This avoids the dependency on DocumentLearningService
        progressCallback?(0.9)
        
        // Skip enhancement since we don't need it for the core functionality
        print("📚 Using document classification without enhancement patterns")
        
        progressCallback?(1.0)
        
        return aiSuggestions
    }
    
    // Function to classify document with metadata context
    func classifyDocumentWithMetadata(text: String, metadata: [String: Any]) async throws -> DocumentSuggestions {
        // Create an enhanced prompt with the metadata context
        let enhancedPrompt = createMetadataEnrichedPrompt(text: text, metadata: metadata)
        
        // Ensure OpenAI service is initialized
        guard let service = openAIService else {
            throw NSError(domain: "DocumentClassifier", code: 4, userInfo: [NSLocalizedDescriptionKey: "OpenAI service not initialized"])
        }
        
        // Get the model from UserDefaults instead of hardcoding
        let modelName = UserDefaults.standard.string(forKey: "AI Classifier Model") ?? "gpt-4-turbo"
        print("🤖 Using model for document classification with metadata: \(modelName)")
        
        // Call OpenAI with the enhanced prompt
        let jsonResponse = try await service.generateStructuredResponse(
            prompt: enhancedPrompt,
            instructions: jsonInstructions,
            systemRole: systemRoleWithMetadata,
            modelName: modelName,
            maxTokens: 500,
            temperature: 0.0,
            includeUsage: true
        )
        
        // Parse the response
        let suggestions = try parseJsonResponse(jsonResponse, metadata: metadata)
        return suggestions
    }
    
    // MARK: - Private Methods
    
    private func createMetadataEnrichedPrompt(text: String, metadata: [String: Any]) -> String {
        var prompt = """
        DOCUMENT CONTENT:
        \(text)
        
        """
        
        // Add existing titles as context if available
        if let existingTitles = metadata["existingTitles"] as? [String], !existingTitles.isEmpty {
            prompt += "\nEXISTING DOCUMENT TITLES IN THE SYSTEM (for title format reference):\n"
            // Only show the first 10 titles to avoid overwhelming the context
            let limitedTitles = existingTitles.prefix(10)
            prompt += limitedTitles.joined(separator: "\n")
            prompt += "\n"
            prompt += "INSTRUCTION: When suggesting a title, analyze similar documents above and follow the same naming pattern/convention if applicable. Create consistent and descriptive titles.\n"
        }
        
        // Add existing tags as context if available
        if let existingTags = metadata["existingTags"] as? [String], !existingTags.isEmpty {
            prompt += "\nEXISTING TAGS IN THE SYSTEM (use these whenever relevant):\n"
            prompt += existingTags.joined(separator: ", ")
            prompt += "\n"
            prompt += "INSTRUCTION: IMPORTANT - Always prioritize selecting from existing tags above rather than creating new ones. Only suggest new tag names if no existing tag is appropriate. Suggest no more than 4 tags total, focusing on the most relevant ones only.\n"
        }
        
        // Add existing folders as context if available
        if let existingFolders = metadata["existingFolders"] as? [String], !existingFolders.isEmpty {
            prompt += "\nEXISTING FOLDERS IN THE SYSTEM (match document to these):\n"
            // Format as bullet points instead of comma-separated list
            for folder in existingFolders {
                prompt += "• \(folder)\n"
            }
            prompt += "\n"
            prompt += "⚠️ HIGHEST PRIORITY INSTRUCTION: ALWAYS prefer using existing folders over creating new ones!\n"
            
            // Add explicit numbered list of folders that MUST be evaluated
            prompt += "\n🔴 REQUIRED FOLDER EVALUATIONS - YOU MUST SCORE EACH ONE:\n"
            for (index, folder) in existingFolders.enumerated() {
                prompt += "\(index+1). \"\(folder)\"\n"
            }
            
            prompt += "\n⚠️ CRITICAL: Your response MUST include confidence scores for ALL \(existingFolders.count) folders listed above.\n"
            prompt += "⚠️ If you skip even one folder, your response will be considered incomplete and rejected.\n"
            prompt += "⚠️ Assign low scores (0.05-0.10) to folders that are not relevant, but DO NOT omit any folder.\n"
            prompt += "If any folder matches with at least 30% confidence, use that folder instead of suggesting a new one.\n"
        }
        
        prompt += "\nIMPORTANT GUIDELINES:\n"
        prompt += "1. For titles: Follow the naming patterns seen in similar existing documents\n"
        prompt += "2. For folders: HIGHEST PRIORITY - ALWAYS prefer existing folders when relevant (≥30% confidence). Only suggest new folders if nothing matches.\n"
        prompt += "3. For tags: ALWAYS prioritize reusing existing tags to maintain consistency, limit to max 4 tags\n"
        prompt += "4. You MUST include a 'folderConfidences' object that contains EVERY existing folder with its confidence score (0.0-1.0)\n"
        prompt += "5. Overall confidence: Set a value (0.0-1.0) indicating how confident you are in your entire classification\n"
        
        prompt += "\nRESPONSE FORMAT EXAMPLE:\n"
        prompt += """
        {
          "title": "Your suggested title",
          "folder": "Best matching folder name",
          "tags": ["Tag1", "Tag2", "Tag3"],
          "confidence": 0.85,
          "folderConfidences": {
            // CRITICAL: ALL folders must be included below - no exceptions!
            "Folder from required list #1": 0.85,
            "Folder from required list #2": 0.45,
            "Folder from required list #3": 0.20,
            "Folder from required list #4": 0.10,
            "Folder from required list #5": 0.05  // Very low confidence is OK
            // Every folder from the numbered list must appear here
          }
        }
        """
        
        return prompt
    }
    
    // Enhanced system role that explains how to use metadata
    private var systemRoleWithMetadata: String {
        return """
        You are an intelligent document analyzer that helps users classify and organize their documents.
        You will be given document text and metadata about existing items in the system.
        
        CRITICAL TASK REQUIREMENTS:
        - You MUST evaluate EVERY folder in the numbered required folder evaluation list
        - You MUST include ALL folders in your folderConfidences response
        - NO EXCEPTIONS: Even irrelevant folders must be included with low scores (0.05-0.10)
        - Your response will be rejected if any folder is missing from folderConfidences
        
        When suggesting a title, folder, or tags, follow these improved guidelines:
        1. Title formatting:
           - Identify similar existing document titles and follow the same naming convention/format
           - Make titles concise but descriptive and consistent with existing patterns
        
        2. Folder selection (HIGHEST PRIORITY):
           - Your primary task is to match documents to EXISTING folders whenever possible
           - You MUST evaluate EVERY existing folder with a confidence score (0.0-1.0)
           - You MUST include ALL folders from the numbered required evaluation list
           - If any existing folder appears relevant with at least 30% confidence, use that folder
           - Only suggest a new folder if no existing folder meets the 30% confidence threshold
        
        3. Tag selection:
           - Prioritize reusing existing tags when they match document content
           - Avoid creating new tags that are slight variations of existing ones
           - Suggest no more than 4 tags per document, selecting only the most relevant
           - For similar documents, maintain tag consistency by using the same tag set
        
        4. Set a confidence level (0.0-1.0) based on how certain you are of your classification
        
        Return your analysis in the requested JSON format. The folderConfidences object MUST include EVERY folder from the numbered list.
        """
    }
    
    private func createClassificationPrompt(text: String) -> String {
        return "DOCUMENT CONTENT:\n\(text)" // Using full document text without character limit
    }
    
    // Function to enhance document suggestions with synthetic folder confidences if needed
    func enhanceWithSyntheticConfidences(suggestions: DocumentSuggestions, metadata: [String: Any]) -> DocumentSuggestions {
        // Get existing folders from metadata
        let existingFolders = metadata["existingFolders"] as? [String] ?? []
        
        // If we have folder confidences, check if ALL folders are included
        if let existingConfidences = suggestions.folderConfidences, !existingConfidences.isEmpty {
            // Check if all expected folders are included
            let missingFolders = existingFolders.filter { !existingConfidences.keys.contains($0) }
            
            if missingFolders.isEmpty {
                print("✅ AI successfully evaluated ALL \(existingFolders.count) folders as required")
                return suggestions
            } else {
                print("⚠️ WARNING: AI evaluation is incomplete - missing \(missingFolders.count) folders:")
                for (index, missingFolder) in missingFolders.enumerated() {
                    print("   \(index+1). Missing evaluation for: \"\(missingFolder)\"")
                }
            }
        } else {
            print("⚠️ WARNING: AI provided NO folder confidence scores")
        }
        
        // Instead of generating synthetic values, show a warning
        print("⚠️ This indicates the AI model didn't follow instructions to evaluate all folders")
        print("⚠️ Please report this issue to improve the prompting system")
        
        // Create minimal fallback confidences just for the suggested folder
        var minimalConfidences: [String: Double]? = nil
        if let suggestedFolder = suggestions.suggestedFolderName, !existingFolders.isEmpty {
            minimalConfidences = [suggestedFolder: suggestions.confidence]
            print("ℹ️ Using minimal fallback confidence for folder: \(suggestedFolder) at \(Int(suggestions.confidence * 100))%")
        }
        
        // Create a new suggestions object with minimal fallback confidences
        return DocumentSuggestions(
            suggestedTitle: suggestions.suggestedTitle,
            suggestedFolderName: suggestions.suggestedFolderName,
            suggestedTags: suggestions.suggestedTags,
            confidence: suggestions.confidence,
            tokenUsage: suggestions.tokenUsage,
            folderConfidences: minimalConfidences
        )
    }
}
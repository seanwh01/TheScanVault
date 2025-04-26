import Foundation
import SwiftUI
import Vision
import Combine
import CoreData

// MARK: - DocumentProcessor Delegate Protocol
// This protocol is the authoritative version for the app
protocol DocumentProcessorDelegate: AnyObject {
    func processorDidBeginDocument(_ processor: DocumentProcessor)
    func processor(_ processor: DocumentProcessor, didCompleteOCRForPage pageIndex: Int, withText text: String)
    func processor(_ processor: DocumentProcessor, didCompleteAllOCRWithText text: String)
    func processor(_ processor: DocumentProcessor, didReceiveAISuggestions suggestions: DocumentClassifierService.DocumentSuggestions)
    func processor(_ processor: DocumentProcessor, didFailWithError error: Error)
    func processorDidFinishProcessing(_ processor: DocumentProcessor)
    func isAIEnabledForProcessor(_ processor: DocumentProcessor) -> Bool
}

// MARK: - Document Processing State
enum DocumentProcessingState: String {
    case idle = "Ready for processing"
    case ocrInProgress = "Performing OCR"
    case ocrComplete = "OCR completed"
    case aiInProgress = "AI analysis in progress"
    case aiComplete = "Document processed"
    case error = "Error processing document"
    case aiAnalysisInProgress = "AI analysis in progress (detailed)"
    case documentProcessed = "Document fully processed"
}

// MARK: - Document Processor
// This is the authoritative implementation for the app
class DocumentProcessor: NSObject {
    // MARK: - Properties
    
    // Processing state
    private(set) var processingState: DocumentProcessingState = .idle {
        didSet {
            print("🔄 Document processing state: \(processingState.rawValue)")
        }
    }
    
    // Document data
    private var scannedImages: [UIImage] = []
    private var pageTexts: [Int: String] = [:]
    private var totalPages: Int = 0
    private var completedPages: Int = 0
    private var combinedText: String = ""
    
    // API control
    private var hasCalledAI: Bool = false
    private let processingQueue = DispatchQueue(label: "com.app.documentProcessing", qos: .userInitiated)
    private let callLock = NSLock()
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let openAIService: OpenAIService
    private let persistenceController: PersistenceController
    private let documentAIService: DocumentAIService
    private let adaptiveLearningClassifier: AdaptiveLearningClassifier
    
    // Delegate
    weak var delegate: DocumentProcessorDelegate?
    
    // MARK: - Initialization
    
    init(openAIService: OpenAIService, persistenceController: PersistenceController, documentAIService: DocumentAIService, adaptiveLearningClassifier: AdaptiveLearningClassifier) {
        // Initialize services
        self.openAIService = openAIService
        self.persistenceController = persistenceController
        self.documentAIService = documentAIService
        self.adaptiveLearningClassifier = adaptiveLearningClassifier
        
        super.init()
        
        print("🚀 Document processor initialized with persistence controller")
        
        // Register for subscription change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSubscriptionChange),
            name: NSNotification.Name("SubscriptionStatusChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleSubscriptionChange() {
        // Force reload subscription status from UserDefaults
        let isPremium = UserDefaults.standard.bool(forKey: "IsPremiumUser")
        print("🔄 Document processor detected subscription change: Premium=\(isPremium)")
        
        // Reset the processing state to allow AI processing on current document if needed
        if isPremium {
            print("🔄 Document processor state is being reset - forcing reanalysis")
            hasCalledAI = false
        }
    }
    
    // MARK: - Public Methods
    
    /// Start processing a document with the given images
    func processDocument(images: [UIImage]) {
        // Reset state
        resetState()
        
        // Store images
        scannedImages = images
        
        // Notify delegate that processing has begun
        delegate?.processorDidBeginDocument(self)
        
        // Set total OCR pages
        totalPages = images.count
        
        // Begin processing
        processingState = .ocrInProgress
        
        // Process each image
        processConcurrentOCR(for: images)
    }
    
    /// Process OCR concurrently for better performance
    private func processConcurrentOCR(for images: [UIImage]) {
        print("🔄 Starting concurrent OCR for \(images.count) images")
        
        // Create a dispatch group to track completion
        let group = DispatchGroup()
        
        // Process each image concurrently
        for (pageIndex, image) in images.enumerated() {
            group.enter()
            
            // Use a concurrent queue for better performance
            DispatchQueue.global(qos: .userInitiated).async {
                self.performOCR(for: image, pageIndex: pageIndex)
                group.leave()
            }
        }
        
        // Notify when all OCR is complete
        group.notify(queue: .main) {
            print("✅ All OCR tasks submitted")
        }
    }
    
    /// Cancel ongoing processing
    func cancelProcessing() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🛑 Document processing cancelled")
            self.resetState()
        }
    }
    
    // Method to analyze document text with metadata context
    func analyzeDocumentText(_ text: String, withMetadata metadata: [String: Any], completion: @escaping (Result<DocumentClassifierService.DocumentSuggestions, Error>) -> Void) {
        // Skip if already in progress
        guard processingState != .aiInProgress else {
            completion(.failure(NSError(domain: "DocumentProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI analysis is already in progress"])))
            return
        }
        
        // Update processing state
        processingState = .aiInProgress
        
        // Store the combined text
        combinedText = text
        
        // Log the metadata context being sent to the AI
        print("📝 Analyzing document with metadata context:")
        if let existingTitles = metadata["existingTitles"] as? [String] {
            print("📚 Passing \(existingTitles.count) document titles to AI")
        } else {
            print("📚 No document titles in metadata context")
        }
        
        if let existingTags = metadata["existingTags"] as? [String] {
            print("🏷️ Passing \(existingTags.count) tags to AI: \(existingTags.joined(separator: ", "))")
        } else {
            print("🏷️ No tags in metadata context")
        }
        
        if let existingFolders = metadata["existingFolders"] as? [String] {
            print("📁 Passing \(existingFolders.count) folders to AI: \(existingFolders.joined(separator: ", "))")
        } else {
            print("📁 No folders in metadata context")
        }
        
        if let forceAnalysis = metadata["forceAnalysis"] as? Bool, forceAnalysis {
            print("🔄 Force analysis flag is enabled")
        }
        
        // Determine which AI service to use based on config
        let useOpenAI = UserDefaults.standard.string(forKey: "OpenAIAPIKey") != nil
        
        if useOpenAI {
            // Get the model to use from user preferences - use AIClassifierModelPreference for document analysis
            let modelName = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
            
            // Use the OpenAI service with metadata context
            openAIService.analyzeDocumentWithMetadata(text, metadata: metadata, model: modelName) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let openAISuggestions):
                        // Convert to DocumentClassifierService.DocumentSuggestions
                        let suggestions = DocumentClassifierService.DocumentSuggestions(
                            suggestedTitle: openAISuggestions.suggestedTitle,
                            suggestedFolderName: openAISuggestions.suggestedFolderName,
                            suggestedTags: openAISuggestions.suggestedTags,
                            confidence: openAISuggestions.confidence,
                            tokenUsage: self.convertTokenUsage(openAISuggestions.tokenUsage),
                            folderConfidences: openAISuggestions.folderConfidences
                        )
                    
                        // Update state
                        self.processingState = .aiComplete
                        completion(.success(suggestions))
                        
                    case .failure(let error):
                        // Handle errors
                        self.processingState = .error
                        completion(.failure(error))
                    }
                }
            }
        } else {
            // Use the dev AI service
            Task {
                if let devSuggestions = try? await documentAIService.analyzeDocument(text: text) {
                    // Update state
                    self.processingState = .aiComplete
                    
                    // Convert devSuggestions to DocumentClassifierService.DocumentSuggestions
                    let suggestions = DocumentClassifierService.DocumentSuggestions(
                        suggestedTitle: devSuggestions.suggestedTitle,
                        suggestedFolderName: devSuggestions.suggestedFolderName,
                        suggestedTags: devSuggestions.suggestedTags,
                        confidence: devSuggestions.confidence,
                        tokenUsage: nil,
                        folderConfidences: nil
                    )
                    
                    // Return on main thread
                    DispatchQueue.main.async {
                        completion(.success(suggestions))
                    }
                } else {
                    // Handle error
                    self.processingState = .error
                    
                    // Return error on main thread
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "DocumentProcessor",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get AI suggestions"]
                        )))
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Reset the processor state for a new document
    private func resetState() {
        print("🔄 Document processor state reset")
        processingState = .idle
        scannedImages = []
        pageTexts = [:]
        totalPages = 0
        completedPages = 0
        combinedText = ""
        hasCalledAI = false
        
        // Reset OpenAI call counter
        openAIService.resetCallCounter()
    }
    
    /// Perform OCR on a single page
    private func performOCR(for image: UIImage, pageIndex: Int) {
        guard processingState == .ocrInProgress else {
            print("⚠️ Cannot perform OCR when not in OCR state")
            return
        }
        
        print("🔍 Starting OCR on page \(pageIndex + 1)")
        
        // Create a text recognition request
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let self = self else { return }
            
            guard error == nil else {
                print("❌ OCR error on page \(pageIndex + 1): \(error!.localizedDescription)")
                
                // Mark this page as completed even if it failed
                self.processingQueue.async {
                    self.completePageOCR(pageIndex: pageIndex, text: "")
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("❌ No text observations found on page \(pageIndex + 1)")
                
                // Mark this page as completed with no text
                self.processingQueue.async {
                    self.completePageOCR(pageIndex: pageIndex, text: "")
                }
                return
            }
            
            // Safety check - ensure observations array is not empty
            if observations.isEmpty {
                print("⚠️ Empty text observations array on page \(pageIndex + 1)")
                self.processingQueue.async {
                    self.completePageOCR(pageIndex: pageIndex, text: "")
                }
                return
            }
            
            // Extract text from observations with additional error handling
            var extractedText = ""
            do {
                extractedText = observations.compactMap { observation -> String? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return candidate.string
                }.joined(separator: " ")
            } catch {
                print("⚠️ Error extracting text from observations: \(error.localizedDescription)")
                // Continue with empty string if extraction fails
                extractedText = ""
            }
            
            print("✅ OCR completed for page \(pageIndex + 1) with \(extractedText.count) characters")
            
            // Store the extracted text
            self.processingQueue.async {
                self.completePageOCR(pageIndex: pageIndex, text: extractedText)
            }
        }
        
        // Configure the request for accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Create a request handler
        guard let cgImage = image.cgImage else {
            print("❌ Failed to get CGImage for page \(pageIndex + 1)")
            
            // Mark this page as completed with no text
            self.completePageOCR(pageIndex: pageIndex, text: "")
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Perform the text recognition
        do {
            try requestHandler.perform([request])
        } catch {
            print("❌ Failed to perform OCR on page \(pageIndex + 1): \(error.localizedDescription)")
            
            // Mark this page as completed with error
            self.completePageOCR(pageIndex: pageIndex, text: "")
        }
    }
    
    /// Handle completion of OCR for a page
    private func completePageOCR(pageIndex: Int, text: String) {
        // Store the extracted text
        pageTexts[pageIndex] = text
        completedPages += 1
        
        // Notify delegate about page completion
        DispatchQueue.main.async {
            self.delegate?.processor(self, didCompleteOCRForPage: pageIndex, withText: text)
        }
        
        print("📊 OCR progress: \(completedPages)/\(totalPages) pages")
        
        // Check if all pages are complete
        if completedPages == totalPages {
            print("✅ OCR completed for all \(totalPages) pages")
            finishOCR()
        }
    }
    
    /// Combine all page texts and finish OCR phase
    private func finishOCR() {
        // Combine all pages in order
        let sortedIndices = pageTexts.keys.sorted()
        combinedText = sortedIndices.compactMap { pageTexts[$0] }.joined(separator: "\n\n")
        
        print("📝 Combined text from all pages: \(combinedText.count) characters")
        processingState = .ocrComplete
        
        // Notify delegate
        DispatchQueue.main.async {
            self.delegate?.processor(self, didCompleteAllOCRWithText: self.combinedText)
        }
        
        // Proceed with AI analysis if applicable
        if UserDefaults.isAIDocumentClassificationEnabled {
            print("🧠 Proceeding with AI analysis")
            proceedWithAIAnalysis()
        } else {
            print("⚠️ AI analysis disabled - processing complete")
            finishProcessing()
        }
    }
    
    /// Proceed with AI analysis after OCR is complete
    private func proceedWithAIAnalysis() {
        print("🧠 Proceeding with AI analysis")
        
        // Ensure we have extracted text
        if combinedText.isEmpty {
            print("❌ ERROR: No OCR text available for AI analysis")
            processingState = .error
            delegate?.processor(self, didFailWithError: NSError(domain: "DocumentProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text extracted from document"]))
            finishProcessing()
            return
        }
        
        print("📝 Starting AI analysis with \(combinedText.count) characters of text")
        
        // Update processing state
        processingState = .aiAnalysisInProgress
        
        // Reset the OpenAI call counter to ensure a clean start
        openAIService.resetCallCounter()
        
        // Check if AI is enabled via delegate
        let isAIEnabled = delegate?.isAIEnabledForProcessor(self) ?? true
        if !isAIEnabled {
            print("⚠️ AI analysis disabled by delegate")
            processingState = .documentProcessed
            finishProcessing()
            return
        }
        
        // Get the model to use from user preferences
        let modelName = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
        print("🧠 Starting AI analysis with model \(modelName) - THE ONLY API CALL")
        
        // Check if Enhanced Metadata Context is enabled
        let useEnhancedMetadata = UserDefaults.standard.bool(forKey: "AIVerbosePrompts")
        
        if useEnhancedMetadata {
            print("📊 Using Enhanced Metadata Context for AI analysis")
            
            // Fetch all folders to create proper metadata context
            let context = persistenceController.viewContext
            var existingFolders: [String] = []
            
            // Fetch all folders from Core Data
            let folderFetchRequest = NSFetchRequest<Folder>(entityName: "Folder")
            do {
                let folders = try context.fetch(folderFetchRequest)
                existingFolders = folders.compactMap { $0.name }
                print("📁 Fetched \(existingFolders.count) folders for AI context: \(existingFolders.joined(separator: ", "))")
            } catch {
                print("⚠️ Failed to fetch folders: \(error.localizedDescription)")
                // Continue with empty folders list rather than failing
            }

            // NEW CODE: Fetch common tags associated with each folder
            var folderTagAssociations: [String: [String: Double]] = [:]
            
            for folderName in existingFolders {
                // Get folder ID first
                let folderIDFetchRequest = NSFetchRequest<Folder>(entityName: "Folder")
                folderIDFetchRequest.predicate = NSPredicate(format: "name == %@", folderName)
                folderIDFetchRequest.fetchLimit = 1
                
                do {
                    let matchingFolders = try context.fetch(folderIDFetchRequest)
                    if let folder = matchingFolders.first, let folderId = folder.id?.uuidString {
                        // Fetch documents in this folder
                        let documentFetchRequest = NSFetchRequest<Document>(entityName: "Document")
                        documentFetchRequest.predicate = NSPredicate(format: "folderId == %@", folderId)
                        let documents = try context.fetch(documentFetchRequest)
                        
                        // Count tag occurrences across all documents in this folder
                        var tagCounts: [String: Int] = [:]
                        var totalDocuments = 0
                        
                        for document in documents {
                            totalDocuments += 1
                            // Get tags for this document
                            if let tags = document.tags as? Set<Tag> {
                                for tag in tags {
                                    if let tagName = tag.name {
                                        tagCounts[tagName, default: 0] += 1
                                    }
                                }
                            }
                        }
                        
                        // Only process folders with at least 3 documents for statistically significant patterns
                        if totalDocuments >= 3 {
                            print("📊 Folder '\(folderName)' has \(totalDocuments) documents - sufficient for pattern detection")
                            
                            // Convert counts to frequency percentages
                            var tagFrequencies: [String: Double] = [:]
                            for (tag, count) in tagCounts {
                                let frequency = Double(count) / Double(totalDocuments)
                                // Only include tags that appear in at least 30% of documents
                                if frequency >= 0.3 {
                                    tagFrequencies[tag] = frequency
                                }
                            }
                            
                            // Only include this folder if it has common tags
                            if !tagFrequencies.isEmpty {
                                folderTagAssociations[folderName] = tagFrequencies
                                print("📊 Found \(tagFrequencies.count) common tags for folder '\(folderName)'")
                                
                                // Log the top tags for debugging
                                let sortedTags = tagFrequencies.sorted { $0.value > $1.value }
                                let topTags = sortedTags.prefix(3).map { "\($0.key) (\(Int($0.value * 100))%)" }.joined(separator: ", ")
                                print("🏷️ Top tags: \(topTags)")
                            }
                        } else {
                            print("📊 Folder '\(folderName)' only has \(totalDocuments) documents - insufficient for reliable pattern detection")
                        }
                    }
                } catch {
                    print("⚠️ Failed to fetch tag associations for folder '\(folderName)': \(error.localizedDescription)")
                }
            }
            
            // Create metadata dictionary with folder-tag associations
            var metadata: [String: Any] = ["existingFolders": existingFolders]
            
            // Fetch some recent document titles for pattern matching
            let titleFetchRequest = NSFetchRequest<Document>(entityName: "Document")
            titleFetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            titleFetchRequest.fetchLimit = 15 // Fetch recent documents for relevant title patterns
            
            do {
                let recentDocuments = try context.fetch(titleFetchRequest)
                let existingTitles = recentDocuments.compactMap { $0.title }.filter { !$0.isEmpty }
                
                if !existingTitles.isEmpty {
                    metadata["existingTitles"] = existingTitles
                    print("📚 Adding \(existingTitles.count) document titles to metadata for pattern matching")
                    
                    // Log a few examples for debugging
                    let titleExamples = existingTitles.prefix(3).joined(separator: ", ")
                    print("📚 Sample titles: \(titleExamples)")
                }
            } catch {
                print("⚠️ Failed to fetch document titles: \(error.localizedDescription)")
            }
            
            // Add folder tag associations if we found any
            if !folderTagAssociations.isEmpty {
                metadata["folderTagPatterns"] = folderTagAssociations
                print("🧠 Added tag patterns for \(folderTagAssociations.count) folders to metadata")
                
                // Debug: Print detailed folder-tag patterns
                print("📊 FOLDER-TAG PATTERNS DETAIL:")
                for (folderName, tagFrequencies) in folderTagAssociations {
                    let sortedTags = tagFrequencies.sorted { $0.value > $1.value }
                    let tagDetails = sortedTags.map { "\($0.key) (\\(Int($0.value * 100))%)" }.joined(separator: ", ")
                    print("   - \(folderName): \(tagDetails)")
                }
            }
            
            // Fetch deleted folders and tags from the adaptive learning classifier
            let deletedItems = self.adaptiveLearningClassifier.getDeletedFoldersAndTags()
            
            // Add deleted folders to metadata if any exist
            if !deletedItems.folders.isEmpty {
                metadata["deletedFolders"] = deletedItems.folders
                print("🗑️ Added \(deletedItems.folders.count) deleted folders to metadata")
            }
            
            // Add deleted tags to metadata if any exist
            if !deletedItems.tags.isEmpty {
                metadata["deletedTags"] = deletedItems.tags
                print("🗑️ Added \(deletedItems.tags.count) deleted tags to metadata")
            }
            
            print("🔍 Created metadata with \(existingFolders.count) folders for AI evaluation")
            
            // Make the API call with enhanced metadata
            openAIService.analyzeDocumentWithMetadata(combinedText, metadata: metadata, model: modelName) { [weak self] result in
                self?.handleAIResult(result, modelName: modelName)
            }
        } else {
            print("📊 Using Standard AI analysis without enhanced metadata")
            
            // Make the API call without enhanced metadata
            openAIService.analyzeDocument(combinedText, model: modelName) { [weak self] result in
                self?.handleAIResult(result, modelName: modelName)
            }
        }
    }
    
    /// Handle AI analysis result
    private func handleAIResult(_ result: Result<OpenAIService.DocumentSuggestions, Error>, modelName: String) {
        DispatchQueue.main.async {
            switch result {
            case .success(let openAISuggestions):
                print("✅ AI analysis complete: \(openAISuggestions.suggestedTitle)")
                
                // Convert to DocumentClassifierService.DocumentSuggestions
                let suggestions = DocumentClassifierService.DocumentSuggestions(
                    suggestedTitle: openAISuggestions.suggestedTitle,
                    suggestedFolderName: openAISuggestions.suggestedFolderName,
                    suggestedTags: openAISuggestions.suggestedTags,
                    confidence: openAISuggestions.confidence,
                    tokenUsage: self.convertTokenUsage(openAISuggestions.tokenUsage),
                    folderConfidences: openAISuggestions.folderConfidences
                )
                
                // Add default token usage if missing
                var enhancedSuggestions: DocumentClassifierService.DocumentSuggestions
                if suggestions.tokenUsage == nil {
                    // Create placeholder token usage with estimated values based on text length
                    let estimatedPromptTokens = Int(Float(self.combinedText.count) * 1.3)
                    let estimatedCompletionTokens = 150
                    let estimatedTotal = estimatedPromptTokens + estimatedCompletionTokens
                    
                    print("📊 Adding estimated token usage: \(estimatedTotal) tokens")
                    
                    // Create DocumentClassifierService.DocumentSuggestions
                    enhancedSuggestions = DocumentClassifierService.DocumentSuggestions(
                        suggestedTitle: suggestions.suggestedTitle,
                        suggestedFolderName: suggestions.suggestedFolderName,
                        suggestedTags: suggestions.suggestedTags,
                        confidence: suggestions.confidence,
                        tokenUsage: DocumentClassifierService.DocumentSuggestions.TokenUsage(
                            promptTokens: estimatedPromptTokens,
                            completionTokens: estimatedCompletionTokens,
                            totalTokens: estimatedTotal,
                            model: modelName
                        ),
                        folderConfidences: suggestions.folderConfidences
                    )
                } else {
                    // Use the suggestions with the token usage we already have
                    enhancedSuggestions = suggestions
                }
                
                self.processingState = .aiComplete
                self.delegate?.processor(self, didReceiveAISuggestions: enhancedSuggestions)
                
                // Verify AI suggestions comply with our rules
                self.verifyAISuggestions(openAISuggestions)
                
            case .failure(let error):
                // Check if this was a rate limit or auth error
                if let nsError = error as NSError?, nsError.code == 429 {
                    print("⚠️ AI call was blocked as a duplicate - completing anyway")
                    self.processingState = .aiComplete
                } else {
                    print("❌ AI analysis failed: \(error.localizedDescription)")
                    self.processingState = .error
                    self.delegate?.processor(self, didFailWithError: error)
                }
            }
            
            // Finish processing
            self.finishProcessing()
        }
    }
    
    /// Complete all processing
    private func finishProcessing() {
        print("📋 Document processing complete")
        
        // Notify delegate that processing is complete
        DispatchQueue.main.async {
            self.delegate?.processorDidFinishProcessing(self)
        }
    }
    
    // MARK: - Helpers
    
    /// Check if AI analysis is enabled and premium requirements are met
    private func isAIEnabled() -> Bool {
        // Access subscription info
        let isPremium = UserDefaults.standard.bool(forKey: "IsPremiumUser")
        let isAIEnabled = UserDefaults.isAIDocumentClassificationEnabled
        
        return isPremium && isAIEnabled
    }
    
    // Helper method to convert between token usage types
    private func convertTokenUsage(_ tokenUsage: OpenAIService.TokenUsage?) -> DocumentClassifierService.DocumentSuggestions.TokenUsage? {
        guard let tokenUsage = tokenUsage else { return nil }
        
        return DocumentClassifierService.DocumentSuggestions.TokenUsage(
            promptTokens: tokenUsage.promptTokens,
            completionTokens: tokenUsage.completionTokens,
            totalTokens: tokenUsage.totalTokens,
            model: tokenUsage.modelUsed
        )
    }
    
    /// Verify AI suggestions comply with our rules
    private func verifyAISuggestions(_ suggestions: OpenAIService.DocumentSuggestions) {
        print("🔍 VERIFYING AI SUGGESTIONS:")
        
        // 1. Check if the suggested folder exists
        if let suggestedFolder = suggestions.suggestedFolderName {
            // Fetch all folders using the injected controller
            let context = persistenceController.viewContext
            let folderFetchRequest = NSFetchRequest<Folder>(entityName: "Folder")
            
            do {
                let folders = try context.fetch(folderFetchRequest)
                let folderNames = folders.compactMap { $0.name }
                
                if folderNames.contains(where: { $0.lowercased() == suggestedFolder.lowercased() }) {
                    print("✅ Suggested folder '\(suggestedFolder)' exists in the system")
                } else {
                    print("❌ WARNING: Suggested folder '\(suggestedFolder)' does NOT exist in the system")
                }
            } catch {
                print("⚠️ Could not verify folder existence: \(error.localizedDescription)")
            }
        }
        
        // 2. Check if the title follows existing patterns
        let suggestedTitle = suggestions.suggestedTitle
        
        // Fetch some recent document titles
        let context = persistenceController.viewContext
        let titleFetchRequest = NSFetchRequest<Document>(entityName: "Document")
        titleFetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        titleFetchRequest.fetchLimit = 10
        
        do {
            let recentDocuments = try context.fetch(titleFetchRequest)
            let existingTitles = recentDocuments.compactMap { $0.title }.filter { !$0.isEmpty }
            
            if !existingTitles.isEmpty {
                // Simple verification - check capitalization pattern
                let existingCapPattern = existingTitles.filter { !$0.isEmpty }.map { $0.first!.isUppercase }
                let mostCommonCapPattern = existingCapPattern.filter { $0 }.count > existingCapPattern.filter { !$0 }.count
                
                if suggestedTitle.first?.isUppercase == mostCommonCapPattern {
                    print("✅ Suggested title '\(suggestedTitle)' follows capitalization pattern of existing titles")
                } else {
                    print("⚠️ Suggested title '\(suggestedTitle)' doesn't follow common capitalization pattern")
                }
                
                // Check average title length pattern
                let avgTitleLength = existingTitles.map { $0.count }.reduce(0, +) / existingTitles.count
                let lengthDifference = abs(suggestedTitle.count - avgTitleLength)
                let lengthPercentDiff = Double(lengthDifference) / Double(avgTitleLength)
                
                if lengthPercentDiff <= 0.3 {
                    print("✅ Suggested title length (\(suggestedTitle.count) chars) is within 30% of average (\(avgTitleLength) chars)")
                } else {
                    print("⚠️ Suggested title length (\(suggestedTitle.count) chars) differs significantly from average (\(avgTitleLength) chars)")
                }
                
                // Check for common prefixes/suffixes
                let commonPrefixes = findCommonPrefixes(in: existingTitles)
                if !commonPrefixes.isEmpty {
                    let hasCommonPrefix = commonPrefixes.contains { prefix in
                        suggestedTitle.lowercased().hasPrefix(prefix.lowercased())
                    }
                    
                    if hasCommonPrefix {
                        print("✅ Suggested title correctly uses a common document prefix")
                    } else if commonPrefixes.count >= 2 { // Only flag if there are multiple documents with the same prefix
                        print("⚠️ Suggested title doesn't use common prefixes found in existing titles: \(commonPrefixes.joined(separator: ", "))")
                    }
                }
                
                // Check for special characters and punctuation patterns
                let existingPunctuation = findCommonPunctuation(in: existingTitles)
                if !existingPunctuation.isEmpty {
                    let suggestedHasSimilarPunctuation = existingPunctuation.contains { punct in
                        suggestedTitle.contains(punct)
                    }
                    
                    if suggestedHasSimilarPunctuation {
                        print("✅ Suggested title correctly uses similar punctuation patterns")
                    } else {
                        print("⚠️ Suggested title doesn't use punctuation patterns found in existing titles: \(existingPunctuation.joined(separator: ", "))")
                    }
                }
            }
        } catch {
            print("⚠️ Could not verify title pattern: \(error.localizedDescription)")
        }
        
        // 3. Check for deleted folders/tags
        let deletedItems = self.adaptiveLearningClassifier.getDeletedFoldersAndTags()
        
        // Check for deleted folders
        if let folder = suggestions.suggestedFolderName, !folder.isEmpty,
           deletedItems.folders.contains(where: { $0.lowercased() == folder.lowercased() }) {
            print("❌ AI suggested a DELETED folder: '\(folder)'")
        }
        
        // Check for deleted tags
        let suggestedTags = suggestions.suggestedTags
        let deletedTagsUsed = suggestedTags.filter { suggestedTag in
            deletedItems.tags.contains(where: { $0.lowercased() == suggestedTag.lowercased() })
        }
        
        if !deletedTagsUsed.isEmpty {
            print("❌ AI suggested \(deletedTagsUsed.count) DELETED tags: \(deletedTagsUsed.joined(separator: ", "))")
        }
    }
    
    // Helper method to find common prefixes in an array of strings
    private func findCommonPrefixes(in strings: [String]) -> [String] {
        guard strings.count >= 2 else { return [] }
        
        // Look for word-based prefixes (more meaningful than character-based)
        var prefixCandidates: [String: Int] = [:]
        
        // Consider first word or first two words as potential prefixes
        for string in strings {
            let words = string.components(separatedBy: " ")
            
            if words.count >= 1 {
                let firstWord = words[0]
                if firstWord.count >= 3 { // Only consider meaningful words
                    prefixCandidates[firstWord, default: 0] += 1
                }
            }
            
            if words.count >= 2 {
                let firstTwoWords = words[0] + " " + words[1]
                prefixCandidates[firstTwoWords, default: 0] += 1
            }
        }
        
        // Filter for prefixes that appear in at least 2 documents or 30% of documents
        let threshold = max(2, Int(Double(strings.count) * 0.3))
        let commonPrefixes = prefixCandidates.filter { $0.value >= threshold }.keys.sorted()
        
        return commonPrefixes
    }
    
    // Helper method to find common punctuation patterns in an array of strings
    private func findCommonPunctuation(in strings: [String]) -> [String] {
        guard strings.count >= 2 else { return [] }
        
        // Special characters and punctuation to look for
        let specialChars = [":", "-", "—", "(", ")", "[", "]", "{", "}", "/", "\\", "&", "+", "#"]
        var patternCounts: [String: Int] = [:]
        
        // Count occurrences of each special character
        for string in strings {
            for char in specialChars {
                if string.contains(char) {
                    patternCounts[char, default: 0] += 1
                }
            }
        }
        
        // Also look for specific patterns like "Name - Detail" or "Name: Detail"
        let patternRegexes = [
            ".*\\s-\\s.*": "space-dash-space",
            ".*:\\s.*": "colon-space",
            ".*\\(.*\\)": "parentheses",
            ".*\\[.*\\]": "brackets"
        ]
        
        for (pattern, name) in patternRegexes {
            for string in strings {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let range = NSRange(location: 0, length: string.utf16.count)
                    if regex.firstMatch(in: string, options: [], range: range) != nil {
                        patternCounts[name, default: 0] += 1
                    }
                }
            }
        }
        
        // Filter for patterns that appear in at least 2 documents or 30% of documents
        let threshold = max(2, Int(Double(strings.count) * 0.3))
        let commonPatterns = patternCounts.filter { $0.value >= threshold }.keys.sorted()
        
        return commonPatterns
    }
}

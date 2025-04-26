import Foundation
import Combine
import CoreData // Needed for DocumentClassifierService interaction potentially

#if os(macOS)
typealias UIImage = NSImage
#endif

extension ViewModels_Scan {
    
    @MainActor
    class AIDocumentAnalysisService: ObservableObject {
        @Published var analysisResult: DocumentClassifierService.DocumentSuggestions? = nil
        @Published var isLoading: Bool = false
        @Published var error: Error? = nil

        // Dependencies
        private let subscriptionManager: SubscriptionManager
        private let documentClassifierService: DocumentClassifierService
        // Added PersistenceController dependency
        private let persistenceController: PersistenceController
        private let documentAIService: DocumentAIService // 1. Add property

        private var analysisTask: Task<Void, Never>? = nil

        // MARK: - Public API
        // Call this when OCR text is available from DocumentProcessingService
        func analyzeDocument(ocrText: String?, folderNames: [String], tagNames: [String]) {
            guard shouldAttemptAIAnalysis else {
                print("🤖 AI analysis skipped: User setting is disabled.")
                resetAIState()
                return
            }
            
            guard isEligibleForAI else {
                print("🤖 AI analysis skipped: User is not premium.")
                showPremiumUpgradePrompt = true
                resetAIState()
                return
            }
            
            guard let textToAnalyze = ocrText, !textToAnalyze.isEmpty else {
                print("🤖 AI analysis skipped: No OCR text available.")
                resetAIState()
                return
            }
            
            print("🤖 Triggering AI document analysis...")
            isLoading = true
            error = nil
            analysisResult = nil // Clear previous suggestions
            
            // Get current selected AI model from UserDefaults
            let selectedModel = UserDefaults.standard.string(forKey: "selectedAIModel") ?? "gpt-3.5-turbo" // Default model

            // Start the classification task asynchronously
            analysisTask = Task {
                do {
                    // Call the async version, remove unsupported args (folders, tags, model)
                    let suggestions = try await documentClassifierService.classifyDocument(text: textToAnalyze)
                    
                    // Ensure updates are on the main thread after await
                    await MainActor.run { 
                        print("✅ Received AI suggestions: \(suggestions.suggestedTitle)")
                        // Assuming TokenUsage is now part of DocumentSuggestions
                        print("📊 Token usage: \(suggestions.tokenUsage?.totalTokens ?? 0) tokens") 
                        self.isLoading = false
                        self.analysisResult = suggestions
                    }
                    
                } catch {
                    // Ensure updates are on the main thread after await
                     await MainActor.run { 
                        print("🚨 AI analysis failed: \(error.localizedDescription)")
                        self.isLoading = false
                        self.error = error // Simplified error message
                    }
                }
            }
        }
        
        // Clear AI-related state
        func resetAIState() {
            analysisResult = nil
            isLoading = false
            error = nil
            print("🤖 Reset AI Analysis State")
        }
        
        // User preference from settings - should we *attempt* analysis?
        var shouldAttemptAIAnalysis: Bool {
            UserDefaults.standard.bool(forKey: "isAIDocumentClassificationEnabled")
        }

        // Eligibility - can the user actually use AI based on subscription?
        var isEligibleForAI: Bool {
            subscriptionManager.currentSubscription == .premium
        }
        
        // Observe changes in subscription status
        var cancellables = Set<AnyCancellable>()
        var showPremiumUpgradePrompt = false // If analysis fails due to subscription
        
        init(subscriptionManager: SubscriptionManager, persistenceController: PersistenceController, documentAIService: DocumentAIService) {
            self.subscriptionManager = subscriptionManager
            self.persistenceController = persistenceController // Store it
            self.documentAIService = documentAIService // 2. Update initializer to accept and store documentAIService
            // Initialize DocumentClassifierService passing the controller and documentAIService
            self.documentClassifierService = DocumentClassifierService(persistenceController: persistenceController, documentAIService: documentAIService) // 3. Update DocumentClassifierService initializer call
            print("🤖 AIDocumentAnalysisService Initialized")
            
            // Observe changes in subscription status
            subscriptionManager.$currentSubscription
                .dropFirst() // Ignore initial value
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    print("🤖 Subscription status changed. Re-evaluating AI analysis capability.")
                    // Potentially trigger re-analysis if needed and now eligible
                    // self?.triggerAnalysisIfNeeded(...)
                }
                .store(in: &cancellables)
                
            // Observe changes in the AI setting
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                 .receive(on: DispatchQueue.main)
                 .sink { [weak self] _ in
                     // Check if the relevant key changed
                     // Could potentially trigger re-analysis
                      print("🤖 UserDefaults changed. Re-evaluating AI analysis setting.")
                 }
                 .store(in: &cancellables)
        }
    }
}

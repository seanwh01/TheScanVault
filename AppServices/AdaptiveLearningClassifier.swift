import Foundation
import CoreData

// This file exists for backward compatibility during refactoring
// It serves as a proxy to the actual implementation in Services/AI/Learning/

class AdaptiveLearningClassifier {
    // The persistence controller for CoreData operations
    private let persistenceController: PersistenceController
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        print("🧠 AdaptiveLearningClassifier initialized (stable proxy implementation)")
    }
    
    // MARK: - Public API Methods
    
    func finishInitialization() {
        print("🧠 AdaptiveLearningClassifier.finishInitialization called")
        
        // Run the verification task after a delay, but without causing crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            print("🧠 AdaptiveLearningClassifier running post-initialization tasks")
        }
    }
    
    func recordUserCorrection(originalText: String, 
                              aiSuggestion: DocumentClassifierService.DocumentSuggestions,
                              finalUserChoice: DocumentClassifierService.DocumentSuggestions) {
        // Log the correction for debugging purposes
        print("🧠 Recording user correction:")
        print("  Original text: \(originalText.prefix(30))...")
        print("  Title: \(aiSuggestion.suggestedTitle) → \(finalUserChoice.suggestedTitle)")
        print("  Folder: \(aiSuggestion.suggestedFolderName ?? "none") → \(finalUserChoice.suggestedFolderName ?? "none")")
        
        // Only log tag changes if there are not too many tags
        if aiSuggestion.suggestedTags.count < 5 && finalUserChoice.suggestedTags.count < 5 {
            print("  Tags: \(aiSuggestion.suggestedTags.joined(separator: ", ")) → \(finalUserChoice.suggestedTags.joined(separator: ", "))")
        } else {
            print("  Tags: \(aiSuggestion.suggestedTags.count) tags → \(finalUserChoice.suggestedTags.count) tags")
        }
        
        // Store the correction details in memory only (no Core Data access)
        let fingerprint = createDocumentFingerprint(from: originalText)
        let timestamp = Date()
        
        // In the future, this would store the correction
        // For now we just create the object but don't store it
        _ = ClassificationPair(
            documentFingerprint: fingerprint,
            aiSuggestion: aiSuggestion,
            userSelection: finalUserChoice,
            timestamp: timestamp
        )
    }
    
    func enhancePromptWithLearning(documentText: String, basePrompt: String) -> String {
        // In the real implementation, this would analyze past corrections
        // For now, we just return the original prompt
        return basePrompt
    }
    
    func loadLearningExamples() {
        print("🧠 AdaptiveLearningClassifier.loadLearningExamples called")
        // No-op placeholder for the real implementation
    }
    
    func getLearningStatistics() -> (totalExamples: Int, folderCorrections: Int, tagCorrections: Int) {
        // Return default statistics
        return (0, 0, 0)
    }
    
    func verifyAndFixCoreDataStorage() {
        print("🧠 AdaptiveLearningClassifier.verifyAndFixCoreDataStorage called")
        
        // First check if the KeywordPattern entity exists WITHOUT trying to fetch it
        // This avoids crashes when the entity doesn't exist
        let context = persistenceController.viewContext
        
        // Safely check if the entity exists in the model
        if let _ = NSEntityDescription.entity(forEntityName: "KeywordPattern", in: context) {
            print("✅ KeywordPattern entity exists in the model")
            
            // We could fetch entities here, but we'll skip it for safety
        } else {
            print("ℹ️ KeywordPattern entity does not exist in the model")
            print("ℹ️ This is expected during refactoring - no action needed")
        }
    }
    
    func repairBrokenEntities() {
        print("🧠 AdaptiveLearningClassifier.repairBrokenEntities called")
        // No-op placeholder for the real implementation
    }
    
    func getDeletedFoldersAndTags() -> (folders: [String], tags: [String]) {
        // Return empty arrays as a placeholder
        return ([], [])
    }
    
    func getDeletedItemsHistory() -> [(type: String, name: String, date: Date)] {
        // Return empty array as a placeholder
        return []
    }
    
    func getFolderTagPatternStatistics() -> [String: [(tag: String, frequency: Double)]] {
        // Return empty dictionary as a placeholder
        return [:]
    }
    
    func debugGetLearnedFolderPatterns() -> [(original: String, updated: String, count: Int)] {
        // Return empty array as a placeholder
        return []
    }
    
    func debugGetRecentExamples() -> [ClassificationPair] {
        // Return empty array as a placeholder
        return []
    }
    
    // MARK: - Private Helper Methods
    
    private func createDocumentFingerprint(from text: String) -> String {
        // Create a simple hash of the document text
        let hash = text.hash
        return "doc-\(abs(hash))"
    }
}

// Minimal implementation of ClassificationPair for backward compatibility
struct ClassificationPair {
    let documentFingerprint: String
    let aiSuggestion: DocumentClassifierService.DocumentSuggestions
    let userSelection: DocumentClassifierService.DocumentSuggestions
    let timestamp: Date
    
    // Default initializer with safe defaults
    init(documentFingerprint: String = "",
         aiSuggestion: DocumentClassifierService.DocumentSuggestions = DocumentClassifierService.DocumentSuggestions(suggestedTitle: "", suggestedFolderName: nil, suggestedTags: [], confidence: 0.0),
         userSelection: DocumentClassifierService.DocumentSuggestions = DocumentClassifierService.DocumentSuggestions(suggestedTitle: "", suggestedFolderName: nil, suggestedTags: [], confidence: 0.0),
         timestamp: Date = Date()) {
        self.documentFingerprint = documentFingerprint
        self.aiSuggestion = aiSuggestion
        self.userSelection = userSelection
        self.timestamp = timestamp
    }
}

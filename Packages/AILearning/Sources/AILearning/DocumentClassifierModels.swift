import Foundation

/// This file contains minimal declarations of key types from the DocumentClassifierService
/// to avoid circular dependencies between modules

/// Namespace mirroring the original DocumentClassifierService
public enum DocumentClassifierService {
    /// Document suggestions model used by AdaptiveLearningClassifier
    public struct DocumentSuggestions {
        public let suggestedTitle: String
        public let suggestedFolderName: String?
        public let suggestedTags: [String]
        public let confidence: Double
        
        public init(suggestedTitle: String, suggestedFolderName: String?, suggestedTags: [String], confidence: Double) {
            self.suggestedTitle = suggestedTitle
            self.suggestedFolderName = suggestedFolderName
            self.suggestedTags = suggestedTags
            self.confidence = confidence
        }
    }
}

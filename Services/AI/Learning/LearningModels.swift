import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

extension AI_Learning {
    /// Models and data structures for the AdaptiveLearningClassifier
    
    // Store both AI suggestions and user's final choices
    struct ClassificationPair: Codable {
        let documentFingerprint: String  // Hash or signature of document
        let aiSuggestion: DocumentClassifierService.DocumentSuggestions
        let userSelection: DocumentClassifierService.DocumentSuggestions
        let timestamp: Date
        
        // Standard memberwise initializer
        init(documentFingerprint: String, 
             aiSuggestion: DocumentClassifierService.DocumentSuggestions,
             userSelection: DocumentClassifierService.DocumentSuggestions,
             timestamp: Date) {
            self.documentFingerprint = documentFingerprint
            self.aiSuggestion = aiSuggestion
            self.userSelection = userSelection
            self.timestamp = timestamp
        }
        
        // Custom Codable implementation because DocumentClassifierService.DocumentSuggestions isn't Codable
        enum CodingKeys: String, CodingKey {
            case documentFingerprint, timestamp
            case aiSuggestion, userSelection
        }
        
        // Custom encoding for DocumentSuggestions
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(documentFingerprint, forKey: .documentFingerprint)
            try container.encode(timestamp, forKey: .timestamp)
            
            // Encode AI suggestion
            var aiContainer = container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .aiSuggestion)
            try aiContainer.encode(aiSuggestion.suggestedTitle, forKey: .title)
            try aiContainer.encode(aiSuggestion.suggestedFolderName, forKey: .folder)
            try aiContainer.encode(aiSuggestion.suggestedTags, forKey: .tags)
            try aiContainer.encode(aiSuggestion.confidence, forKey: .confidence)
            
            // Encode user selection
            var userContainer = container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .userSelection)
            try userContainer.encode(userSelection.suggestedTitle, forKey: .title)
            try userContainer.encode(userSelection.suggestedFolderName, forKey: .folder)
            try userContainer.encode(userSelection.suggestedTags, forKey: .tags)
            try userContainer.encode(userSelection.confidence, forKey: .confidence)
        }
        
        // Custom decoding for DocumentSuggestions
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            documentFingerprint = try container.decode(String.self, forKey: .documentFingerprint)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            
            // Decode AI suggestion
            let aiContainer = try container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .aiSuggestion)
            let aiTitle = try aiContainer.decode(String.self, forKey: .title)
            // Make folder decoding safer by handling nulls
            let aiFolder: String?
            if try aiContainer.contains(.folder) && !(try aiContainer.decodeNil(forKey: .folder)) {
                aiFolder = try aiContainer.decode(String.self, forKey: .folder)
            } else {
                aiFolder = nil
            }
            let aiTags = try aiContainer.decode([String].self, forKey: .tags)
            let aiConfidence = try aiContainer.decode(Double.self, forKey: .confidence)
            
            aiSuggestion = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: aiTitle,
                suggestedFolderName: aiFolder,
                suggestedTags: aiTags,
                confidence: aiConfidence
            )
            
            // Decode user selection
            let userContainer = try container.nestedContainer(keyedBy: SuggestionCodingKeys.self, forKey: .userSelection)
            let userTitle = try userContainer.decode(String.self, forKey: .title)
            // Make folder decoding safer by handling nulls
            let userFolder: String?
            if try userContainer.contains(.folder) && !(try userContainer.decodeNil(forKey: .folder)) {
                userFolder = try userContainer.decode(String.self, forKey: .folder)
            } else {
                userFolder = nil
            }
            let userTags = try userContainer.decode([String].self, forKey: .tags)
            let userConfidence = try userContainer.decode(Double.self, forKey: .confidence)
            
            userSelection = DocumentClassifierService.DocumentSuggestions(
                suggestedTitle: userTitle,
                suggestedFolderName: userFolder,
                suggestedTags: userTags,
                confidence: userConfidence
            )
        }
        
        // Nested coding keys for DocumentSuggestions
        enum SuggestionCodingKeys: String, CodingKey {
            case title, folder, tags, confidence
        }
    }
    
    // Learning statistics data structure
    struct LearningStatistics {
        let totalExamples: Int
        let folderCorrections: Int
        let tagCorrections: Int
    }
    
    // Keys for tracking learning statistics in UserDefaults
    struct StatKeys {
        static let totalChanges = "learning_stat_total_changes"
        static let titleChanges = "learning_stat_title_changes"
        static let folderChanges = "learning_stat_folder_changes"
        static let tagsAdded = "learning_stat_tags_added"
        static let tagsRemoved = "learning_stat_tags_removed"
        static let deletedFolderHistory = "deleted_folder_history"
        static let deletedTagHistory = "deleted_tag_history"
    }
}

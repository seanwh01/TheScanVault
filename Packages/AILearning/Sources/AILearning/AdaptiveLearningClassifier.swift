import Foundation
import CoreData

/// Main implementation of the adaptive learning classifier
/// This class serves as the container for all adaptive learning components
extension AI_Learning {
    public class AdaptiveLearningClassifier {
        // Core component that handles the actual classification logic
        private let classifierCore: LearningClassifierCore
        
        // Reference to the persistence controller for CoreData operations
        private let persistenceController: PersistenceController
        
        // MARK: - Initialization
        
        /// Initialize with a PersistenceController
        /// - Parameter persistenceController: The CoreData persistence controller
        public init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
            
            print("🧠 Initializing AdaptiveLearningClassifier...")
            
            // Initialize the core classifier which manages all subcomponents
            self.classifierCore = LearningClassifierCore(persistenceController: persistenceController)
            
            print("🧠 AdaptiveLearningClassifier initialized")
        }
        
        // MARK: - Public Methods
        
        /// Complete initialization with background tasks
        public func finishInitialization() {
            classifierCore.finishInitialization()
        }
        
        /// Record when user corrects an AI suggestion
        public func recordUserCorrection(originalText: String, 
                                 aiSuggestion: DocumentClassifierService.DocumentSuggestions,
                                 finalUserChoice: DocumentClassifierService.DocumentSuggestions) {
            classifierCore.recordUserCorrection(
                originalText: originalText,
                aiSuggestion: aiSuggestion,
                finalUserChoice: finalUserChoice
            )
        }
        
        /// Use the learning database to enhance OpenAI prompts
        public func enhancePromptWithLearning(documentText: String, basePrompt: String) -> String {
            return classifierCore.enhancePromptWithLearning(
                documentText: documentText,
                basePrompt: basePrompt
            )
        }
        
        /// Load learning examples from persistent storage
        public func loadLearningExamples() {
            classifierCore.loadLearningExamples()
        }
        
        /// Get statistics about the learning database
        public func getLearningStatistics() -> (totalExamples: Int, folderCorrections: Int, tagCorrections: Int) {
            return classifierCore.getLearningStatistics()
        }
        
        /// Verify and fix any issues with CoreData storage
        public func verifyAndFixCoreDataStorage() {
            classifierCore.verifyAndFixCoreDataStorage()
        }
        
        /// Repair any broken entity relationships
        public func repairBrokenEntities() {
            classifierCore.repairBrokenEntities()
        }
        
        /// Get lists of deleted folders and tags
        public func getDeletedFoldersAndTags() -> (folders: [String], tags: [String]) {
            return classifierCore.getDeletedFoldersAndTags()
        }
        
        /// Get history of deleted items
        public func getDeletedItemsHistory() -> [(type: String, name: String, date: Date)] {
            return classifierCore.getDeletedItemsHistory()
        }
        
        /// Get statistics about folder-tag pattern associations
        public func getFolderTagPatternStatistics() -> [String: [(tag: String, frequency: Double)]] {
            return classifierCore.getFolderTagPatternStatistics()
        }
        
        // MARK: - Debug Methods
        
        /// Debug function to get learned folder patterns
        public func debugGetLearnedFolderPatterns() -> [(original: String, updated: String, count: Int)] {
            return classifierCore.debugGetLearnedFolderPatterns()
        }
        
        /// Debug function to get recent examples
        public func debugGetRecentExamples() -> [ClassificationPair] {
            return classifierCore.debugGetRecentExamples()
        }
    }
}

// Make ClassificationPair available at the top level for backward compatibility
typealias ClassificationPair = AI_Learning.ClassificationPair

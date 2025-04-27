import Foundation
import CoreData

/// Namespace for all AI learning-related components
/// This serves as the main entry point for the AILearning module
public enum AI_Learning {
    // This enum serves as a namespace to organize adaptive learning components
    // The actual implementation is in separate files
    
    // Re-export key types to simplify imports
    public typealias ClassificationPair = AI_Learning.ClassificationPair
    public typealias LearningStatistics = AI_Learning.LearningStatistics
    
    // Initialize the module (called once at app startup)
    public static func initialize() {
        print("🧠 AI_Learning module initialized")
    }
}

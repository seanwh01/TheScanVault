import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Vision
import Combine
import CoreData

// Public access to all AppServices components
// Refactored to be an ObservableObject instance
public class AppServices: ObservableObject {
    
    // Service Properties
    let persistenceController: PersistenceController
    let documentProcessor: DocumentProcessor // Assuming this might be needed
    let documentClassifierService: DocumentClassifierService
    let adaptiveLearningClassifier: AdaptiveLearningClassifier
    let documentLearningService: DocumentLearningService // Ensure it's declared
    let openAIService: OpenAIService // Add OpenAIService property
    let documentAIService: DocumentAIService // Add DocumentAIService property
    
    // Initializer
    public init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        
        // Initialize services (order matters for dependencies)
        let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? ""
        self.openAIService = OpenAIService(apiKey: apiKey)
        self.adaptiveLearningClassifier = AdaptiveLearningClassifier(persistenceController: persistenceController)
        self.documentAIService = DocumentAIService(adaptiveLearningClassifier: self.adaptiveLearningClassifier) // Init DocumentAIService
        self.documentClassifierService = DocumentClassifierService(persistenceController: persistenceController, documentAIService: self.documentAIService)
        self.documentLearningService = DocumentLearningService(persistenceController: persistenceController, adaptiveClassifier: self.adaptiveLearningClassifier)
        
        #if os(iOS)
        print("🚀 Initializing App services for iOS...")
        // Initialize iOS-specific services using the controller
        self.documentProcessor = DocumentProcessor(openAIService: self.openAIService, persistenceController: persistenceController, documentAIService: self.documentAIService, adaptiveLearningClassifier: self.adaptiveLearningClassifier)
        
        // Finish initialization for adaptive classifier
        self.adaptiveLearningClassifier.finishInitialization()
        
        print("👍 App services initialized for iOS.")
        #elseif os(macOS)
        print("🚀 Initializing App services for macOS...")
        // Initialize macOS-compatible services (placeholders if none)
        // Need to define what macOS needs. For now, let's ensure properties are initialized to avoid compiler errors.
        // If these services are iOS-only, they might need optional types or different handling.
        // For now, assuming placeholder initializers or errors if used on macOS.
        
        // ADDED: Initialize all services for macOS, mirroring iOS
        self.documentProcessor = DocumentProcessor(openAIService: self.openAIService, persistenceController: persistenceController, documentAIService: self.documentAIService, adaptiveLearningClassifier: self.adaptiveLearningClassifier)
        
        // ADDED: Finish initialization for adaptive classifier on macOS too
        self.adaptiveLearningClassifier.finishInitialization() // Keep for now
        
        print("👍 App services initialized for macOS.")
        #endif
    }
}
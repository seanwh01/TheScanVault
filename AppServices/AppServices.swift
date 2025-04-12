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
public class AppServices {
    // Make sure all services are initialized
    public static func initialize() {
        #if os(iOS)
        // Initialize iOS-specific services
        _ = DocumentProcessor.shared
        _ = DocumentClassifierService.shared
        _ = AdaptiveLearningClassifier.shared
        
        print("🚀 App services initialized for iOS")
        #elseif os(macOS)
        // Initialize only macOS-compatible services
        // Note: Document processing services aren't needed for the locking functionality on macOS
        
        print("🚀 App services initialized for macOS (limited functionality)")
        #endif
    }
} 
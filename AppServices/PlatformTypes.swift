import Foundation
#if os(iOS)
import UIKit
/// Cross-platform image type
public typealias PlatformImage = UIImage
/// Cross-platform color type
public typealias PlatformColor = UIColor
/// Cross-platform font type
public typealias PlatformFont = UIFont
#elseif os(macOS)
import AppKit
/// Cross-platform image type
public typealias PlatformImage = NSImage
/// Cross-platform color type
public typealias PlatformColor = NSColor
/// Cross-platform font type
public typealias PlatformFont = NSFont
#endif

/// Cross-platform shared types for use across iOS and macOS
enum PlatformTypes {
    /// Create a standard dictionary of sync data for CloudKit
    static func createSyncDictionary(for documentIds: [String]) -> [String: Any] {
        return [
            "lockedDocuments": documentIds,
            "updatedAt": Date()
        ]
    }
} 
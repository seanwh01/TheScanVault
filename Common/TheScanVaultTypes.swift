import Foundation
import SwiftUI
import CoreData

// Platform-specific image type
#if os(iOS)
import UIKit
public typealias ImageType = UIImage
#else
import AppKit
public typealias ImageType = NSImage

// Compatibility extensions for NSImage
extension NSImage {
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: Float(compressionQuality))])
    }
    
    convenience init?(data: Data) {
        self.init(data: data)
    }
}
#endif

// Core Data Entity Extensions
extension Folder {
    @objc var id: UUID? {
        get { return entityId }
        set { entityId = newValue }
    }
}

extension Tag {
    @objc var id: UUID? {
        get { return entityId }
        set { entityId = newValue }
    }
}

extension Document {
    @objc var id: UUID? {
        get { return entityId }
        set { entityId = newValue }
    }
}

// Utility Extensions
extension Float {
    var safeIntValue: Int {
        if self.isNaN || self.isInfinite {
            return 0
        }
        return Int(self)
    }
} 
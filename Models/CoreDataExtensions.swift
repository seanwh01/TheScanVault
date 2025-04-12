import Foundation
import CoreData

// Extensions to provide proper ID access for Core Data entities
// This file is deliberately separate from CoreDataTypeDefinitions.swift to avoid conflicts

#if os(iOS) || os(macOS)
// Document extension to provide UUID-based Identifiable conformance
extension Document {
    // Already Identifiable via NSManagedObject, this just provides a UUID accessor
    public var uniqueId: UUID? {
        return entityId
    }
}

// Folder extension to provide UUID-based Identifiable conformance
extension Folder {
    // Already Identifiable via NSManagedObject, this just provides a UUID accessor
    public var uniqueId: UUID? {
        return entityId
    }
}

// Tag extension to provide UUID-based Identifiable conformance
extension Tag {
    // Already Identifiable via NSManagedObject, this just provides a UUID accessor
    public var uniqueId: UUID? {
        return entityId
    }
}
#endif 
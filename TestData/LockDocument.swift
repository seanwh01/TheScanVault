import Foundation

// Utility class for document locking test operations
class DocumentLockUtility {
    
    // Static method that can be called from tests
    static func lockDocument(_ documentIdString: String) {
        guard let documentId = UUID(uuidString: documentIdString) else {
            print("Error: Invalid UUID format")
            return
        }
        
        // Get current locked documents
        var lockedDocuments = UserDefaults.standard.stringArray(forKey: "com.scanvault.lockedDocuments") ?? []
        
        // Add this document ID if not already locked
        if !lockedDocuments.contains(documentIdString) {
            lockedDocuments.append(documentIdString)
            UserDefaults.standard.set(lockedDocuments, forKey: "com.scanvault.lockedDocuments")
            print("🔒 Locked document: \(documentIdString)")
        } else {
            print("🔒 Document was already locked: \(documentIdString)")
        }
        
        // Print all locked documents
        print("Currently locked documents (\(lockedDocuments.count)):")
        for docId in lockedDocuments {
            print("  - \(docId)")
        }
        
        // Set a default password for document locking if not already set
        let lockServiceName = "com.scanvault.documentlock"
        let lockAccountName = "documentLockPassword"
        let defaultPassword = "test123"
        
        // Since we can't use KeychainManager directly here, print instructions
        print("\nTo set a password in the app, you can use:")
        print("1. DocumentLockManager.shared.saveDocumentLockPassword(\"\(defaultPassword)\")")
        print("2. Or set it in the app's settings")
    }
    
    // Utility method to print usage instructions
    static func printUsage() {
        print("Usage: Call DocumentLockUtility.lockDocument(\"document-uuid-string\") from your test")
    }
} 
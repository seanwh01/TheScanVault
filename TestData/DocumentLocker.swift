import Foundation

// Test utility to explicitly lock or unlock documents for testing
class DocumentLocker {
    // Singleton instance
    static let shared = DocumentLocker()
    
    private init() {}
    
    // Lock a document with the given ID
    func lockDocument(id: UUID) {
        // Get current locked documents
        var lockedDocuments: [String] = UserDefaults.standard.stringArray(forKey: "com.scanvault.lockedDocuments") ?? []
        
        // Add this document ID if not already locked
        let idString = id.uuidString
        if !lockedDocuments.contains(idString) {
            lockedDocuments.append(idString)
            UserDefaults.standard.set(lockedDocuments, forKey: "com.scanvault.lockedDocuments")
            print("🔒 Locked document: \(idString)")
        } else {
            print("🔒 Document was already locked: \(idString)")
        }
    }
    
    // Unlock a document with the given ID
    func unlockDocument(id: UUID) {
        // Get current locked documents
        var lockedDocuments: [String] = UserDefaults.standard.stringArray(forKey: "com.scanvault.lockedDocuments") ?? []
        
        // Remove this document ID if it's locked
        let idString = id.uuidString
        if let index = lockedDocuments.firstIndex(of: idString) {
            lockedDocuments.remove(at: index)
            UserDefaults.standard.set(lockedDocuments, forKey: "com.scanvault.lockedDocuments")
            print("🔓 Unlocked document: \(idString)")
        } else {
            print("🔓 Document was not locked: \(idString)")
        }
    }
    
    // Print all currently locked documents
    func listLockedDocuments() {
        let lockedDocuments: [String] = UserDefaults.standard.stringArray(forKey: "com.scanvault.lockedDocuments") ?? []
        print("Currently locked documents (\(lockedDocuments.count)):")
        for docId in lockedDocuments {
            print("  - \(docId)")
        }
    }
    
    // Set password for document locking
    func setPassword(_ password: String) {
        // You'll need to implement the KeychainManager here
        print("⚠️ Password setting not implemented in this test utility")
    }
}

// Example usage:
// DocumentLocker.shared.lockDocument(id: UUID(uuidString: "4657ABCC-5EF0-4434-BF74-E15525AFF7E9")!)
// DocumentLocker.shared.listLockedDocuments() 
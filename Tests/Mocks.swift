import Foundation
@testable import TheScanVault

// This file is maintained for project references
// The actual mock implementations are now in the test files
// Just importing the namespace here to satisfy the build system

// Define a namespace for test mocks to avoid conflicts
enum TestMocks {
    // Mock implementation of KeychainServiceProtocol
    class KeychainService: KeychainServiceProtocol {
        private var items: [String: String] = [:]
        
        func saveAPIKey(key: String, service: String, account: String) -> Bool {
            items["\(service)_\(account)"] = key
            return true
        }
        
        func getAPIKey(service: String, account: String) -> String? {
            return items["\(service)_\(account)"]
        }
        
        func deleteAPIKey(service: String, account: String) -> Bool {
            items.removeValue(forKey: "\(service)_\(account)")
            return true
        }
        
        func scheduleCloudSync() {
            // Mock implementation - just log the call
            print("📱 Mock: scheduleCloudSync called")
        }
    }

    // Mock implementation of UserDefaultsProtocol
    class UserDefaults: UserDefaultsProtocol {
        private var storage: [String: Any] = [:]
        
        func array(forKey defaultName: String) -> [Any]? {
            return storage[defaultName] as? [Any]
        }
        
        func set(_ value: Any?, forKey defaultName: String) {
            storage[defaultName] = value
        }
    }

    // Mock implementation of CloudSyncManagerProtocol
    class CloudSyncManager: CloudSyncManagerProtocol {
        private var documentTitleCache: [String: String] = [:]
        private var lockedDocuments: [String] = []
        private var isCloudAvailable: Bool = true
        
        func updateDocumentTitleCache(_ titles: [String: String]) {
            documentTitleCache.merge(titles) { (_, new) in new }
            print("📱 Mock CloudSyncManager: Updated document title cache with \(titles.count) entries")
        }
        
        func fetchLockedDocuments(completion: @escaping ([String]?, Error?) -> Void) {
            print("📱 Mock CloudSyncManager: fetchLockedDocuments() called")
            completion(lockedDocuments, nil)
        }
        
        func syncLockedDocuments(_ documents: [String], completion: @escaping (Error?) -> Void) {
            print("📱 Mock CloudSyncManager: syncLockedDocuments() called with \(documents.count) documents")
            lockedDocuments = documents
            completion(nil)
        }
        
        func checkIsCloudAvailable() -> Bool {
            print("📱 Mock CloudSyncManager: checkIsCloudAvailable() called, returning \(isCloudAvailable)")
            return isCloudAvailable
        }
        
        // Helper methods for testing
        func setCloudAvailable(_ available: Bool) {
            isCloudAvailable = available
        }
        
        func setLockedDocuments(_ documents: [String]) {
            lockedDocuments = documents
        }
    }
}

// Helper function to create a document lock service for testing
func createTestDocumentLockService() -> DocumentLockService {
    let keychain = TestMocks.KeychainService()
    let userDefaults = TestMocks.UserDefaults()
    let cloudSync = TestMocks.CloudSyncManager()
    
    return DocumentLockServiceImpl(keychain: keychain, userDefaults: userDefaults, cloudSyncManager: cloudSync)
}

// Mock implementation of DocumentLockManager for testing
class MockDocumentLockManager {
    static var shared: MockDocumentLockManager = MockDocumentLockManager()
    
    // Set of document IDs that are considered locked
    private var lockedDocuments: Set<UUID> = []
    
    func lockDocument(_ documentId: UUID) {
        lockedDocuments.insert(documentId)
    }
    
    func unlockDocument(_ documentId: UUID) {
        lockedDocuments.remove(documentId)
    }
    
    func isDocumentLocked(_ documentId: UUID) -> Bool {
        return lockedDocuments.contains(documentId)
    }
    
    // Reset all locks for fresh test runs
    func reset() {
        lockedDocuments.removeAll()
    }
} 
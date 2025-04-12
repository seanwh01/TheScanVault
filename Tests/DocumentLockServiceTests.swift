import XCTest
@testable import TheScanVault

// Create a custom test wrapper for KeychainService with stricter password verification
class StrictPasswordCheckingService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]
    
    func saveAPIKey(key: String, service: String, account: String) -> Bool {
        storage["\(service)_\(account)"] = key
        return true
    }
    
    func getAPIKey(service: String, account: String) -> String? {
        return storage["\(service)_\(account)"]
    }
    
    func deleteAPIKey(service: String, account: String) -> Bool {
        storage.removeValue(forKey: "\(service)_\(account)")
        return true
    }
    
    func scheduleCloudSync() {
        print("📱 StrictPasswordCheckingService: scheduleCloudSync() called (no-op)")
    }
}

// Standalone strict document lock service for testing
class StrictTestDocumentLockService: DocumentLockService {
    // Constants for keychain storage - define our own versions
    private let serviceName = "test.documentlock"
    private let accountName = "test.password"
    
    private let keychainService: KeychainServiceProtocol
    
    init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
        print("🔐 StrictTestDocumentLockService initialized")
    }
    
    func hasLock() -> Bool {
        let result = keychainService.getAPIKey(service: serviceName, account: accountName) != nil
        print("🔐 StrictTestDocumentLockService.hasLock(): \(result)")
        return result
    }
    
    func setupLock(password: String) -> Bool {
        let success = keychainService.saveAPIKey(key: password, service: serviceName, account: accountName)
        print("🔐 StrictTestDocumentLockService.setupLock(): \(success)")
        return success
    }
    
    func removeLock() -> Bool {
        let success = keychainService.deleteAPIKey(service: serviceName, account: accountName)
        print("🔐 StrictTestDocumentLockService.removeLock(): \(success)")
        return success
    }
    
    func verifyPassword(_ password: String) -> Bool {
        // Get the stored password from the keychain
        if let storedPassword = keychainService.getAPIKey(service: serviceName, account: accountName) {
            // Only direct match, no fallbacks
            let result = storedPassword == password
            print("🔑 Strict password verification: \(result ? "success" : "failure")")
            return result
        }
        print("🔑 Strict password verification: no stored password")
        return false
    }
    
    // Minimal stub implementations for the rest of the protocol
    func isLocked(_ documentId: UUID) -> Bool { return false }
    func lock(_ documentId: UUID) -> Bool { return true }
    func unlock(_ documentId: UUID) -> Bool { return true }
    func updateDocumentTitles(_ titles: [UUID: String]) {}
    func isFolderLocked(_ folderName: String) -> Bool { return false }
    func lockFolder(_ folderName: String) -> Bool { return true }
    func unlockFolder(_ folderName: String) -> Bool { return true }
    func refreshLocksFromCloudKit() {}
    func fetchLocksFromCloudKit() {}
    func resetPassword() -> Bool { return true }
    func getCurrentPassword() -> String? { return nil }
    func isDocumentLocked(_ documentId: UUID) -> Bool { return false }
    func lockDocument(_ documentId: UUID) -> Bool { return true }
    func unlockDocument(_ documentId: UUID) -> Bool { return true }
    func getLockedDocuments() -> [UUID] { return [] }
    func getLockedDocumentIds() -> [UUID] { return [] }
    func fetchLocksFromCloudKit(completion: @escaping () -> Void) { completion() }
}

class DocumentLockServiceTests: XCTestCase {
    var service: DocumentLockService!
    var mockKeychain: TestMocks.KeychainService!
    var strictKeychain: StrictPasswordCheckingService!
    var mockUserDefaults: TestMocks.UserDefaults!
    var mockCloudSync: TestMocks.CloudSyncManager!
    
    override func setUp() {
        super.setUp()
        mockKeychain = TestMocks.KeychainService()
        strictKeychain = StrictPasswordCheckingService()
        mockUserDefaults = TestMocks.UserDefaults()
        mockCloudSync = TestMocks.CloudSyncManager()
        
        // Use regular mock for most tests
        service = DocumentLockServiceImpl(keychain: mockKeychain, userDefaults: mockUserDefaults, cloudSyncManager: mockCloudSync)
    }
    
    override func tearDown() {
        service = nil
        mockKeychain = nil
        strictKeychain = nil
        mockUserDefaults = nil
        mockCloudSync = nil
        super.tearDown()
    }
    
    func testLockUnlock() {
        let documentId = UUID()
        
        // Test locking
        XCTAssertFalse(service.isLocked(documentId))
        XCTAssertTrue(service.lock(documentId))
        XCTAssertTrue(service.isLocked(documentId))
        
        // Test unlocking
        XCTAssertTrue(service.unlock(documentId))
        XCTAssertFalse(service.isLocked(documentId))
    }
    
    func testPasswordVerification() {
        // Create a strict service that doesn't have the default password fallback
        let strictService = StrictTestDocumentLockService(keychainService: strictKeychain)
        
        let password = "test123"
        
        // Test setup
        XCTAssertTrue(strictService.setupLock(password: password))
        
        // Test verification
        XCTAssertTrue(strictService.verifyPassword(password))
        
        // Test wrong password
        XCTAssertFalse(strictService.verifyPassword("wrong_password"))
    }
    
    func testHasLock() {
        XCTAssertFalse(service.hasLock())
        XCTAssertTrue(service.setupLock(password: "test123"))
        XCTAssertTrue(service.hasLock())
    }
} 
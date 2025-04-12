import XCTest
@testable import TheScanVault

class KeychainServiceMockTests: XCTestCase {
    
    func testMockKeychainService() {
        // Create a mock keychain service
        let mockKeychain = TestMocks.KeychainService()
        
        // Test saving a key
        let saveResult = mockKeychain.saveAPIKey(key: "testValue", service: "testService", account: "testAccount")
        XCTAssertTrue(saveResult, "Save should return true")
        
        // Test retrieving the key
        let retrievedValue = mockKeychain.getAPIKey(service: "testService", account: "testAccount")
        XCTAssertEqual(retrievedValue, "testValue", "Retrieved value should match saved value")
        
        // Test deleting the key
        let deleteResult = mockKeychain.deleteAPIKey(service: "testService", account: "testAccount")
        XCTAssertTrue(deleteResult, "Delete should return true")
        
        // Test that the key is gone
        let afterDeleteValue = mockKeychain.getAPIKey(service: "testService", account: "testAccount")
        XCTAssertNil(afterDeleteValue, "Value should be nil after deletion")
    }
    
    func testMockUserDefaults() {
        // Create a mock user defaults
        let mockDefaults = TestMocks.UserDefaults()
        
        // Test storing an array
        let testArray = ["item1", "item2", "item3"]
        mockDefaults.set(testArray, forKey: "testArray")
        
        // Test retrieving the array
        let retrievedArray = mockDefaults.array(forKey: "testArray") as? [String]
        XCTAssertEqual(retrievedArray, testArray, "Retrieved array should match saved array")
    }
} 
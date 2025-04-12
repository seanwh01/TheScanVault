import Foundation

// Extension to make KeychainManager conform to KeychainServiceProtocol
extension KeychainManager: KeychainServiceProtocol {
    // KeychainManager already has these methods, so it automatically conforms
}

// Extension to make UserDefaults conform to UserDefaultsProtocol
extension UserDefaults: UserDefaultsProtocol {
    // UserDefaults already has these methods, so it automatically conforms
} 
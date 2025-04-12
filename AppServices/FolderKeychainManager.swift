import Foundation

/// A manager class for handling folder information storage in the keychain
class FolderKeychainManager {
    static let shared = FolderKeychainManager()
    
    private let keychain = KeychainManager.shared
    
    // Keys for keychain storage
    private let folderIDKey = "FolderID"
    private let folderNameKey = "FolderName"
    private let serviceName = "com.thescanvault.folders"
    
    private init() {}
    
    /// Saves folder information to the keychain
    /// - Parameters:
    ///   - documentId: The document ID associated with the folder
    ///   - folderId: The folder UUID
    ///   - folderName: The folder name
    ///   - account: Account identifier, defaults to "CurrentFolder"
    /// - Returns: Boolean indicating success
    func saveFolderInfo(documentId: String, folderId: UUID?, folderName: String?, account: String = "CurrentFolder") -> Bool {
        let folderIdStr = folderId?.uuidString ?? ""
        let folderNameStr = folderName ?? ""
        
        // Create a combined key with the document ID to make it unique
        let accountKey = "\(account)_\(documentId)"
        
        // Save both pieces of information
        let saveIdResult = keychain.saveAPIKey(key: folderIdStr, service: serviceName, account: "\(accountKey)_ID")
        let saveNameResult = keychain.saveAPIKey(key: folderNameStr, service: serviceName, account: "\(accountKey)_Name")
        
        return saveIdResult && saveNameResult
    }
    
    /// Retrieves folder information from the keychain
    /// - Parameters:
    ///   - documentId: The document ID associated with the folder
    ///   - account: Account identifier, defaults to "CurrentFolder"
    /// - Returns: Tuple containing folder ID and name
    func getFolderInfo(documentId: String, account: String = "CurrentFolder") -> (folderId: UUID?, folderName: String?) {
        // Create a combined key with the document ID to make it unique
        let accountKey = "\(account)_\(documentId)"
        
        // Get the folder ID and name
        let folderIdStr = keychain.getAPIKey(service: serviceName, account: "\(accountKey)_ID")
        let folderName = keychain.getAPIKey(service: serviceName, account: "\(accountKey)_Name")
        
        // Convert the folder ID string to UUID if it exists
        var folderId: UUID? = nil
        if let idStr = folderIdStr, !idStr.isEmpty {
            folderId = UUID(uuidString: idStr)
        }
        
        return (folderId, folderName)
    }
    
    /// Removes folder information from the keychain
    /// - Parameters:
    ///   - documentId: The document ID associated with the folder
    ///   - account: Account identifier, defaults to "CurrentFolder"
    /// - Returns: Boolean indicating success
    func removeFolderInfo(documentId: String, account: String = "CurrentFolder") -> Bool {
        // Create a combined key with the document ID to make it unique
        let accountKey = "\(account)_\(documentId)"
        
        // Delete both pieces of information
        let deleteIdResult = keychain.deleteAPIKey(service: serviceName, account: "\(accountKey)_ID")
        let deleteNameResult = keychain.deleteAPIKey(service: serviceName, account: "\(accountKey)_Name")
        
        return deleteIdResult && deleteNameResult
    }
} 
import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    // Track local-only passwords that need to be synced later
    private var pendingSync = false
    
    // Manual team ID that can be set at app startup
    private var manualTeamID: String?
    
    // The keychain access group for sharing between app variants and extensions
    private var keychainAccessGroup: String? {
        // If we have a manually set team ID, use it (most reliable)
        if let teamID = manualTeamID, !teamID.isEmpty {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.SWhiteApps.ScanVaultAI"
            
            #if os(macOS)
            return "\(teamID).\(bundleID)"
            #else
            return "\(teamID).com.SWhiteApps.ScanVaultAI"
            #endif
        }
        
        // Get team ID from bundle using multiple approaches
        var teamIDString = ""
        if let teamID = Bundle.main.object(forInfoDictionaryKey: "TeamIdentifier") as? [String], 
           let firstTeamID = teamID.first, !firstTeamID.isEmpty {
            teamIDString = firstTeamID
        }
        
        // Alternative: try to extract from app identifier prefix if available
        if teamIDString.isEmpty {
            let entitlements = Bundle.main.infoDictionary?["Entitlements"] as? [String: Any]
            if let accessGroups = entitlements?["keychain-access-groups"] as? [String],
               let firstGroup = accessGroups.first {
                // Usually in format: TEAMID.bundleID
                let components = firstGroup.components(separatedBy: ".")
                if components.count > 1 && components[0].count > 5 {
                    teamIDString = components[0]
                }
            }
        }
        
        // Last option: try to extract from app groups
        if teamIDString.isEmpty {
            let entitlements = Bundle.main.infoDictionary?["Entitlements"] as? [String: Any]
            if let appGroups = entitlements?["com.apple.security.application-groups"] as? [String],
               let firstGroup = appGroups.first {
                // Usually in format: group.TEAMID.bundleID or group.bundleID
                let components = firstGroup.components(separatedBy: ".")
                if components.count > 2 && components[1].count > 5 {
                    teamIDString = components[1]
                }
            }
        }
        
        let bundleID = Bundle.main.bundleIdentifier ?? "com.SWhiteApps.ScanVaultAI"
        
        // For safety, if we still don't have a team ID, use just the bundle ID
        // This will make the access group not share between versions but at least it will work locally
        if teamIDString.isEmpty {
            print("⚠️ Couldn't determine team ID for keychain access group")
            #if os(macOS)
            return bundleID
            #else
            return "com.SWhiteApps.ScanVaultAI"
            #endif
        }
        
        // Use full bundle ID on macOS for compatibility with entitlements
        #if os(macOS)
        return "\(teamIDString).\(bundleID)"
        #else
        // For iOS, use the app group-style identifier
        return "\(teamIDString).com.SWhiteApps.ScanVaultAI"
        #endif
    }
    
    /// Configure the team ID manually at app initialization
    /// - Parameter teamID: The Apple Developer Team ID (can be found in developer account)
    func configureTeamID(_ teamID: String) {
        manualTeamID = teamID
        print("🔑 Configured keychain with team ID: \(teamID)")
    }
    
    func saveAPIKey(key: String, service: String, account: String = "default") -> Bool {
        let keyData = key.data(using: .utf8)!
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            // Make key available after first unlock for security with better accessibility
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
        
        // Add the access group if available
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // First try to delete both synchronized and local items
        var syncDeleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true
        ]
        
        // Add the access group if available
        if let accessGroup = keychainAccessGroup {
            syncDeleteQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var localDeleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        
        // Add the access group if available
        if let accessGroup = keychainAccessGroup {
            localDeleteQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Try to clean up any existing items regardless of sync status
        SecItemDelete(syncDeleteQuery as CFDictionary)
        SecItemDelete(localDeleteQuery as CFDictionary)
        
        // Add the new key with sync enabled
        var status = SecItemAdd(query as CFDictionary, nil)
        
        // If successful, post a notification
        if status == errSecSuccess {
            print("✅ Keychain item saved with iCloud sync")
            
            // Notify that a password was saved to iCloud
            NotificationCenter.default.post(
                name: NSNotification.Name("PasswordSyncedToCloud"),
                object: nil
            )
            
            // Schedule a cloud sync to push this update to iCloud
            scheduleCloudSync()
            return true
        } else {
            // Log the error
            print("❌ Failed to save to keychain with iCloud sync (error: \(status))")
            
            // Try again without synchronizable flag if iCloud sync fails
            if status != errSecSuccess {
                print("⚠️ Falling back to local storage without iCloud sync")
                
                // Remove sync flag for local-only storage
                query.removeValue(forKey: kSecAttrSynchronizable as String)
                
                // Try to add as local-only item
                status = SecItemAdd(query as CFDictionary, nil)
                if status == errSecSuccess {
                    print("✅ Keychain item saved locally (without iCloud sync)")
                    
                    // Schedule future attempts to sync this to iCloud when available
                    pendingSync = true
                    
                    // Try again in a few seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        print("🔄 Retrying iCloud keychain sync after delay")
                        guard let self = self else { return }
                        let _ = self.saveAPIKey(key: key, service: service, account: account)
                    }
                    
                    return true
                } else {
                    print("❌ Failed to save to local keychain (error: \(status))")
                    return false
                }
            }
        }
        
        return status == errSecSuccess
    }
    
    /// Retrieve an API key from the keychain
    /// - Parameters:
    ///   - service: The service name
    ///   - account: The account name
    /// - Returns: The API key if available
    func getAPIKey(service: String, account: String = "default") -> String? {
        print("🔑 Attempting to get keychain item: \(service)")
        
        // First try to get the synchronized value from iCloud
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
        
        // Add the access group if available
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        // If we found a synchronized password, use it
        if status == errSecSuccess {
            guard let data = item as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            print("🔑 Successfully retrieved synchronized password from iCloud keychain")
            return password
        }
        
        // If we can't find a synchronized value, try to find any value (including local)
        print("🔑 No iCloud keychain password found (status: \(status)), trying any available")
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        
        item = nil
        let anyStatus = SecItemCopyMatching(query as CFDictionary, &item)
        
        if anyStatus == errSecSuccess {
            guard let data = item as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            print("📱 Found password in local keychain, will sync to iCloud when available")
            
            // Try to promote this to an iCloud keychain item
            scheduleCloudSync()
            
            return password
        }
        
        print("🔑 No iCloud keychain password found (status: \(anyStatus))")
        return nil
    }
    
    /// Retrieve an API key from the keychain with a custom key name
    /// - Parameters:
    ///   - service: The service name
    ///   - account: The account name
    ///   - key: Custom key name, defaults to the account name
    /// - Returns: The API key if available
    func getAPIKey(service: String, account: String, key: String) -> String? {
        // Use the provided key or fallback to the account name
        let actualKey = key
        
        // Create the query
        var query = [String: Any]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service
        query[kSecAttrAccount as String] = actualKey
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        // Try with access group first if available
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var dataTypeRef: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        // If not found and we have an access group, try without it
        if status != errSecSuccess && keychainAccessGroup != nil {
            // Remove access group and try again
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        }
        
        // If successful, convert the data to a string
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data,
               let result = String(data: retrievedData, encoding: .utf8) {
                return result
            }
        }
        
        return nil
    }
    
    func deleteAPIKey(service: String, account: String) -> Bool {
        // Delete from iCloud keychain
        var syncQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true
        ]
        
        // Add the access group if available
        if let accessGroup = keychainAccessGroup {
            syncQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let syncStatus = SecItemDelete(syncQuery as CFDictionary)
        
        // Delete from local keychain
        var localQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        
        // Add the access group if available
        if let accessGroup = keychainAccessGroup {
            localQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let localStatus = SecItemDelete(localQuery as CFDictionary)
        
        return (syncStatus == errSecSuccess || syncStatus == errSecItemNotFound) && 
               (localStatus == errSecSuccess || localStatus == errSecItemNotFound)
    }
    
    func scheduleCloudSync() {
        // Try to sync immediately
        DispatchQueue.global(qos: .utility).async {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
            ]
            
            // Add the access group if available
            if let accessGroup = self.keychainAccessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }
            
            // Force a sync by doing a read operation
            var result: CFTypeRef?
            let _ = SecItemCopyMatching(query as CFDictionary, &result)
        }
        
        // Then schedule multiple retries with increasing delays
        let delays = [0.5, 1.0, 3.0, 5.0, 10.0]
        
        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                print("🔄 Scheduling keychain sync attempt \(index + 1) after \(delay) seconds")
                DispatchQueue.global(qos: .utility).async {
                    var query: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
                    ]
                    
                    // Add the access group if available
                    if let accessGroup = self.keychainAccessGroup {
                        query[kSecAttrAccessGroup as String] = accessGroup
                    }
                    
                    // Force a sync by doing a read operation
                    var result: CFTypeRef?
                    let _ = SecItemCopyMatching(query as CFDictionary, &result)
                }
            }
        }
    }
} 
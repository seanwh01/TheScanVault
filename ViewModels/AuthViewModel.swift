import SwiftUI
import Combine
import Security

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let keychainService = "com.thescanvault.app"
    
    init() {
        checkForSavedCredentials()
    }
    
    func login(username: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, you would validate against a server
            // For now, we'll use simple validation
            if self.validateCredentials(username: username, password: password) {
                let user = User(id: UUID(), username: username, email: "\(username)@example.com")
                self.currentUser = user
                self.isAuthenticated = true
                self.saveCredentials(username: username, password: password)
            } else {
                self.errorMessage = "Invalid username or password"
            }
            
            self.isLoading = false
        }
    }
    
    func register(username: String, email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // In a real app, you would register with a server
            // For now, we'll pretend it worked
            let user = User(id: UUID(), username: username, email: email)
            self.currentUser = user
            self.isAuthenticated = true
            self.saveCredentials(username: username, password: password)
            
            self.isLoading = false
        }
    }
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
        deleteCredentials()
    }
    
    func forgotPassword(email: String) {
        // In a real app, this would trigger a password reset flow
        errorMessage = nil
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            // Show confirmation
        }
    }
    
    private func validateCredentials(username: String, password: String) -> Bool {
        // In a real app, validate against server
        // For development purposes, accept any non-empty credentials
        return !username.isEmpty && !password.isEmpty
    }
    
    private func checkForSavedCredentials() {
        guard let credentials = retrieveCredentials() else { return }
        login(username: credentials.username, password: credentials.password)
    }
    
    // MARK: - Keychain Management
    
    private func saveCredentials(username: String, password: String) {
        let credentials = "\(username):\(password)".data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecValueData as String: credentials
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func retrieveCredentials() -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let credentialsString = String(data: data, encoding: .utf8),
              let separatorIndex = credentialsString.firstIndex(of: ":")
        else {
            return nil
        }
        
        let username = String(credentialsString[..<separatorIndex])
        let password = String(credentialsString[credentialsString.index(after: separatorIndex)...])
        
        return (username, password)
    }
    
    private func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Password Verification
    
    func verifyPassword(_ password: String) -> Bool {
        guard let credentials = retrieveCredentials() else { 
            return false 
        }
        
        // Check if the provided password matches the stored password
        return credentials.password == password
    }
    
    // MARK: - Email Management
    
    func updateEmail(newEmail: String) {
        guard let currentUser = currentUser else { return }
        
        // In a real app, this would update the email on a server
        // For now, we'll just update the local model
        
        // Create a new user with the updated email
        let updatedUser = User(
            id: currentUser.id,
            username: currentUser.username,
            email: newEmail,
            subscriptionLevel: currentUser.subscriptionLevel
        )
        
        // Update the current user
        self.currentUser = updatedUser
        
        // In a real implementation, we would also update the email in saved credentials
        if let credentials = retrieveCredentials() {
            saveCredentials(username: credentials.username, password: credentials.password)
        }
    }
} 
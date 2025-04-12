//
//  ScanVaultAI_for_Mac_OSApp.swift
//  ScanVaultAI for Mac OS
//
//  Created by SEAN WHITE on 3/28/25.
//

import SwiftUI
import CoreData
import CloudKit
import Combine
import AppKit

// Import needed model files
// @_exported import struct Models.DocumentSelection
// @_exported import struct Models.WindowManager

// MARK: - Keychain Extensions

extension KeychainManager {
    /// Safely sets a value in the keychain, with proper nil handling
    /// - Parameters:
    ///   - value: The value to store, or nil
    ///   - forKey: The key to store it under
    ///   - service: The service name
    ///   - account: The account name
    /// - Returns: Success or failure
    func setWithSafety(_ value: String?, forKey key: String, service: String = "TheScanVault", account: String = "DefaultAccount") -> Bool {
        // Always provide a safe empty string if value is nil
        let safeValue = value ?? ""
        return self.saveAPIKey(key: safeValue, service: service, account: key)
    }
    
    /// Safely stores folder information for a document
    /// - Parameters:
    ///   - documentId: The document ID (can be nil)
    ///   - folder: The folder name (can be nil)
    ///   - folderId: The folder UUID (can be nil)
    /// - Returns: Success or failure
    func setFolderInfo(documentId: Any?, folder: String?, folderId: UUID?) -> Bool {
        var documentIdString = ""
        
        // Handle various document ID types
        if let stringValue = documentId as? String {
            documentIdString = stringValue
        } else if let uuidValue = documentId as? UUID {
            documentIdString = uuidValue.uuidString
        } else if let nsStringValue = documentId as? NSString {
            documentIdString = nsStringValue as String
        } else if let anyObject = documentId {
            // Convert any object to string representation
            documentIdString = String(describing: anyObject)
        }
        
        // Store folder ID
        let folderIdSuccess = self.setWithSafety(
            folderId?.uuidString,
            forKey: "FolderID",
            service: "TheScanVault.Folders",
            account: documentIdString
        )
        
        // Store folder name
        let folderNameSuccess = self.setWithSafety(
            folder,
            forKey: "FolderName",
            service: "TheScanVault.Folders",
            account: documentIdString
        )
        
        return folderIdSuccess && folderNameSuccess
    }
}

@main
struct ScanVaultAI_for_Mac_OSApp: App {
    // Core Data persistent container
    @StateObject private var persistenceController = PersistenceController.shared
    
    // Document selection state
    @StateObject private var documentSelection = DocumentSelection()
    
    // Window manager to track open document windows
    @StateObject private var windowManager = WindowManager()
    
    // Document lock manager to handle document locking
    @StateObject private var documentLockManager = DocumentLockManager()
    
    // Fix for macOS 14 window behavior
    @State private var didInitializeWindow = false
    
    init() {
        // Set up the keychain manager with proper team ID
        KeychainManager.shared.configureTeamID("YOURTEAMID")
        
        // Set the default user agent for network requests
        if let userAgent = Bundle.main.infoDictionary?["CFBundleName"] as? String {
            UserDefaults.standard.register(defaults: ["UserAgent": "\(userAgent)/1.0"])
        }
        
        // Configure subscription status
        configureSubscription()
        
        // Try reading existing password from keychain when app launches
        configureDocumentLock()
        
        // Run the keychain fix utility to detect and fix any folder information issues
        DispatchQueue.global(qos: .background).async {
            // Delay slightly to ensure Core Data is fully loaded
            Thread.sleep(forTimeInterval: 1.0)
            KeychainFixUtility.shared.detectAndFixKeyChainIssues()
        }
        
        // Initialize CloudKit and document locks
        CloudSyncManager.shared.subscribeToChanges { error in
            if let error = error {
                print("⚠️ Failed to set up CloudKit subscription: \(error.localizedDescription)")
            }
        }
        
        // Immediately fetch locked documents on app launch
        CloudSyncManager.shared.fetchLockedDocuments { _, _ in
            // Initial fetch completed
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(documentSelection)
                .environmentObject(windowManager)
                .environmentObject(documentLockManager)
                .onAppear {
                    // Set up CloudKit subscription and fetch initial data when the main view appears
                    CloudSyncManager.shared.subscribeToChanges { _ in }
                    CloudSyncManager.shared.fetchLockedDocuments { _, _ in }
                    
                    // Also verify document lock password state
                    checkAndSyncDocumentLockPassword()
                }
        }
        .commands {
            // Custom menu commands
            SidebarCommands()
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(documentLockManager)
        }
    }
    
    /// Ensures we have a document lock password set up
    private func setupDocumentLockPassword() {
        if !documentLockManager.hasLockPassword() {
            print("🔑 No document lock password found, checking with CloudSyncManager...")
            
            // Try to read from keychain
            if documentLockManager.initializePasswordFromKeychain() {
                print("ℹ️ Document lock password already exists")
            } else {
                // If no password exists, create a new one
                print("🔑 No existing password found, creating a new one")
                let _ = documentLockManager.setLockPassword(UUID().uuidString)
            }
        }
    }
    
    /// Check if we need to sync document lock password
    private func checkAndSyncDocumentLockPassword() {
        if CloudSyncManager.shared.checkIsCloudAvailable() {
            // Force keychain sync when iCloud is available
            documentLockManager.syncPasswordToiCloud()
        }
    }
}

// AppDelegate to handle Objective-C compatible notification callbacks
class AppDelegate: NSObject, ObservableObject {
    @objc func handleTemporaryDocumentAccess(_ notification: Notification) {
        guard let documentId = notification.userInfo?["documentId"] as? UUID else {
            return
        }
        
        print("🔐 Handling temporary document access for document: \(documentId)")
        
        // Refresh the UI to ensure lock status is properly displayed
        DispatchQueue.main.async {
            // Notify UI that document locks should be refreshed, without changing actual lock state
            NotificationCenter.default.post(
                name: NSNotification.Name("RefreshAllDocumentLocks"),
                object: nil
            )
        }
    }
}

// Delete the entire PersistenceController class from here
// Delete everything between these lines --------------------
// class PersistenceController {
//    ...all code here...
// }
// ---------------------------------------------------------

// This function can stay
func configureEntity(entity: NSEntityDescription) {
    #if os(iOS)
    // iOS-specific entity configuration
    #elseif os(macOS)
    // macOS-specific entity configuration
    #endif
}

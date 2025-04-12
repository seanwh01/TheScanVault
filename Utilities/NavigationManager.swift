import Foundation
import SwiftUI

class NavigationManager: ObservableObject {
    // Notification names for navigation events
    static let navigateToDocumentEdit = Notification.Name("NavigateToDocumentEdit")
    static let navigateToSettings = Notification.Name("NavigateToSettings")
    static let navigateToVault = Notification.Name("NavigateToVault")
    
    // Navigation state
    @Published var activeTab: Int = 0
    @Published var selectedDocumentId: String?
    @Published var isEditingDocument: Bool = false
    
    func navigateToDocumentEdit(documentId: String) {
        self.selectedDocumentId = documentId
        self.isEditingDocument = true
        
        // Post notification to trigger navigation in main app view
        NotificationCenter.default.post(
            name: NavigationManager.navigateToDocumentEdit,
            object: nil,
            userInfo: ["documentId": documentId]
        )
        
        // Switch to vault tab if needed (tab index may vary based on your app)
        activeTab = 1 // Assuming 1 is the vault tab
    }
    
    func navigateToVault() {
        activeTab = 1 // Assuming 1 is the vault tab
        
        NotificationCenter.default.post(
            name: NavigationManager.navigateToVault,
            object: nil
        )
    }
    
    func navigateToSettings() {
        activeTab = 2 // Assuming 2 is the settings tab
        
        NotificationCenter.default.post(
            name: NavigationManager.navigateToSettings,
            object: nil
        )
    }
} 
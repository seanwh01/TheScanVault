import SwiftUI
import Combine
import CoreData

class SubscriptionManager: ObservableObject {
    @Published var currentSubscription: User.SubscriptionLevel = .basic
    @Published var isUpgrading = false
    @Published var isDowngrading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load subscription status from UserDefaults
        if let subscriptionString = UserDefaults.standard.string(forKey: "userSubscription"),
           let subscription = User.SubscriptionLevel(rawValue: subscriptionString) {
            currentSubscription = subscription
        }
    }
    
    func upgradeToPremiun() {
        isUpgrading = true
        errorMessage = nil
        
        // In a real app, this would communicate with payment processor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            // Update subscription status
            self.currentSubscription = .premium
            
            // Save to UserDefaults and ensure consistent premium status across all keys
            UserDefaults.standard.set(self.currentSubscription.rawValue, forKey: "userSubscription")
            self.syncPremiumStatusAcrossApp()
            
            // Start the iCloud sync process
            self.syncLocalToCloud()
            
            self.isUpgrading = false
        }
    }
    
    func downgradeToBasic() {
        isDowngrading = true
        errorMessage = nil
        
        // In a real app, this would communicate with payment processor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            // Ensure all documents are synced from cloud to local
            self.syncCloudToLocal {
                // Update subscription status
                self.currentSubscription = .basic
                
                // Save to UserDefaults and ensure consistent premium status across all keys
                UserDefaults.standard.set(self.currentSubscription.rawValue, forKey: "userSubscription")
                self.syncPremiumStatusAcrossApp()
                
                self.isDowngrading = false
            }
        }
    }
    
    // MARK: - Sync Methods
    
    private func syncLocalToCloud() {
        // In a real app, this would trigger a proper iCloud sync
        // For development purposes, we'll just simulate success
        print("Syncing local documents to iCloud...")
    }
    
    private func syncCloudToLocal(completion: @escaping () -> Void) {
        // In a real app, this would ensure all iCloud documents are downloaded
        // For development purposes, we'll just simulate success
        print("Syncing iCloud documents to local storage...")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion()
        }
    }
    
    // MARK: - Status Information
    
    var isPremium: Bool {
        return currentSubscription == .premium
    }
    
    var subscriptionName: String {
        return currentSubscription == .premium ? "Premium" : "Basic"
    }
    
    var subscriptionFeatures: [String] {
        if currentSubscription == .premium {
            return [
                "Full app functionality",
                "Bulk export of documents",
                "Cross-device access",
                "iCloud sync for long-term storage"
            ]
        } else {
            return [
                "Full app functionality",
                "Documents accessible only while using the app"
            ]
        }
    }
    
    // Sync premium status across all UserDefaults keys used in the app
    private func syncPremiumStatusAcrossApp() {
        // Ensure the IsPremiumUser key is set properly to match currentSubscription
        UserDefaults.standard.set(isPremium, forKey: "IsPremiumUser")
        
        // Log status for debugging
        print("🔄 Subscription manager update called - syncing premium status to all UserDefaults keys")
        print("🔄 Subscription status: \(isPremium ? "Premium" : "Basic") with AI enabled - triggering document reanalysis")
        
        // Post a notification so other components can respond to subscription changes
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionStatusChanged"), object: nil)
    }
} 
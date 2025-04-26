import SwiftUI
import CoreData

@main
struct ScanVaultApp: App {
    // MARK: - State Objects
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appServices: AppServices

    init() {
        // Initialize AppServices with persistenceController
        _appServices = StateObject(wrappedValue: AppServices(persistenceController: PersistenceController.shared))
        
        // Configure logging levels
        configureLogging()
        
        if UserDefaults.standard.object(forKey: "AIDocumentClassificationEnabled") == nil {
            print(" First run - Setting default AI Classification to OFF")
            UserDefaults.standard.set(false, forKey: "AIDocumentClassificationEnabled")
            UserDefaults.standard.set(Date(), forKey: "AIToggleLastUpdateTime")
        } else {
            let currentValue = UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled")
            print(" App startup - Current AI Classification setting: \(currentValue)")
        }
    }
    
    /// Configure CoreData and CloudKit logging levels
    private func configureLogging() {
        // Set default values if they don't exist
        if UserDefaults.standard.object(forKey: "com.apple.CoreData.CloudKitDebug") == nil {
            UserDefaults.standard.set(0, forKey: "com.apple.CoreData.CloudKitDebug")
        }
        
        if UserDefaults.standard.object(forKey: "com.apple.CoreData.Logging.stderr") == nil {
            UserDefaults.standard.set(0, forKey: "com.apple.CoreData.Logging.stderr")
        }
        
        if UserDefaults.standard.object(forKey: "com.apple.CoreData.SQLDebug") == nil {
            UserDefaults.standard.set(0, forKey: "com.apple.CoreData.SQLDebug")
        }
        
        // Apply the current settings
        let cloudKitLevel = UserDefaults.standard.integer(forKey: "com.apple.CoreData.CloudKitDebug")
        let coreDataLevel = UserDefaults.standard.integer(forKey: "com.apple.CoreData.Logging.stderr")
        let sqlLevel = UserDefaults.standard.integer(forKey: "com.apple.CoreData.SQLDebug")
        
        print(" Configuring logging - CloudKit: \(cloudKitLevel), CoreData: \(coreDataLevel), SQL: \(sqlLevel)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(persistenceController)
                .environmentObject(subscriptionManager)
                .environmentObject(navigationManager)
                .environmentObject(authViewModel)
                .environmentObject(appServices)
        }
    }
}
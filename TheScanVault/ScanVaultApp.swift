import SwiftUI
import CoreData

@main
struct ScanVaultApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var navigationManager = NavigationManager()
    let persistenceController = PersistenceController.shared
    
    init() {
        // Configure logging levels
        configureLogging()
        
        if UserDefaults.standard.object(forKey: "AIDocumentClassificationEnabled") == nil {
            print("📱 First run - Setting default AI Classification to OFF")
            UserDefaults.standard.set(false, forKey: "AIDocumentClassificationEnabled")
            UserDefaults.standard.set(Date(), forKey: "AIToggleLastUpdateTime")
        } else {
            let currentValue = UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled")
            print("📱 App startup - Current AI Classification setting: \(currentValue)")
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
        
        print("📝 Configuring logging - CloudKit: \(cloudKitLevel), CoreData: \(coreDataLevel), SQL: \(sqlLevel)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(subscriptionManager)
                .environmentObject(navigationManager)
                .environmentObject(authViewModel)
                .onAppear {
                    ensureLearningDataLoaded()
                }
        }
    }
    
    func ensureLearningDataLoaded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AdaptiveLearningClassifier.shared.verifyAndFixCoreDataStorage()
            let stats = AdaptiveLearningClassifier.shared.getLearningStatistics()
            print("🚀 App launched with \(stats.totalExamples) learning examples")
        }
    }
} 
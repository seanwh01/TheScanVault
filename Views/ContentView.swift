import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var persistenceController: PersistenceController
    @EnvironmentObject private var appServices: AppServices
    @State private var selectedTab: Tab = .scan
    @State private var navigateToDocumentEdit: String? = nil
    
    enum Tab {
        case scan, vault, aiResearch, settings
    }
    
    var body: some View {
        if authViewModel.isAuthenticated {
            TabView(selection: $selectedTab) {
                ScanView(
                    appServices: appServices,
                    subscriptionManager: subscriptionManager
                )
                    .tabItem {
                        Label("Scan", systemImage: "doc.text.viewfinder")
                    }
                    .tag(Tab.scan)
                
                VaultView(persistenceController: persistenceController)
                    .tabItem {
                        Label("Vault", systemImage: "folder")
                    }
                    .tag(Tab.vault)
                
                AIResearchView(persistenceController: persistenceController)
                    .tabItem {
                        Label("AI Research", systemImage: "brain")
                    }
                    .tag(Tab.aiResearch)
                
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    Views_Settings.SettingsView()
                        .environmentObject(authViewModel)
                        .environmentObject(subscriptionManager)
                        .environment(\.colorScheme, .dark)
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToDocumentEdit"))) { notification in
                if let documentId = notification.userInfo?["documentId"] as? String {
                    navigateToDocumentEdit = documentId
                    
                    selectedTab = .vault
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToVault"))) { _ in
                selectedTab = .vault
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToSettings"))) { _ in
                selectedTab = .settings
            }
        } else {
            LoginView()
        }
    }
}
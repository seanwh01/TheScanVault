import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedTab: Tab = .scan
    @State private var navigateToDocumentEdit: String? = nil
    
    enum Tab {
        case scan, vault, aiResearch, settings
    }
    
    var body: some View {
        if authViewModel.isAuthenticated {
            TabView(selection: $selectedTab) {
                ScanView()
                    .tabItem {
                        Label("Scan", systemImage: "doc.text.viewfinder")
                    }
                    .tag(Tab.scan)
                
                VaultView()
                    .tabItem {
                        Label("Vault", systemImage: "folder")
                    }
                    .tag(Tab.vault)
                
                AIResearchView()
                    .tabItem {
                        Label("AI Research", systemImage: "brain")
                    }
                    .tag(Tab.aiResearch)
                
                // Use the Views_Settings namespace for SettingsView
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
            // Handle navigation changes through NotificationCenter
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToDocumentEdit"))) { notification in
                if let documentId = notification.userInfo?["documentId"] as? String {
                    // Set the document ID to edit
                    navigateToDocumentEdit = documentId
                    
                    // Switch to the vault tab
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
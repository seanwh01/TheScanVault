import SwiftUI
import Security
import CoreData

// IMPORTANT TEMPORARY FIX: We've refactored this file into multiple smaller components
// located in the Views/Settings directory. To prevent build errors from duplicate 
// symbols, we've temporarily replaced the content of this file with this message.
//
// To properly fix:
// 1. Open the Xcode project
// 2. Add the Views/Settings directory to the project if not already added
// 3. Make sure all files in Views/Settings are included in the build target
// 4. Then replace this placeholder with proper implementation that uses the new components

// This is a proxy implementation that forwards to the refactored SettingsView
// We're using a different styling approach (dark mode) now
struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    var body: some View {
        ZStack {
            // Add dark background for consistent styling
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Use the refactored view from the Settings directory
            Views_Settings.SettingsView()
                .environmentObject(authViewModel)
                .environmentObject(subscriptionManager)
                .environment(\.colorScheme, .dark) // Ensure dark mode is applied
        }
    }
}

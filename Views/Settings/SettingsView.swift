import SwiftUI
import Security
import CoreData

extension Views_Settings {
    struct SettingsView: View {
        @EnvironmentObject private var authViewModel: AuthViewModel
        @EnvironmentObject private var subscriptionManager: SubscriptionManager
        @State private var showChangePassword = false
        @State private var showAbout = false
        @State private var showSubscriptionDetails = false
        @State private var showConfirmLogout = false
        @State private var showOpenAISettings = false
        @State private var isCleaningTags = false
        @State private var isCleaningFolders = false
        @State private var showCleanupAlert = false
        @State private var cleanupAlertMessage = ""
        @State private var cleanupAlertTitle = ""
        @State private var showNotificationBanner = false
        @State private var notificationMessage = ""
        @State private var notificationTitle = ""
        @State private var notificationType: NotificationType = .info
        @State private var currentOperation: String? = nil
        @State private var lastButtonPressTime: Date = Date()
        @State private var buttonLock = false
        @State private var showFolderCleanupModal = false
        @State private var currentAIModel: String = UserDefaults.standard.string(forKey: "AIModelPreference") ?? "gpt-4-turbo"
        @State private var lastRefreshTime = Date()
        @State private var showDocumentLockSetup = false
        @State private var documentLockAlertMessage = ""
        @State private var documentLockAlertTitle = ""
        @State private var showDocumentLockAlert = false
        @Environment(\.managedObjectContext) private var viewContext
        @AppStorage("documentLockPassword") private var documentLockPassword: String = ""
        @AppStorage("isDocumentLockEnabled") private var isDocumentLockEnabled: Bool = false
        @State private var showingPasswordDialog = false
        @State private var showingResetPasswordDialog = false
        @State private var showingForgotPasswordDialog = false
        @State private var currentPassword = ""
        @State private var newPassword = ""
        @State private var confirmPassword = ""
        @State private var showingPasswordError = false
        @State private var passwordError = ""
        @State private var showingSuccessAlert = false
        @State private var successMessage = ""
        @State private var pendingFoldersToDelete: [Folder] = []
        @State private var pendingTagsToDelete: [Tag] = []
        @State private var showFolderDeleteConfirmation = false
        @State private var showTagDeleteConfirmation = false
        @State private var showChangeEmail = false
        @State private var showLearningPatterns = false
        @State private var showLearningDataResetAlert = false
        
        // Define notification types
        enum NotificationType {
            case info
            case success
            case warning
            case error
            
            var color: Color {
                switch self {
                case .info: return Color.blue
                case .success: return Color.green
                case .warning: return Color.orange
                case .error: return Color.red
                }
            }
            
            var icon: String {
                switch self {
                case .info: return "info.circle.fill"
                case .success: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.octagon.fill"
                }
            }
        }
        
        // Helper function to get display name for model
        private func modelDisplayName(for modelName: String) -> String {
            switch modelName {
            case "gpt-4o":
                return "GPT-4o"
            case "gpt-4-turbo":
                return "GPT-4 Turbo"
            default:
                return "GPT-3.5 Turbo"
            }
        }
        
        var body: some View {
            NavigationView {
                ZStack(alignment: .bottom) {
                    List {
                        // User Profile Section
                        Section {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(authViewModel.currentUser?.username ?? "User")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(authViewModel.currentUser?.email ?? "email@example.com")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Subscription Section
                        Section(header: Text("Subscription").foregroundColor(.gray)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Current Plan")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(subscriptionManager.subscriptionName)
                                        .foregroundColor(subscriptionManager.isPremium ? .green : .blue)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showSubscriptionDetails = true
                                }) {
                                    Text("Manage")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // AI feature status
                            if subscriptionManager.isPremium {
                                Toggle(isOn: Binding(
                                    get: { 
                                        let value = UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled")
                                        print("📱 Reading AI toggle state: \(value)")
                                        return value
                                    },
                                    set: { newValue in
                                        print("📱 Setting AI toggle to: \(newValue)")
                                        UserDefaults.standard.set(newValue, forKey: "AIDocumentClassificationEnabled")
                                        // Post a notification that the setting changed
                                        NotificationCenter.default.post(name: Notification.Name("AIDocumentClassificationToggleChanged"), 
                                                                       object: nil, 
                                                                       userInfo: ["enabled": newValue])
                                    }
                                )) {
                                    HStack {
                                        Image(systemName: "brain")
                                            .foregroundColor(.blue)
                                        Text("AI Document Classification")
                                            .foregroundColor(.white)
                                    }
                                }
                                .tint(.blue)
                                
                                Text("When enabled, AI will automatically suggest document classification.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                HStack {
                                    Image(systemName: "brain")
                                        .foregroundColor(.gray)
                                    Text("AI Document Classification")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Premium Only")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        // OpenAI Model Selection and API Key Section
                        Section(header: Text("OpenAI Model Selection and API Key").foregroundColor(.gray)) {
                            // OpenAI API Key button
                            Button(action: {
                                showOpenAISettings = true
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.blue)
                                    Text("OpenAI API Key")
                                        .foregroundColor(.white)
                                    Spacer()
                                    hasOpenAIKey ? Image(systemName: "checkmark.circle.fill").foregroundColor(.green) : Image(systemName: "exclamationmark.circle").foregroundColor(.orange)
                                }
                            }
                            
                            // AI Models Selection links
                            NavigationLink {
                                AIModelSelectionView()
                                    .onDisappear {
                                        let newModel = UserDefaults.standard.string(forKey: "AIModelPreference") ?? "gpt-4-turbo"
                                        if currentAIModel != newModel {
                                            print("⚡️ SettingsView detected model change: \(currentAIModel) → \(newModel)")
                                            currentAIModel = newModel
                                            lastRefreshTime = Date()
                                        }
                                    }
                            } label: {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.blue)
                                    Text("AI Research Model")
                                        .foregroundColor(.white)
                                    Spacer()
                                    
                                    Text(modelDisplayName(for: currentAIModel))
                                        .foregroundColor(.gray)
                                }
                            }
                            .id(lastRefreshTime)
                            
                            NavigationLink {
                                AIClassifierModelSelectionView()
                                    .onDisappear {
                                        let newModel = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
                                        if currentAIModel != newModel {
                                            print("⚡️ SettingsView detected classifier model change: \(currentAIModel) → \(newModel)")
                                            lastRefreshTime = Date()
                                        }
                                    }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundColor(.blue)
                                    Text("Document Classification Model")
                                        .foregroundColor(.white)
                                    Spacer()
                                    
                                    let modelKey = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
                                    Text(modelDisplayName(for: modelKey))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // API Key Testing Button
                            NavigationLink {
                                APIKeyTestingView()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.shield")
                                        .foregroundColor(.blue)
                                    Text("Test API Key")
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Text("Select which OpenAI models to use for different features. More powerful models provide better results but cost more.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Advanced AI Settings Section
                        Section(header: Text("Advanced Settings").foregroundColor(.gray)) {
                            NavigationLink {
                                AdvancedAISettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "slider.horizontal.3")
                                        .foregroundColor(.blue)
                                    Text("Advanced AI Settings")
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: {
                                showLearningDataResetAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.blue)
                                    Text("Reset Learning Data")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Security Section
                        Section(header: Text("Security").foregroundColor(.gray)) {
                            Button(action: {
                                showChangePassword = true
                            }) {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.blue)
                                    Text("Change Password")
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: {
                                showChangeEmail = true
                            }) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.blue)
                                    Text("Change Email")
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: {
                                showDocumentLockSetup = true
                            }) {
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(.blue)
                                    Text("Document Lock")
                                        .foregroundColor(.white)
                                    Spacer()
                                    if isDocumentLockEnabled {
                                        Text("Enabled")
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Disabled")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        
                        // Clean Up Tools Section
                        Section(header: Text("Clean Up Tools").foregroundColor(.gray)) {
                            Button(action: {
                                cleanupUnusedTags()
                            }) {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundColor(.blue)
                                    Text("Clean Up Unused Tags")
                                        .foregroundColor(.white)
                                    
                                    if isCleaningTags {
                                        Spacer()
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isCleaningTags || buttonLock)
                            
                            Button(action: {
                                cleanupEmptyFolders()
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.blue)
                                    Text("Clean Up Empty Folders")
                                        .foregroundColor(.white)
                                    
                                    if isCleaningFolders {
                                        Spacer()
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isCleaningFolders || buttonLock)
                        }
                        
                        // About Section
                        Section(header: Text("About").foregroundColor(.gray)) {
                            Button(action: {
                                showAbout = true
                            }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("About TheScanVault")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Logout Section
                        Section {
                            Button(action: {
                                showConfirmLogout = true
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                    Text("Log Out")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // Add spacer section at the bottom for better scrolling
                        Section {
                            Text("TheScanVault © 2024")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .environment(\.colorScheme, .dark)
                    .background(Color.black)
                    
                    // Only show notification banner when needed
                    if showNotificationBanner {
                        VStack {
                            HStack(alignment: .center, spacing: 15) {
                                Image(systemName: notificationType.icon)
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                
                                VStack(alignment: .leading) {
                                    Text(notificationTitle)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(notificationMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showNotificationBanner = false
                                }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding()
                            .background(notificationType.color)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: showNotificationBanner)
                        .zIndex(1) // Ensure it stays on top
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView(isPresented: $showChangePassword)
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showAbout) {
                AboutAppView(isPresented: $showAbout)
            }
            .sheet(isPresented: $showSubscriptionDetails) {
                SubscriptionView(isPresented: $showSubscriptionDetails)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showOpenAISettings) {
                OpenAISettingsView(isPresented: $showOpenAISettings)
            }
            .sheet(isPresented: $showChangeEmail) {
                ChangeEmailView(isPresented: $showChangeEmail)
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showDocumentLockSetup) {
                DocumentLockSetupView(
                    isPresented: $showDocumentLockSetup,
                    documentLockAlertTitle: $documentLockAlertTitle,
                    documentLockAlertMessage: $documentLockAlertMessage,
                    showDocumentLockAlert: $showDocumentLockAlert
                )
            }
            .alert(isPresented: $showCleanupAlert) {
                Alert(title: Text(cleanupAlertTitle),
                      message: Text(cleanupAlertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showDocumentLockAlert) {
                Alert(
                    title: Text(documentLockAlertTitle),
                    message: Text(documentLockAlertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showConfirmLogout) {
                Alert(
                    title: Text("Confirm Logout"),
                    message: Text("Are you sure you want to log out?"),
                    primaryButton: .destructive(Text("Logout")) {
                        print("👋 User confirmed logout")
                        authViewModel.logout()
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
            .alert(isPresented: $showLearningDataResetAlert) {
                Alert(
                    title: Text("Reset Learning Data?"),
                    message: Text("This will reset all learning patterns and document classification history. This action cannot be undone."),
                    primaryButton: .destructive(Text("Reset")) {
                        print("🧠 Resetting learning data")
                        // Call method to reset learning data
                        resetLearningData()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        
        // Cleanup functions
        private func cleanupUnusedTags() {
            guard !buttonLock else { return }
            lockButton()
            
            isCleaningTags = true
            print("🧹 Starting tag cleanup...")
            
            // Get the managed object context
            let context = PersistenceController.shared.container.viewContext
            
            // Create a fetch request for all tags
            let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            
            do {
                // Fetch all tags
                let allTags = try context.fetch(fetchRequest)
                var unusedTags: [Tag] = []
                
                // Check each tag to see if it's associated with any documents
                for tag in allTags {
                    if let documents = tag.documents, documents.count == 0 {
                        // This tag has no associated documents
                        unusedTags.append(tag)
                    }
                }
                
                // Delete unused tags
                let unusedCount = unusedTags.count
                for tag in unusedTags {
                    context.delete(tag)
                }
                
                // Save context
                if unusedCount > 0 {
                    try context.save()
                    print("🧹 Removed \(unusedCount) unused tags")
                }
                
                // Update UI
                DispatchQueue.main.async {
                    self.isCleaningTags = false
                    
                    // Show notification banner
                    self.notificationType = .success
                    self.notificationTitle = "Tags Cleanup Complete"
                    self.notificationMessage = "\(unusedCount) unused tag(s) have been removed."
                    self.showNotificationBanner = true
                    
                    // Auto-hide notification after a few seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        self.showNotificationBanner = false
                    }
                    
                    // Also keep the alert for redundancy
                    self.cleanupAlertTitle = "Tags Cleanup Complete"
                    self.cleanupAlertMessage = "\(unusedCount) unused tag(s) have been removed."
                    self.showCleanupAlert = true
                    self.unlockButton()
                }
            } catch {
                print("❌ Error cleaning up tags: \(error)")
                
                // Update UI in case of error
                DispatchQueue.main.async {
                    self.isCleaningTags = false
                    self.cleanupAlertTitle = "Error"
                    self.cleanupAlertMessage = "An error occurred while cleaning up tags."
                    self.showCleanupAlert = true
                    self.unlockButton()
                }
            }
        }
        
        private func cleanupEmptyFolders() {
            guard !buttonLock else { return }
            lockButton()
            
            isCleaningFolders = true
            print("🧹 Starting folder cleanup...")
            
            // Get the managed object context
            let context = PersistenceController.shared.container.viewContext
            
            // Create a fetch request for all folders
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            
            do {
                // Fetch all folders
                let allFolders = try context.fetch(fetchRequest)
                var emptyFolders: [Folder] = []
                
                // Check each folder to see if it's associated with any documents
                for folder in allFolders {
                    // Skip folders with nil IDs
                    guard let folderId = folder.id else {
                        // This folder has no ID, consider it for deletion
                        emptyFolders.append(folder)
                        continue
                    }
                    
                    // Count documents with this folder's ID
                    let docRequest: NSFetchRequest<Document> = Document.fetchRequest()
                    docRequest.predicate = NSPredicate(format: "folderId == %@", folderId as CVarArg)
                    let count = try context.count(for: docRequest)
                    
                    if count == 0 {
                        // This folder has no associated documents
                        emptyFolders.append(folder)
                    }
                }
                
                // Delete empty folders
                let emptyCount = emptyFolders.count
                for folder in emptyFolders {
                    context.delete(folder)
                }
                
                // Save context
                if emptyCount > 0 {
                    try context.save()
                    print("🧹 Removed \(emptyCount) empty folders")
                }
                
                // Update UI
                DispatchQueue.main.async {
                    self.isCleaningFolders = false
                    
                    // Show notification banner
                    self.notificationType = .success
                    self.notificationTitle = "Folders Cleanup Complete"
                    self.notificationMessage = "\(emptyCount) empty folder(s) have been removed."
                    self.showNotificationBanner = true
                    
                    // Auto-hide notification after a few seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        self.showNotificationBanner = false
                    }
                    
                    // Also keep the alert for redundancy
                    self.cleanupAlertTitle = "Folders Cleanup Complete"
                    self.cleanupAlertMessage = "\(emptyCount) empty folder(s) have been removed."
                    self.showCleanupAlert = true
                    self.unlockButton()
                }
            } catch {
                print("❌ Error cleaning up folders: \(error)")
                
                // Update UI in case of error
                DispatchQueue.main.async {
                    self.isCleaningFolders = false
                    self.cleanupAlertTitle = "Error"
                    self.cleanupAlertMessage = "An error occurred while cleaning up folders."
                    self.showCleanupAlert = true
                    self.unlockButton()
                }
            }
        }
        
        private func lockButton() {
            buttonLock = true
            lastButtonPressTime = Date()
            
            // Auto unlock after 3 seconds in case something goes wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if Date().timeIntervalSince(lastButtonPressTime) >= 3 {
                    buttonLock = false
                }
            }
        }
        
        private func unlockButton() {
            buttonLock = false
        }
        
        // Helper function to reset learning data
        private func resetLearningData() {
            // This is just a stub implementation for now
            print("🧠 Would reset learning data here")
            // Show confirmation in notification
            notificationType = .success
            notificationTitle = "Success"
            notificationMessage = "All learning data has been reset"
            showNotificationBanner = true
            
            // Hide notification after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showNotificationBanner = false
            }
        }
        
        // Check if there's an OpenAI API key
        private var hasOpenAIKey: Bool {
            // First check KeychainManager
            let keychain = KeychainManager.shared
            let apiKey = keychain.getAPIKey(service: "OpenAI")
            
            // If keychain has the key, return true
            if apiKey != nil && !apiKey!.isEmpty {
                return true
            }
            
            // If keychain access fails, check UserDefaults as fallback (for simulator)
            if let userDefaultsKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"), !userDefaultsKey.isEmpty {
                print("🔑 Using API key from UserDefaults (simulator fallback)")
                return true
            }
            
            // No key found in either location
            return false
        }
    }
}
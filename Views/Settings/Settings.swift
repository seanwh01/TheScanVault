import SwiftUI

// Define a namespace for all Settings components
// This helps avoid naming conflicts with existing components
enum Settings {
    /// The main SettingsView that serves as the container
    typealias SettingsView = Views_Settings.SettingsView
    
    /// Change Password View
    typealias ChangePasswordView = Views_Settings.ChangePasswordView
    
    /// Change Email View
    typealias ChangeEmailView = Views_Settings.ChangeEmailView
    
    /// OpenAI Settings View
    typealias OpenAISettingsView = Views_Settings.OpenAISettingsView
    
    /// Subscription View
    typealias SubscriptionView = Views_Settings.SubscriptionView
    
    /// Advanced AI Settings View
    typealias AdvancedAISettingsView = Views_Settings.AdvancedAISettingsView
    
    /// AI Model Selection View
    typealias AIModelSelectionView = Views_Settings.AIModelSelectionView
    
    /// Document Lock Setup View
    typealias DocumentLockSetupView = Views_Settings.DocumentLockSetupView
    
    /// About App View
    typealias AboutAppView = Views_Settings.AboutAppView
}

// All views in this module belong to this namespace
// This helps avoid naming conflicts with existing views
enum Views_Settings {} 
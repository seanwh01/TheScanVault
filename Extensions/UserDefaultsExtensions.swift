import Foundation

// Extensions to add helper properties for UserDefaults
extension UserDefaults {
    /// Checks if AI document classification is enabled in the app settings
    static var isAIDocumentClassificationEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled")
    }
    
    /// Sets the AI document classification enabled status
    static func setAIDocumentClassificationEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "AIDocumentClassificationEnabled")
        // Post notification for observers
        NotificationCenter.default.post(
            name: Notification.Name("AIDocumentClassificationToggleChanged"),
            object: nil,
            userInfo: ["enabled": value]
        )
    }
    
    /// Gets the currently selected AI model from user preferences
    /// This handles both possible keys used in the app: "AIModelPreference" (standard) and "AI Classifier Model" (legacy)
    static var selectedAIModel: String {
        // Check the standard key first
        if let model = UserDefaults.standard.string(forKey: "AIModelPreference") {
            return model
        }
        // Fall back to legacy key if needed
        return UserDefaults.standard.string(forKey: "AI Classifier Model") ?? "gpt-4-turbo"
    }
    
    /// Sets the selected AI model
    static func setSelectedAIModel(_ modelName: String) {
        // Save to the standard key
        UserDefaults.standard.set(modelName, forKey: "AIModelPreference")
        
        // For backwards compatibility, also save to the legacy key
        UserDefaults.standard.set(modelName, forKey: "AI Classifier Model")
        
        // Post notification for observers
        NotificationCenter.default.post(
            name: Notification.Name("AIModelChanged"),
            object: nil,
            userInfo: ["model": modelName]
        )
    }
} 
import SwiftUI

extension Views_Settings {
    struct AdvancedAISettingsView: View {
        @Environment(\.presentationMode) var presentationMode
        @AppStorage("aiTemperature") private var aiTemperature: Double = 0.7
        @AppStorage("aiMaxTokens") private var aiMaxTokens: Double = 1000
        @AppStorage("aiClassifierPrecision") private var aiClassifierPrecision: Double = 0.8
        @AppStorage("aiUseAutoClassification") private var aiUseAutoClassification: Bool = true
        @AppStorage("aiUseContextAwareness") private var aiUseContextAwareness: Bool = true
        @AppStorage("aiUseBatchProcessing") private var aiUseBatchProcessing: Bool = false
        @State private var showingResetConfirmation = false
        
        var body: some View {
            Form {
                Section(header: Text("AI Model Parameters").foregroundColor(.gray)) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Temperature")
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f", aiTemperature))
                                .foregroundColor(.gray)
                        }
                        
                        Slider(value: $aiTemperature, in: 0...1, step: 0.1)
                            .tint(.blue)
                        
                        Text("Controls creativity. Lower values are more deterministic, higher values are more creative.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Max Tokens")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(aiMaxTokens))")
                                .foregroundColor(.gray)
                        }
                        
                        Slider(value: $aiMaxTokens, in: 100...2000, step: 100)
                            .tint(.blue)
                        
                        Text("Maximum number of tokens (words) for AI responses. Higher values allow more detailed responses but cost more.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Classifier Precision")
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f", aiClassifierPrecision))
                                .foregroundColor(.gray)
                        }
                        
                        Slider(value: $aiClassifierPrecision, in: 0.5...0.9, step: 0.1)
                            .tint(.blue)
                        
                        Text("Controls how confident the AI must be to apply a classification. Higher values require more confidence.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("AI Behavior").foregroundColor(.gray)) {
                    Toggle(isOn: $aiUseAutoClassification) {
                        VStack(alignment: .leading) {
                            Text("Automatic Classification")
                                .foregroundColor(.white)
                            Text("Automatically classify documents when added")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: $aiUseContextAwareness) {
                        VStack(alignment: .leading) {
                            Text("Context Awareness")
                                .foregroundColor(.white)
                            Text("Use previously classified documents to improve accuracy")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: $aiUseBatchProcessing) {
                        VStack(alignment: .leading) {
                            Text("Batch Processing")
                                .foregroundColor(.white)
                            Text("Process multiple documents in a single AI call to reduce costs")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.blue)
                }
                
                Section {
                    Button(action: { showingResetConfirmation = true }) {
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("About Advanced AI Settings").foregroundColor(.gray)) {
                    Text("These settings allow fine-tuning of the AI document classification system. Default values work well for most users, but advanced users may adjust these for specific document types or classification needs.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .environment(\.colorScheme, .dark)
            .background(Color.black)
            .navigationTitle("Advanced AI Settings")
            .alert("Reset Settings", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { resetToDefaults() }
            } message: {
                Text("This will reset all advanced AI settings to their default values. This action cannot be undone.")
            }
        }
        
        private func resetToDefaults() {
            aiTemperature = 0.7
            aiMaxTokens = 1000
            aiClassifierPrecision = 0.8
            aiUseAutoClassification = true
            aiUseContextAwareness = true
            aiUseBatchProcessing = false
        }
    }
}

// MARK: - AI Status Section View
struct AIStatusSectionView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        Section(header: Text("AI Status")) {
            HStack {
                Text("AI Classification")
                Spacer()
                Text(UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") ? "Enabled" : "Disabled")
                    .foregroundColor(UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") ? .green : .gray)
            }
            
            HStack {
                Text("Current AI Model")
                Spacer()
                let model = UserDefaults.standard.string(forKey: "AIModelPreference") ?? "gpt-4-turbo"
                Text(modelDisplayName(for: model))
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Current Classifier Model")
                Spacer()
                let model = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
                Text(modelDisplayName(for: model))
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("API Key Status")
                Spacer()
                if let keychainKey = KeychainManager.shared.getAPIKey(service: "OpenAI", account: "DocumentClassification"),
                   !keychainKey.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Configured")
                        .foregroundColor(.green)
                } else if let userDefaultsKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"),
                          !userDefaultsKey.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Configured (UserDefaults)")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Not Configured")
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Text("Subscription Status")
                Spacer()
                if subscriptionManager.isPremium {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Premium")
                        .foregroundColor(.green)
                } else {
                    Text("Basic")
                        .foregroundColor(.blue)
                }
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
        case "gpt-3.5-turbo-0125":
            return "GPT-3.5 Turbo"
        default:
            return modelName
        }
    }
}

// MARK: - AI Testing Section View
struct AITestingSectionView: View {
    @State private var showingAPIKeyTest = false
    
    var body: some View {
        Section(header: Text("AI Testing")) {
            NavigationLink(destination: AIResearchView()) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                    Text("AI Document Research")
                }
            }
            
            NavigationLink(destination: APIKeyTestingView()) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                    Text("Test OpenAI API Key")
                }
            }
        }
    }
} 
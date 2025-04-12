import SwiftUI

// Inline implementation of model preference to avoid dependency issues
private class ModelPreference {
    static let shared = ModelPreference()
    
    // Ensure consistent key name across the app
    private let modelPreferenceKey = "AIModelPreference"
    
    struct Models {
        static let gpt35Turbo = "gpt-3.5-turbo-0125"
        static let gpt4o = "gpt-4o"
        static let gpt4Turbo = "gpt-4-turbo"
        
        static let allModels = [gpt35Turbo, gpt4o, gpt4Turbo]
        
        static func displayName(for model: String) -> String {
            switch model {
            case gpt35Turbo: return "GPT-3.5 Turbo (Faster, Lower Cost)"
            case gpt4Turbo: return "GPT-4 Turbo (Highest Quality, Higher Cost)"
            case gpt4o: return "GPT-4o (High Quality, Moderate Cost)"
            default: return model
            }
        }
        
        static func costInfo(for model: String) -> String {
            switch model {
            case gpt35Turbo:
                return "Input: $0.50/million tokens, Output: $1.50/million tokens"
            case gpt4Turbo:
                return "Input: $10.00/million tokens, Output: $30.00/million tokens"
            case gpt4o:
                return "Input: $2.50/million tokens, Output: $10.00/million tokens"
            default:
                return "Cost information unavailable"
            }
        }
    }
    
    var currentModel: String {
        get {
            let model = UserDefaults.standard.string(forKey: modelPreferenceKey) ?? Models.gpt4Turbo
            print("📱 Reading model preference: \(model)")
            return model
        }
        set {
            print("💾 Saving new model preference: \(newValue)")
            UserDefaults.standard.set(newValue, forKey: modelPreferenceKey)
            // Force UserDefaults to synchronize immediately
            UserDefaults.standard.synchronize()
        }
    }
}

struct AIModelSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedModel: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Select AI Model")) {
                ForEach(ModelPreference.Models.allModels, id: \.self) { model in
                    Button(action: {
                        // Save the selection
                        selectedModel = model
                        ModelPreference.shared.currentModel = model
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ModelPreference.Models.displayName(for: model))
                                    .font(.headline)
                                Text(ModelPreference.Models.costInfo(for: model))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if selectedModel == model {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Section(header: Text("About These Models")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("GPT-3.5 Turbo")
                        .font(.headline)
                    Text("A good balance of performance and cost. Recommended for most document classification tasks.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("GPT-4o")
                        .font(.headline)
                    Text("OpenAI's recommended model with excellent understanding and reasoning at a moderate cost. This balances cost and quality well.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("GPT-4 Turbo")
                        .font(.headline)
                    Text("More advanced model with significantly better understanding of complex documents. Higher cost but better quality results.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("AI Model Selection")
        .navigationBarItems(trailing: Button("Done") {
            presentationMode.wrappedValue.dismiss()
        })
        .onAppear {
            // CRITICAL: Always refresh selectedModel from UserDefaults
            let storedModel = UserDefaults.standard.string(forKey: "AIModelPreference") ?? ModelPreference.Models.gpt4Turbo
            print("📱 AIModelSelectionView appeared, UserDefaults value: \(storedModel)")
            
            // Update the selectedModel state to match UserDefaults
            if selectedModel != storedModel {
                print("🔄 Updating selectedModel from \(selectedModel) to \(storedModel)")
                selectedModel = storedModel
            }
            
            print("📱 Current UserDefaults value: \(UserDefaults.standard.string(forKey: "AIModelPreference") ?? "nil")")
        }
    }
} 
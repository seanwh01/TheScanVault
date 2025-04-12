import SwiftUI

extension Views_Settings {
    struct AIModelSelectionView: View {
        @Environment(\.presentationMode) var presentationMode
        @AppStorage("AIModelPreference") private var selectedModel: String = UserDefaults.standard.string(forKey: "AIModelPreference") ?? "gpt-4-turbo"
        
        // Define the available models
        let availableModels = [
            "claude-3-5-sonnet",
            "gpt-3.5-turbo-0125",
            "gpt-4o",
            "gpt-4-turbo"
        ]
        
        var body: some View {
            Form {
                Section(header: Text("AI Model").foregroundColor(.gray)) {
                    ForEach(availableModels, id: \.self) { model in
                        Button(action: {
                            selectedModel = model
                            UserDefaults.standard.set(model, forKey: "AIModelPreference")
                            print("🔄 Changed AI model to: \(model)")
                        }) {
                            HStack {
                                Text(displayName(for: model))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if model == selectedModel {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("Model Information").foregroundColor(.gray), footer: Text("More powerful models provide better results but cost more per API call.").foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Claude 3.5 Sonnet")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Most economical option from Anthropic. Great for basic tasks with the lowest cost per API call.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GPT-3.5 Turbo")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Lower cost but less powerful model. Good for simpler classification tasks.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GPT-4o")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Advanced multimodal model with strong reasoning capabilities. Good balance of cost and performance.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GPT-4 Turbo")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("The most advanced and powerful model. Highest quality results but also the most expensive option.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .environment(\.colorScheme, .dark)
            .background(Color.black)
            .navigationTitle("AI Model Selection")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        
        // Helper function to get nice display names
        private func displayName(for model: String) -> String {
            switch model {
            case "claude-3-5-sonnet":
                return "Claude 3.5 Sonnet (Most Economical)"
            case "gpt-3.5-turbo-0125":
                return "GPT-3.5 Turbo (Economy)"
            case "gpt-4o":
                return "GPT-4o (Standard)"
            case "gpt-4-turbo":
                return "GPT-4 Turbo (Premium)"
            default:
                return model
            }
        }
    }

    struct AIClassifierModelSelectionView: View {
        @Environment(\.presentationMode) var presentationMode
        @AppStorage("AIClassifierModelPreference") private var selectedModel: String = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
        
        // Define the available models
        let availableModels = [
            "claude-3-5-sonnet",
            "gpt-3.5-turbo-0125",
            "gpt-4o",
            "gpt-4-turbo"
        ]
        
        var body: some View {
            Form {
                Section(header: Text("Document Classification Model").foregroundColor(.gray)) {
                    ForEach(availableModels, id: \.self) { model in
                        Button(action: {
                            selectedModel = model
                            UserDefaults.standard.set(model, forKey: "AIClassifierModelPreference")
                            print("🔄 Changed AI classifier model to: \(model)")
                        }) {
                            HStack {
                                Text(displayName(for: model))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if model == selectedModel {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("Model Information").foregroundColor(.gray), footer: Text("This model is used specifically for document classification.").foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Claude 3.5 Sonnet (Ultra Economy)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Most affordable option from Anthropic. Suitable for basic document classification with minimal cost.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GPT-3.5 Turbo (Economy)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Lower cost but less accurate. Good for simple document classification where basic pattern matching is sufficient.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GPT-4o (Standard)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Good balance of accuracy and cost. Recommended for most document types.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GPT-4 Turbo (Premium)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Highest classification accuracy but most expensive. Best for complex documents or when accuracy is critical.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .environment(\.colorScheme, .dark)
            .background(Color.black)
            .navigationTitle("AI Classifier Model")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        
        // Helper function to get nice display names
        private func displayName(for model: String) -> String {
            switch model {
            case "claude-3-5-sonnet":
                return "Claude 3.5 Sonnet (Ultra Economy)"
            case "gpt-3.5-turbo-0125":
                return "GPT-3.5 Turbo (Economy)"
            case "gpt-4o":
                return "GPT-4o (Standard)"
            case "gpt-4-turbo":
                return "GPT-4 Turbo (Premium)"
            default:
                return model
            }
        }
    }
} 
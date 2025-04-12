import SwiftUI

struct APIKeyTestingView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var apiKey = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var hasExistingKey = false
    
    var body: some View {
        Form {
            Section(header: Text("Development Testing Only"), 
                    footer: Text("WARNING: This is a temporary solution for testing only. In production, the API key should be securely stored on a server.")) {
                
                SecureField("OpenAI API Key", text: $apiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button(action: saveApiKey) {
                    Text(hasExistingKey ? "Update API Key" : "Save API Key")
                        .frame(maxWidth: .infinity)
                }
                .disabled(apiKey.isEmpty)
                
                if hasExistingKey {
                    Button(action: removeApiKey) {
                        Text("Remove API Key")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Section(header: Text("Test Connection")) {
                Button(action: testConnection) {
                    Text("Test API Connection")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!hasExistingKey && apiKey.isEmpty)
            }
            
            Section(header: Text("Instructions")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. Enter your OpenAI API key")
                    Text("2. Test the connection to verify it works")
                    Text("3. Scan a document to use AI classification")
                    Text("4. Remove the key when you're done testing")
                }
                .font(.callout)
            }
        }
        .navigationTitle("API Key Testing")
        .onAppear(perform: checkForExistingKey)
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("API Key"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func checkForExistingKey() {
        if let existingKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey"), !existingKey.isEmpty {
            hasExistingKey = true
            apiKey = "••••••••••••••••••" // Mask the actual key
        } else {
            hasExistingKey = false
            apiKey = ""
        }
    }
    
    private func saveApiKey() {
        // Save to UserDefaults for the AI Research feature
        UserDefaults.standard.set(apiKey, forKey: "OpenAIAPIKey")
        
        // Also save to Keychain for document detail view queries
        let _ = KeychainManager.shared.saveAPIKey(key: apiKey, service: "OpenAI", account: "DocumentClassification")
        print("🔑 API key saved to both UserDefaults and Keychain for consistency")
        
        hasExistingKey = true
        apiKey = "••••••••••••••••••" // Mask the key after saving
        alertMessage = "API key saved successfully"
        showingAlert = true
    }
    
    private func removeApiKey() {
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: "OpenAIAPIKey")
        
        // Remove from Keychain as well
        let _ = KeychainManager.shared.deleteAPIKey(service: "OpenAI", account: "DocumentClassification")
        print("🔑 API key removed from both UserDefaults and Keychain")
        
        hasExistingKey = false
        apiKey = ""
        alertMessage = "API key removed"
        showingAlert = true
    }
    
    private func testConnection() {
        let testKey = apiKey.isEmpty ? UserDefaults.standard.string(forKey: "OpenAIAPIKey") : apiKey
        
        guard let key = testKey, !key.isEmpty else {
            alertMessage = "No API key available to test"
            showingAlert = true
            return
        }
        
        // Create a simple request to test the API key
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        alertMessage = "Connection successful! API key is valid."
                    } else {
                        alertMessage = "Connection failed with status code: \(httpResponse.statusCode)"
                    }
                } else if let error = error {
                    alertMessage = "Connection error: \(error.localizedDescription)"
                } else {
                    alertMessage = "Unknown connection error"
                }
                showingAlert = true
            }
        }.resume()
    }
} 
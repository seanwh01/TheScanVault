import SwiftUI

extension Views_Settings {
    struct AboutAppView: View {
        @Binding var isPresented: Bool
        @Environment(\.presentationMode) var presentationMode
        
        // Get app version from Bundle
        private var appVersion: String {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            return "Version \(version) (\(build))"
        }
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // App icon
                        Image("AppIcon") // Use your app icon asset
                            .resizable()
                            .frame(width: 100, height: 100)
                            .cornerRadius(20)
                            .padding(.top, 30)
                        
                        // App name and version
                        Text("The Scan Vault")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(appVersion)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 15) {
                            InfoSection(title: "About", content: "The Scan Vault is a secure document management application designed to help you organize, classify, and protect your important documents.")
                            
                            InfoSection(title: "Features", content: """
                            • Secure document storage
                            • AI document classification
                            • Document tagging and organization
                            • Advanced search capabilities
                            • Cloud synchronization
                            • Document sharing options
                            """)
                            
                            InfoSection(title: "Privacy", content: "Your data privacy is our priority. All documents are securely stored with encryption, and your data never leaves your device without your explicit consent.")
                            
                            InfoSection(title: "Support", content: "For support inquiries, please contact support@thescanvault.com")
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Copyright
                        Text("© \(Calendar.current.component(.year, from: Date())) The Scan Vault. All rights reserved.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 20)
                    }
                    .padding()
                }
                .background(Color.black)
                .navigationTitle("About")
                .navigationBarItems(trailing: Button("Close") {
                    isPresented = false
                })
            }
            .environment(\.colorScheme, .dark)
        }
    }
    
    // Helper view for displaying info sections
    private struct InfoSection: View {
        var title: String
        var content: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(content)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
        }
    }
} 
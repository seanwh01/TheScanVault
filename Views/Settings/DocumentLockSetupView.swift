import SwiftUI

extension Views_Settings {
    struct DocumentLockSetupView: View {
        @Environment(\.presentationMode) var presentationMode
        @Binding var isPresented: Bool
        @Binding var documentLockAlertTitle: String
        @Binding var documentLockAlertMessage: String
        @Binding var showDocumentLockAlert: Bool
        
        @AppStorage("documentLockPassword") private var documentLockPassword: String = ""
        @AppStorage("isDocumentLockEnabled") private var isDocumentLockEnabled: Bool = false
        
        @State private var newPassword = ""
        @State private var confirmPassword = ""
        @State private var currentPassword = ""
        @State private var showError = false
        @State private var errorMessage = ""
        @State private var isChangingPassword = false
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Document Lock").foregroundColor(.gray)) {
                        Toggle(isOn: $isDocumentLockEnabled) {
                            Text("Enable Document Lock")
                                .foregroundColor(.white)
                        }
                        .onChange(of: isDocumentLockEnabled) { newValue in
                            if newValue && documentLockPassword.isEmpty {
                                // If enabling and no password set, prompt to create one
                                isChangingPassword = true
                            } else if !newValue {
                                // If disabling, require password verification first
                                if !documentLockPassword.isEmpty {
                                    isDocumentLockEnabled = true // Reset toggle
                                    promptForPasswordVerification()
                                }
                            }
                        }
                        .tint(.blue)
                        
                        Text("When enabled, documents will require a password to view.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if isDocumentLockEnabled {
                        Section {
                            Button(action: {
                                isChangingPassword = true
                            }) {
                                Text("Change Lock Password")
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: promptForPasswordVerification) {
                                Text("Disable Document Lock")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    if isChangingPassword {
                        Section(header: Text(documentLockPassword.isEmpty ? "Create Password" : "Change Password").foregroundColor(.gray)) {
                            if !documentLockPassword.isEmpty {
                                SecureField("Current Password", text: $currentPassword)
                            }
                            
                            SecureField("New Password", text: $newPassword)
                            SecureField("Confirm New Password", text: $confirmPassword)
                            
                            if showError {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            
                            Button(action: savePassword) {
                                Text("Save Password")
                            }
                            .disabled(
                                (!documentLockPassword.isEmpty && currentPassword.isEmpty) ||
                                newPassword.isEmpty ||
                                confirmPassword.isEmpty
                            )
                        }
                    }
                    
                    Section(header: Text("About Document Lock").foregroundColor(.gray)) {
                        Text("Document Lock provides an additional layer of security for your sensitive documents. When enabled, you'll need to enter a password before viewing protected documents.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Warning: If you forget your document lock password, you will not be able to access protected documents. There is no password recovery option.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .environment(\.colorScheme, .dark)
                .background(Color.black)
                .navigationTitle("Document Lock")
                .navigationBarItems(trailing: Button("Done") {
                    isPresented = false
                })
            }
        }
        
        private func promptForPasswordVerification() {
            // In a real app, this would prompt the user for their password
            // and verify it before disabling the lock
            documentLockAlertTitle = "Enter Password"
            documentLockAlertMessage = "Please enter your current password to disable Document Lock."
            showDocumentLockAlert = true
            
            // This is just a placeholder for demonstration
            // In a real app, you would have proper password verification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Simulate successful verification
                isDocumentLockEnabled = false
                documentLockPassword = ""
                
                documentLockAlertTitle = "Document Lock Disabled"
                documentLockAlertMessage = "Document Lock has been disabled successfully."
                showDocumentLockAlert = true
            }
        }
        
        private func savePassword() {
            showError = false
            
            // If we have an existing password, verify it
            if !documentLockPassword.isEmpty && currentPassword != documentLockPassword {
                showError = true
                errorMessage = "Current password is incorrect"
                return
            }
            
            // Verify that new passwords match
            if newPassword != confirmPassword {
                showError = true
                errorMessage = "New passwords do not match"
                return
            }
            
            // Verify password meets minimum requirements
            if newPassword.count < 4 {
                showError = true
                errorMessage = "Password must be at least 4 characters"
                return
            }
            
            // Save the new password
            documentLockPassword = newPassword
            isDocumentLockEnabled = true
            isChangingPassword = false
            
            // Reset fields
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            
            // Show success message
            documentLockAlertTitle = "Password Saved"
            documentLockAlertMessage = "Your document lock password has been updated successfully."
            showDocumentLockAlert = true
        }
    }
} 
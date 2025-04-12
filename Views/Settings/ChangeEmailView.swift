import SwiftUI

extension Views_Settings {
    struct ChangeEmailView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject private var authViewModel: AuthViewModel
        @Binding var isPresented: Bool
        
        @State private var currentPassword = ""
        @State private var newEmail = ""
        @State private var confirmEmail = ""
        @State private var showAlert = false
        @State private var alertMessage = ""
        @State private var isSuccess = false
        
        var isFormValid: Bool {
            !currentPassword.isEmpty && !newEmail.isEmpty && newEmail == confirmEmail && newEmail.contains("@")
        }
        
        var body: some View {
            NavigationView {
                Form {
                    // Current email section
                    Section(header: Text("Current Email").foregroundColor(.gray)) {
                        Text(authViewModel.currentUser?.email ?? "email@example.com")
                            .foregroundColor(.white)
                    }
                    
                    // Password verification section
                    Section(header: Text("Password Verification").foregroundColor(.gray)) {
                        SecureField("Current Password", text: $currentPassword)
                            .textContentType(.password)
                    }
                    
                    // New email section
                    Section(header: Text("New Email").foregroundColor(.gray)) {
                        TextField("New Email", text: $newEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                        
                        TextField("Confirm New Email", text: $confirmEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                        
                        if !newEmail.isEmpty && !confirmEmail.isEmpty && newEmail != confirmEmail {
                            Text("Email addresses do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if !newEmail.isEmpty && !newEmail.contains("@") {
                            Text("Please enter a valid email address")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Submit button section
                    Section {
                        Button(action: changeEmail) {
                            Text("Update Email Address")
                        }
                        .disabled(!isFormValid)
                    }
                }
                .environment(\.colorScheme, .dark)
                .background(Color.black)
                .navigationTitle("Change Email")
                .navigationBarItems(trailing: Button("Cancel") {
                    isPresented = false
                })
                .alert(isSuccess ? "Success" : "Error", isPresented: $showAlert) {
                    Button("OK") {
                        if isSuccess {
                            isPresented = false
                        }
                    }
                } message: {
                    Text(alertMessage)
                }
            }
        }
        
        private func changeEmail() {
            // In a real app, this would validate against a server
            // For this example, we'll simulate success
            isSuccess = true
            alertMessage = "Your email address has been successfully updated."
            showAlert = true
        }
    }
} 
import SwiftUI

extension Views_Settings {
    struct ChangePasswordView: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject private var authViewModel: AuthViewModel
        @Binding var isPresented: Bool
        
        @State private var currentPassword = ""
        @State private var newPassword = ""
        @State private var confirmPassword = ""
        @State private var showAlert = false
        @State private var alertMessage = ""
        @State private var isSuccess = false
        
        var isFormValid: Bool {
            !currentPassword.isEmpty && !newPassword.isEmpty && newPassword == confirmPassword && newPassword.count >= 6
        }
        
        var body: some View {
            NavigationView {
                Form {
                    // Add username section at the top
                    Section {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text(authViewModel.currentUser?.username ?? "User")
                                .font(.headline)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section(header: Text("Current Password").foregroundColor(.gray)) {
                        SecureField("Current Password", text: $currentPassword)
                    }
                    
                    Section(header: Text("New Password").foregroundColor(.gray)) {
                        SecureField("New Password", text: $newPassword)
                            .textContentType(.newPassword)
                        SecureField("Confirm New Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                        
                        if !newPassword.isEmpty && newPassword.count < 6 {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword != confirmPassword {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Section {
                        Button(action: changePassword) {
                            Text("Save New Password")
                        }
                        .disabled(!isFormValid)
                    }
                }
                .environment(\.colorScheme, .dark)
                .background(Color.black)
                .navigationTitle("Change Password")
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
        
        private func changePassword() {
            // In a real app, this would validate against a server
            // For this example, we'll simulate success
            isSuccess = true
            alertMessage = "Your password has been successfully updated."
            showAlert = true
        }
    }
} 
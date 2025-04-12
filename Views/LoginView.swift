import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        // Use ScrollView to handle keyboard better
        ScrollView {
            // Use VStack for vertical centering - moved everything higher
            VStack {
                // Reduced top spacing
                Spacer().frame(height: 30) // Reduced from 60 to 30
                
                // Logo - kept same size
                Image("ScanVaultLogoforAppTM")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250)
                    .frame(minHeight: 120) 
                    .padding(.bottom, 30) // Reduced from 40 to 30
                
                // Container for username/password with tighter spacing
                VStack(spacing: 15) {
                    // Username field with dark background
                    TextField("Username", text: $username)
                        .padding()
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    // Password field with dark background
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                
                // Login button - moved closer to fields
                Button(action: {
                    isLoggingIn = true
                    authViewModel.login(username: username, password: password)
                    
                    // Reset loading state after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isLoggingIn = false
                    }
                }) {
                    if isLoggingIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    } else {
                        Text("Log In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                }
                .disabled(username.isEmpty || password.isEmpty || isLoggingIn)
                .padding(.top, 25) // Reduced from 30 to 25
                
                // Add extra space below to push everything up
                Spacer().frame(minHeight: 250)
            }
            .frame(minHeight: UIScreen.main.bounds.height)
        }
        .padding(.horizontal, 20)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        // Dismiss keyboard when tapping outside fields
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

struct RegisterView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var isFormValid: Bool {
        !username.isEmpty && !email.isEmpty && !password.isEmpty && password == confirmPassword
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Security")) {
                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                    
                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: register) {
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Create Account")
                        }
                    }
                    .disabled(!isFormValid || authViewModel.isLoading)
                }
                
                if let errorMessage = authViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Register")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func register() {
        authViewModel.register(username: username, email: email, password: password)
        presentationMode.wrappedValue.dismiss()
    }
}

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var resetSent = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter your email")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button(action: resetPassword) {
                        if authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Reset Password")
                        }
                    }
                    .disabled(email.isEmpty || authViewModel.isLoading || resetSent)
                }
                
                if resetSent {
                    Section {
                        Text("Password reset instructions have been sent to your email.")
                            .foregroundColor(.green)
                    }
                }
                
                if let errorMessage = authViewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func resetPassword() {
        authViewModel.forgotPassword(email: email)
        resetSent = true
    }
} 
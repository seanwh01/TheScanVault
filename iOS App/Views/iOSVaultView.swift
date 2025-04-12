import SwiftUI

// iOS App-specific version
struct iOSVaultView: View {
    @StateObject private var viewModel = VaultViewModel()
    @State private var isShowingFilters = false
    @State private var isShowingSettings = false
    @State private var lockSuccessMessage = ""
    @State private var showLockSuccessAlert = false

    var body: some View {
        NavigationView {
            // Placeholder for the main content view
            Text("Vault View Content")
        }
        .navigationTitle("Scan Vault")
        .toolbar {
            buildNavigationToolbar()
        }
        .alert(isPresented: $showLockSuccessAlert) {
            Alert(title: Text("Success"), message: Text(lockSuccessMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func buildNavigationToolbar() -> some ToolbarContent {
        Group {
            ToolbarItem(placement: .principal) {
                Text("Scan Vault")
                    .font(.headline)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isShowingFilters.toggle()
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.blue)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isShowingSettings.toggle()
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(.blue)
                }
            }
            
            // Add button to refresh document lock states
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    print("🔄 Manually refreshing document lock states...")
                    viewModel.forceRefreshDocumentLockStates()
                    
                    // Show success message
                    lockSuccessMessage = "Refreshing document locks..."
                    showLockSuccessAlert = true
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct iOSVaultView_Previews: PreviewProvider {
    static var previews: some View {
        iOSVaultView()
    }
} 
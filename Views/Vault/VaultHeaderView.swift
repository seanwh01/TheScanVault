import SwiftUI

// Header section with logo and loading indicator
struct VaultHeaderView: View {
    @Binding var hasRefreshed: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            Image("ScanVaultLogoforAppTM")
                .resizable()
                .scaledToFit()
                .frame(width: 160)
                .padding(.top, 20)
            
            Text("Find Documents to View")
                .foregroundColor(.gray)
                .font(.subheadline)
            
            // Add a temporary refresh indicator that auto-hides
            if !hasRefreshed {
                ProgressView("Loading data...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.0)
                    .padding(.top, 4)
                    .onAppear {
                        // Auto-hide after 1.5 seconds regardless of refresh status
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            hasRefreshed = true
                        }
                    }
            }
        }
        .padding(.bottom, 20)
    }
} 
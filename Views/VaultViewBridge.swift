import SwiftUI

// This file provides a bridge to the implementation in the Views_Vault module
// Use TSV_VaultView in place of the original VaultView in your code
struct TSV_VaultView: View {
    var body: some View {
        Views_Vault.VaultView()
    }
} 
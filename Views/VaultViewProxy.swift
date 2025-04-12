import SwiftUI

// This file provides a bridge to the implementation in the Views_Vault module
// Use VaultViewBridge in place of the original VaultView in your code
struct VaultViewBridge: View {
    var body: some View {
        Views_Vault.VaultView()
    }
} 
import SwiftUI

// Apply button
struct ApplyButtonView: View {
    @ObservedObject var viewModel: VaultViewModel
    @Binding var showResults: Bool
    
    var body: some View {
        Button(action: {
            // Clear document list to ensure fresh results
            viewModel.documents = []
            
            // Perform the search with fresh context - using existing viewModel.searchTitle
            viewModel.searchDocumentsWithFreshContext()
            showResults = true
        }) {
            Text("Apply")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 140, height: 50)
                .background(Color.green)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .padding(.bottom, 20)
    }
} 
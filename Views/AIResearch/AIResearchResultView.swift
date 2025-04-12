import SwiftUI
import UIKit

extension Views_AIResearch {
    // AI Research Result View
    struct AIResearchResultView: View {
        let response: String
        let query: String
        @ObservedObject var viewModel: AIResearchViewModel
        @Binding var isPresented: Bool
        var onDismiss: () -> Void
        
        @State private var showShareSheet = false
        @State private var showCopyConfirmation = false
        
        var body: some View {
            NavigationView {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Model info
                            if let model = viewModel.modelUsed {
                                Text("Analyzed using \(model)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                            }
                            
                            // Query section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Query:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(query)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(12)
                            }
                            
                            // Response section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Response:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(LocalizedStringKey(response))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                    .textSelection(.enabled)
                            }
                            
                            // API Usage Section
                            if let usage = viewModel.lastUsage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("API Usage")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Divider()
                                        .background(Color.gray.opacity(0.5))
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Total: \(usage.totalTokens) tokens")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Text("Prompt: \(usage.promptTokens) | Completion: \(usage.completionTokens)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            // Add model information here
                                            if let model = usage.modelUsed ?? viewModel.modelUsed {
                                                Text("Model: \(model)")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                            
                                            // Add pricing rate information
                                            if let model = usage.modelUsed ?? viewModel.modelUsed {
                                                if model.contains("gpt-4-turbo") {
                                                    Text("Rate: $10.00/million input, $30.00/million output tokens")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                } else if model.contains("gpt-4o") {
                                                    Text("Rate: $2.50/million input, $10.00/million output tokens")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                } else if model.contains("gpt-4") {
                                                    Text("Rate: $10.00/million input, $30.00/million output tokens")
                                                        .font(.caption)
                                                        .foregroundColor(.orange)
                                                } else {
                                                    Text("Rate: $0.50/million input, $1.50/million output tokens")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text("$\(String(format: "%.4f", usage.estimatedCost))")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .fontWeight(.medium)
                                    }
                                    
                                    // Only show latest request ID
                                    if let latestId = viewModel.requestIds.last {
                                        HStack {
                                            Text("Request ID: \(latestId.uuidString)")
                                                .font(.footnote)
                                                .foregroundColor(.gray)
                                            
                                            Button {
                                                UIPasteboard.general.string = latestId.uuidString
                                                showCopyConfirmation = true
                                            } label: {
                                                Image(systemName: "doc.on.doc")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    
                                    // Copy confirmation
                                    if showCopyConfirmation {
                                        Text("Copied to clipboard!")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                            .onAppear {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                    showCopyConfirmation = false
                                                }
                                            }
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                }
                .navigationTitle("AI Research Results")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            isPresented = false
                        } label: {
                            Text("Done")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            shareResult()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    if let data = response.data(using: .utf8) {
                        AIResearchShareSheet(items: [data])
                    }
                }
            }
        }
        
        private func shareResult() {
            showShareSheet = true
        }
    }

    // Helper for sharing content - renamed to avoid conflict
    struct AIResearchShareSheet: UIViewControllerRepresentable {
        var items: [Any]
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            return controller
        }
        
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
            // Nothing to update
        }
    }
} 
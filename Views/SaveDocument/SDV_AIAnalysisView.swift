import SwiftUI
import CoreData
import Combine

// AI Analysis section view for SaveDocumentView - extracted as part of Phase 3 refactoring
extension Views_SaveDocument {
    struct SDV_AIAnalysisView: View {
        // MARK: - Properties
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @EnvironmentObject private var subscriptionManager: SubscriptionManager
        @State private var showMetadataDebug = false
        
        // MARK: - Body
        var body: some View {
            if !subscriptionManager.isPremium {
                Text("AI Analysis requires Premium.")
                    .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Only show analysis if AI is enabled in user defaults
                    if UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") {
                        // Show analysis status
                        Text("AI Analysis \(viewModel.aiSuggestions == nil ? "Pending" : "Completed")")
                            .font(.headline)
                            .foregroundColor(viewModel.aiSuggestions != nil ? .green : .primary)
                        
                        if let tokenUsage = viewModel.aiSuggestions?.tokenUsage {
                            // Start with model information (GPT-4 is the default model)
                            Text("Model: GPT-4")
                                .font(.caption)
                            
                            // Show token usage
                            Text("Tokens: \(tokenUsage.promptTokens) prompt + \(tokenUsage.completionTokens) completion")
                                .font(.caption)
                            
                            // Show estimated cost if available
                            if let cost = tokenUsage.estimatedCost {
                                Text("Estimated cost: $\(String(format: "%.4f", cost))")
                                    .font(.caption)
                            } else {
                                // Calculate cost if not provided directly
                                Text("Estimated cost: $\(String(format: "%.4f", SDV_AIHelpers.calculateCost(promptTokens: tokenUsage.promptTokens, completionTokens: tokenUsage.completionTokens)))")
                                    .font(.caption)
                            }
                        }
                        
                        // Debug button
                        Button(action: {
                            showMetadataDebug.toggle()
                        }) {
                            Text(showMetadataDebug ? "Hide Debug Info" : "Show Debug Info")
                                .font(.caption)
                        }
                        
                        // Show debug info if enabled
                        if showMetadataDebug {
                            Text(SDV_AIHelpers.generateMetadataDebugText(viewModel: viewModel))
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(nil)
                                .padding(.top, 4)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("AI Document Classification is disabled in settings.")
                            .font(.caption)
                    }
                }
            }
        }
    }
}

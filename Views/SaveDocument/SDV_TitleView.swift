import SwiftUI
import CoreData
import Combine

// Title section view for SaveDocumentView - extracted as part of Phase 3 refactoring
extension Views_SaveDocument {
    struct SDV_TitleView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Binding var documentTitle: String
        @Binding var showAIConfirmation: Bool
        
        var body: some View {
            Section {
                TextField("Document Title", text: $documentTitle)
                    .onChange(of: documentTitle) { _ in
                        viewModel.documentTitle = documentTitle
                    }
                
                // Title suggestions if available
                if let suggestion = viewModel.aiSuggestions?.suggestedTitle, !suggestion.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Suggestion:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Spacer()
                            Button("Use Title") {
                                selectSuggestedTitle(suggestion)
                            }
                            .font(.subheadline)
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("TITLE")
            }
        }
        
        // Handle selecting an AI-suggested title
        private func selectSuggestedTitle(_ title: String) {
            print(" [SDV_TitleView] User selected suggested title: \(title)")
            
            // Update both local state and view model
            documentTitle = title
            viewModel.documentTitle = title
            
            // No confirmation popup needed - it's now removed
        }
    }
}

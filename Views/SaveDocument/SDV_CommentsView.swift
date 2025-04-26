import SwiftUI
import CoreData
import Combine

// Comments section view for SaveDocumentView - extracted as part of Phase 3 refactoring
extension Views_SaveDocument {
    struct SDV_CommentsView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Binding var comments: String
        
        var body: some View {
            Section {
                TextEditor(text: $comments)
                    .frame(minHeight: 100)
                    .onChange(of: comments) { _ in
                        viewModel.comments = comments
                    }
            } header: {
                Text("COMMENTS")
            }
        }
    }
}

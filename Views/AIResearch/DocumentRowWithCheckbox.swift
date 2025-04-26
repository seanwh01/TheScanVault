import SwiftUI

extension Views_AIResearch {
    // Document row with checkbox
    struct DocumentRowWithCheckbox: View {
        let document: AIDocumentItem
        let folderName: String?
        let tagsText: String
        let isSelected: Bool
        let onToggle: () -> Void
        @State private var showingPreview = false
        let persistenceController: PersistenceController
        
        var body: some View {
            HStack {
                CheckboxView(isChecked: isSelected)
                    .customTapAction(haptic: .medium, action: onToggle)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title row - showing title and lock if needed
                    HStack {
                        Text(document.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if document.isLocked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Second row - date and token count separated by dot
                    HStack {
                        Text(document.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text("\(document.estimatedTokens) tokens")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // Eye icon for viewing document
                Button {
                    showingPreview = true
                } label: {
                    Image(systemName: "eye")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .customTapAction(haptic: .light, action: onToggle)
            .fullScreenCover(isPresented: $showingPreview) {
                if let docViewModel = createDocumentViewModel(forDocId: document.id) {
                    DocumentPreviewView(viewModel: docViewModel, isPresented: $showingPreview)
                }
            }
        }
        
        // Function to create a DocumentViewModel for preview
        private func createDocumentViewModel(forDocId id: UUID) -> DocumentViewModel? {
            return DocumentViewModel(documentId: id, persistenceController: self.persistenceController)
        }
    }
} 
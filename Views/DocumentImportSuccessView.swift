import SwiftUI

struct DocumentImportSuccessView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationManager: NavigationManager
    
    let documentName: String
    let documentId: String
    let thumbnailImage: UIImage?
    
    var body: some View {
        VStack(spacing: 25) {
            // Success icon and message
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.top, 40)
            
            Text("Document Imported Successfully!")
                .font(.title2)
                .fontWeight(.bold)
            
            // Document preview
            VStack(spacing: 12) {
                if let thumbnail = thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .frame(height: 120)
                }
                
                Text(documentName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal)
            
            Text("Your document has been added to your library")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button(action: {
                    // Navigate to edit document
                    navigationManager.navigateToDocumentEdit(documentId: documentId)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Document")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    // Just dismiss this view to return to main screen
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

// Preview provider
struct DocumentImportSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentImportSuccessView(
            documentName: "Invoice #12345.pdf",
            documentId: "doc123",
            thumbnailImage: nil
        )
        .environmentObject(NavigationManager())
    }
}

// If you don't already have a NavigationManager, here's a basic implementation
class NavigationManager: ObservableObject {
    func navigateToDocumentEdit(documentId: String) {
        // Implementation to navigate to document edit screen
        print("Navigating to edit document: \(documentId)")
    }
} 
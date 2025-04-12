import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var completion: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define the document types we support
        let supportedTypes: [UTType] = [
            .pdf,
            .image,
            .jpeg,
            .png,
            .tiff
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Create a secure bookmark for the URL
            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                // Copy the file to app's temporary directory
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                
                do {
                    // Remove any existing file at the temporary URL
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    
                    // Copy the file to our temporary directory for processing
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    print("✅ File successfully copied to: \(tempURL.path)")
                    
                    // Call the completion handler with our local copy
                    parent.completion(tempURL)
                } catch {
                    print("❌ Error copying file: \(error.localizedDescription)")
                }
            } catch {
                print("❌ Error creating bookmark: \(error.localizedDescription)")
            }
        }
    }
} 
import Foundation
import Combine
import SwiftUI // For UIImage on macOS conditional

// Only import VisionKit if available (iOS/iPadOS)
#if canImport(VisionKit)
import VisionKit
#endif

#if os(macOS)
typealias UIImage = NSImage
#endif

extension ViewModels_Scan {

    // MARK: - ScanCoordinator
#if canImport(VisionKit)
    @MainActor
    class ScanCoordinator: NSObject, VNDocumentCameraViewControllerDelegate, ObservableObject {

        // Publishers to communicate results back to the ViewModel
        let didFinishScanning = PassthroughSubject<[UIImage], Never>()
        let didFailScanning = PassthroughSubject<Error, Never>()
        let didCancelScanning = PassthroughSubject<Void, Never>()
        
        // Keep track of the presented controller if needed
        private weak var cameraViewController: VNDocumentCameraViewController?

        override init() {
            super.init()
            print("📸 ScanCoordinator Initialized (VisionKit available)")
        }
        
        // Called by ViewModel to create and potentially present the scanner
        // Presentation logic might live in the View itself using a sheet modifier bound to a Bool
        func makeScannerViewController() -> VNDocumentCameraViewController {
            let controller = VNDocumentCameraViewController()
            controller.delegate = self
            self.cameraViewController = controller // Keep a weak reference
            print("📸 Created VNDocumentCameraViewController instance.")
            return controller
        }

        // MARK: - VNDocumentCameraViewControllerDelegate Methods

        // Scanning was successful
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            print("✅ VisionKit Scan Finished: Processing \(scan.pageCount) pages.")
            
            // Extract images from the scan results
            var scannedImages: [UIImage] = []
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                #if os(macOS)
                // On macOS, imageOfPage(at:) returns NSImage directly
                scannedImages.append(image)
                #else
                // On iOS, it returns UIImage
                scannedImages.append(image)
                #endif
            }
            
            if scannedImages.isEmpty {
                 print("🚨 Scan finished but no images were extracted.")
                 // Consider sending an error or just an empty array?
                 // Sending an error might be better to indicate something went wrong.
                 didFailScanning.send(ScanCoordinatorError.noImagesExtracted)
            } else {
                // Send the successfully scanned images back
                didFinishScanning.send(scannedImages)
            }
            
            // Dismissal is usually handled by the View presenting the sheet
            // controller.dismiss(animated: true)
        }

        // Scanning failed with an error
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("🚨 VisionKit Scan Failed: \(error.localizedDescription)")
            // Send the error back
            didFailScanning.send(error)
            
             // Dismissal handled by View
            // controller.dismiss(animated: true)
        }

        // User cancelled the scanning process
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            print("🗑️ VisionKit Scan Cancelled by User.")
            // Notify that the user cancelled
            didCancelScanning.send()
            
             // Dismissal handled by View
            // controller.dismiss(animated: true)
        }
    }
    
    enum ScanCoordinatorError: LocalizedError {
        case noImagesExtracted
        
        var errorDescription: String? {
            switch self {
            case .noImagesExtracted: return "The document scan completed, but no images could be extracted."
            }
        }
    }

#else
    // Fallback for platforms without VisionKit (e.g., macOS without Catalyst?)
    // Provide a stub implementation or handle file import logic here if needed.
    @MainActor
    class ScanCoordinator: NSObject, ObservableObject {
         let didFinishScanning = PassthroughSubject<[UIImage], Never>()
         let didFailScanning = PassthroughSubject<Error, Never>()
         let didCancelScanning = PassthroughSubject<Void, Never>()
         
         override init() {
             super.init()
             print("⚠️ ScanCoordinator Initialized (VisionKit NOT available)")
         }
         
         // Provide alternative methods, e.g., for opening a file panel
         func openFileImporter() {
             print("macOS: Triggering file import (implementation needed)")
             // Implementation would involve NSOpenPanel or similar
             // For now, send an error indicating feature not available
             didFailScanning.send(ScanCoordinatorError.visionKitUnavailable)
         }
    }
    
    enum ScanCoordinatorError: LocalizedError {
        case visionKitUnavailable
        case noImagesExtracted // Keep consistent error type if possible
        
        var errorDescription: String? {
            switch self {
            case .visionKitUnavailable: return "Document scanning via camera is not available on this platform."
            case .noImagesExtracted: return "No images were extracted."
            }
        }
    }
#endif
}

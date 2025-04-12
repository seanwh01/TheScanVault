import SwiftUI
import VisionKit
import UIKit

struct ScanView: View {
    @StateObject private var viewModel: ScanViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showScanner = false
    @State private var showSaveSheet = false
    @State private var showFolderPicker = false
    @State private var selectedFolderId: UUID?
    @State private var folderName: String = ""
    @State private var showUploadProcessingOverlay = false
    @State private var processingMessage = "Processing document..."
    @State private var showUploadErrorAlert = false
    @State private var uploadErrorMessage = ""
    
    init() {
        // Initialize with a temporary subscription manager
        // We'll properly set it in onAppear
        _viewModel = StateObject(wrappedValue: ScanViewModel(subscriptionManager: SubscriptionManager()))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Centered logo at Launch Page size
                Image("ScanVaultLogoforAppTM")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.7) // 70% of screen width
                    .padding(.vertical, 30)
                
                Spacer() // Space between logo and button
                
                // Upload Document button
                Button(action: {
                    viewModel.showDocumentPicker()
                }) {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                            .font(.title2)
                        Text("Upload Document")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .shadow(radius: 3)
                }
                .padding(.horizontal)
                
                // Scan New Document button
                Button(action: {
                    viewModel.startScanning()
                    showScanner = true
                }) {
                    HStack {
                        Image(systemName: "doc.viewfinder")
                            .font(.title2)
                        Text("Scan New Document")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                    .shadow(radius: 3)
                }
                .padding(.horizontal)
                
                // Smaller Recent Scans section
                if !viewModel.recentScans.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Recent Scans")
                            .font(.subheadline)
                            .padding(.leading)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { // Reduced spacing
                                ForEach(viewModel.recentScans.prefix(5)) { document in
                                    VStack {
                                        if let thumbnail = document.thumbnail {
                                            Image(uiImage: thumbnail)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 70, height: 90) // Smaller size
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .shadow(radius: 2)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 70, height: 90)
                                                .overlay(
                                                    Image(systemName: "doc.text")
                                                        .foregroundColor(.gray)
                                                )
                                        }
                                        
                                        Text(document.title)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .frame(width: 70)
                                    }
                                    .onTapGesture {
                                        // Navigate to document detail
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 120) // Reduced height
                    }
                }
            }
            .navigationBarHidden(true) // Hide the navigation bar completely
            .sheet(isPresented: $showScanner) {
                ScannerView { result in
                    switch result {
                    case .success(let scannedImages):
                        viewModel.processScannedImages(scannedImages)
                        showScanner = false
                        viewModel.showingDocumentCreation = true
                    case .failure(let error):
                        print("Scanning failed: \(error.localizedDescription)")
                        showScanner = false
                    }
                }
            }
            .sheet(isPresented: $showSaveSheet) {
                SaveDocumentView(viewModel: viewModel)
            }
            .sheet(isPresented: $showFolderPicker) {
                NavigationView {
                    FolderSelectionView(
                        selectedFolderId: $selectedFolderId,
                        folderName: Binding<String?>(
                            get: { self.folderName.isEmpty ? nil : self.folderName },
                            set: { self.folderName = $0 ?? "" }
                        ),
                        onSave: {
                            print("✅ Folder selected: \(selectedFolderId?.uuidString ?? "None"), Name: \(folderName)")
                            // Additional save logic here if needed
                        }
                    )
                    .navigationBarTitleDisplayMode(.inline)
                }
                .navigationViewStyle(StackNavigationViewStyle()) // Ensure proper navigation style
            }
            .sheet(isPresented: $viewModel.showingDocumentPicker, onDismiss: {
                // Start showing processing overlay if still processing
                if viewModel.isProcessingUpload {
                    showUploadProcessingOverlay = true
                }
            }) {
                DocumentPicker(completion: viewModel.handleSelectedDocument)
            }
            .sheet(isPresented: $viewModel.showingDocumentCreation, onDismiss: {
                // Reset processing state on dismiss
                viewModel.isProcessingUpload = false
                showUploadProcessingOverlay = false
            }) {
                SaveDocumentView(viewModel: viewModel)
            }
            .overlay(
                ZStack {
                    if viewModel.isProcessingUpload {
                        Rectangle()
                            .fill(Color.black.opacity(0.7))
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text(processingMessage)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            if viewModel.ocrProgress > 0 && viewModel.totalOCRPages > 0 {
                                Text("OCR Progress: \(viewModel.ocrProgress) of \(viewModel.totalOCRPages) pages")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(30)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(15)
                    }
                }
            )
            .alert(isPresented: $viewModel.showUnsupportedFileAlert) {
                Alert(
                    title: Text("Unsupported File"),
                    message: Text("The selected file type is not supported. Please select a PDF, JPG, PNG, or TIFF file."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onReceive(viewModel.$isProcessingUpload) { isProcessing in
                showUploadProcessingOverlay = isProcessing
                if isProcessing {
                    processingMessage = "Processing document..."
                }
            }
            .onReceive(viewModel.$ocrProgress) { progress in
                if progress > 0 {
                    processingMessage = "Analyzing text (OCR)..."
                }
            }
        }
        .onAppear {
            // Replace the temporary subscription manager with the real one from the environment
            viewModel.updateSubscriptionManager(subscriptionManager)
        }
    }
}

// Main content component
struct MainContentView: View {
    @Binding var showScanner: Bool
    @ObservedObject var viewModel: ScanViewModel
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                ScanButton(showScanner: $showScanner)
                Spacer()
                RecentScansView(recentScans: viewModel.recentScans)
            }
            .padding()
        }
    }
}

// Scan button component
struct ScanButton: View {
    @Binding var showScanner: Bool
    
    var body: some View {
        Button(action: { showScanner = true }) {
            VStack {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 60))
                Text("Scan Document")
                    .font(.headline)
                    .padding(.top, 8)
            }
            .foregroundColor(.white)
            .frame(width: 200, height: 200)
            .background(Color.blue)
            .cornerRadius(20)
            .shadow(radius: 5)
        }
    }
}

// Recent scans component
struct RecentScansView: View {
    let recentScans: [DocumentItem]
    
    var body: some View {
        if !recentScans.isEmpty {
            VStack(alignment: .leading) {
                Text("Recent Scans")
                    .font(.subheadline)
                    .padding(.leading)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentScans.prefix(5)) { document in
                            RecentScanItem(document: document)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 140)
            }
        }
    }
}

// Individual recent scan item component
struct RecentScanItem: View {
    let document: DocumentItem
    
    var body: some View {
        VStack {
            if let thumbnail = document.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 100)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            
            Text(document.title)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 80)
        }
        .onTapGesture {
            // Navigate to document detail
        }
    }
}

// SwiftUI wrapper for VisionKit's document scanner
struct ScannerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = VNDocumentCameraViewController
    
    let completionHandler: (Result<[UIImage], Error>) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completionHandler: completionHandler)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completionHandler: (Result<[UIImage], Error>) -> Void
        
        init(completionHandler: @escaping (Result<[UIImage], Error>) -> Void) {
            self.completionHandler = completionHandler
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var scannedImages = [UIImage]()
            
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                scannedImages.append(image)
            }
            
            completionHandler(.success(scannedImages))
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completionHandler(.failure(NSError(domain: "ScanVault", code: 0, userInfo: [NSLocalizedDescriptionKey: "Scanning canceled"])))
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completionHandler(.failure(error))
        }
    }
}

struct TagSelectionView: View {
    @Binding var selectedTags: Set<UUID>
    let tags: [TagItem]
    @State private var showAddTag = false
    @State private var newTagName = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            ForEach(tags) { tag in
                Button {
                    if selectedTags.contains(tag.id) {
                        selectedTags.remove(tag.id)
                    } else {
                        selectedTags.insert(tag.id)
                    }
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        if selectedTags.contains(tag.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Tags")
        .navigationBarItems(
            trailing: Button(action: {
                showAddTag = true
            }) {
                Image(systemName: "tag.badge.plus")
            }
        )
        .sheet(isPresented: $showAddTag) {
            // Add tag sheet would go here
        }
    }
} 

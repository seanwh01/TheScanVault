import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif

struct ScanView: View {
    @StateObject private var viewModel: ViewModels_Scan.ScanViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    // Updated initializer to accept AppServices directly
    init(appServices: AppServices, subscriptionManager: SubscriptionManager) {
        _viewModel = StateObject(wrappedValue: ViewModels_Scan.ScanViewModel(
            appServices: appServices, // Use the passed-in instance
            subscriptionManager: subscriptionManager
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image("ScanVaultLogoforAppTM")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .padding(.vertical, 30)

                Spacer()

                Button(action: viewModel.triggerDocumentPicker) {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                            .font(.title2)
                        Text("Import Document")
                            .font(.headline)
                    }
                    .modifier(MainButtonStyle(backgroundColor: .blue))
                }
                .padding(.horizontal)

                Button(action: viewModel.startScan) {
                    HStack {
                        Image(systemName: "doc.viewfinder")
                            .font(.title2)
                        Text("Scan New Document")
                            .font(.headline)
                    }
                    .modifier(MainButtonStyle(backgroundColor: .green))
                }
                .padding(.horizontal)
                #if !canImport(VisionKit)
                .disabled(true)
                .opacity(0.5)
                #endif

                Spacer()

                if !viewModel.recentScans.isEmpty {
                    RecentScansView(viewModel: viewModel)
                }
            }
            .navigationBarHidden(true)
            #if canImport(VisionKit)
            .sheet(isPresented: $viewModel.showDocumentScanner) {
                DocumentScannerViewRepresentable(coordinator: viewModel.scanCoordinator)
                    .edgesIgnoringSafeArea(.all)
            }
            #endif
            .sheet(isPresented: $viewModel.showingDocumentPicker) {
                DocumentPicker { url in
                    viewModel.handleSelectedDocument(.success(url))
                }
            }
            .onChange(of: viewModel.showDocumentCreationSheet) { _, newValue in
                if newValue {
                    print("📄 [ScanView] Presenting Save Sheet. State: Images=\(viewModel.scannedImages.count), PDF=\(viewModel.importedPDFData != nil)")
                }
            }
            .sheet(isPresented: $viewModel.showDocumentCreationSheet) {
                SaveDocumentView(viewModel: viewModel)
                    .environmentObject(subscriptionManager)
            }
            .overlay(
                ProcessingOverlay(isProcessing: $viewModel.isProcessing,
                                    progressText: $viewModel.processingProgressText)
            )
            .alert("Error", isPresented: $viewModel.showProcessingErrorAlert, presenting: viewModel.processingErrorMessage) { _ in
                Button("OK") { }
            } message: { message in
                Text(message)
            }
            .alert("Unsupported File", isPresented: $viewModel.showUnsupportedFileAlert) {
                Button("OK") { }
            } message: {
                Text("The selected file type is not supported. Please select a PDF, JPG, PNG, or TIFF file.")
            }
        }
    }
}

struct MainButtonStyle: ViewModifier {
    let backgroundColor: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(10)
            .shadow(radius: 3)
    }
}

struct RecentScansView: View {
    @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Scans")
                .font(.subheadline)
                .padding(.leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.recentScans.prefix(5), id: \.id) { document in
                        RecentScanItemView(document: document)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 120)
        }
    }
}

#if os(macOS)
import AppKit // Needed for NSImage
#endif
struct RecentScanItemView: View {
    let document: DocumentItem

    var body: some View {
        VStack {
            if let thumbnailData = document.thumbnail {
                #if os(macOS)
                if let nsImage = NSImage(data: thumbnailData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 2)
                }
                #else
                if let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 2)
                }
                #endif
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
                .frame(width: 70) // Ensure text doesn't overflow horizontally
        }
        .onTapGesture {
            print("Navigate to detail for: \(document.title)")
        }
    }
}

struct ProcessingOverlay: View {
    @Binding var isProcessing: Bool
    @Binding var progressText: String

    var body: some View {
        ZStack {
            if isProcessing {
                Rectangle()
                    .fill(Color.black.opacity(0.7))
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text(progressText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(30)
                .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
                .cornerRadius(15)
            }
        }
        .animation(.default, value: isProcessing)
    }
}

#if canImport(VisionKit)
struct DocumentScannerViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var coordinator: ViewModels_Scan.ScanCoordinator

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = coordinator.makeScannerViewController()
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
    }
}
#endif

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let subscriptionManager = SubscriptionManager()
        let appServices = AppServices(persistenceController: persistenceController)
        
        ScanView(
            appServices: appServices,
            subscriptionManager: subscriptionManager
        )
        .environmentObject(subscriptionManager)
        .environment(\.managedObjectContext, persistenceController.viewContext)
        .environmentObject(persistenceController)
    }
}

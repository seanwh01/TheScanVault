import Foundation
import Combine
import PDFKit // For PDF handling
import Vision // For OCR types if needed
import CoreData // Might be needed if DocumentProcessor requires it
import SwiftUI // For UIImage/NSImage

#if os(macOS)
typealias UIImage = NSImage
#else
import UIKit
#endif

// MARK: - Error Enum
enum ProcessingError: LocalizedError {
    case noInputData
    case invalidPDFData
    case pdfConversionFailed
    case ocrFailed(Error?) // Include underlying error if available
    case aiAnalysisFailed(Error?) // Include underlying error if available
    case thumbnailGenerationFailed
    case pdfCreationFailed
    case requiresPremium
    case cancelled
    case unknown(Error?) // Generic fallback
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .noInputData:
            return "No images or PDF data were provided for processing."
        case .invalidPDFData:
            return "The provided PDF data could not be read."
        case .pdfConversionFailed:
            return "Failed to convert PDF pages to images for processing."
        case .ocrFailed(let underlyingError):
            return "OCR processing failed." + (underlyingError != nil ? " Error: \(underlyingError!.localizedDescription)" : "")
        case .aiAnalysisFailed(let underlyingError):
             return "AI analysis failed." + (underlyingError != nil ? " Error: \(underlyingError!.localizedDescription)" : "")
        case .thumbnailGenerationFailed:
            return "Failed to generate document thumbnail."
        case .pdfCreationFailed:
            return "Failed to create the final PDF document."
        case .requiresPremium:
            return "This feature requires a premium subscription."
        case .cancelled:
            return "Processing was cancelled."
        case .unknown(let underlyingError):
            return "An unknown processing error occurred." + (underlyingError != nil ? " Error: \(underlyingError!.localizedDescription)" : "")
        case .processingFailed:
            return "An error occurred during processing."
        }
    }
}

// MARK: - Delegate Protocol
protocol DocumentProcessingServiceDelegate: AnyObject {
    func documentProcessingServiceDidStartProcessing()
    func documentProcessingServiceDidUpdateOCRProgress(completedPages: Int, totalPages: Int)
    func documentProcessingServiceDidCompleteOCR(fullText: String)
    func documentProcessingServiceDidStartAIAnalysis()
    func documentProcessingServiceDidReceiveAISuggestions(suggestions: DocumentClassifierService.DocumentSuggestions)
    // Changed finalDocumentData to Data? to match processor delegate
    func documentProcessingServiceDidFinishProcessing(error: Error?, finalDocumentData: Data?)
    func documentProcessingServiceDidEncounterError(error: ProcessingError) // Specific error type
    func documentProcessingServiceRequiresPremium()
}

extension ViewModels_Scan {
    
    @MainActor
    class DocumentProcessingService: ObservableObject, DocumentProcessorDelegate {
        
        // Input Type - Added Equatable
        enum Input: Equatable { 
            case images([UIImage])
            case pdf(Data)

            // Need to implement == for Equatable because UIImage/Data aren't intrinsically Equatable
            static func == (lhs: Input, rhs: Input) -> Bool {
                switch (lhs, rhs) {
                case (.images(let lhsImages), .images(let rhsImages)):
                    // Basic comparison: check count. For deep comparison, need image hashing or data comparison.
                    return lhsImages.count == rhsImages.count // Simplified comparison
                case (.pdf(let lhsData), .pdf(let rhsData)):
                    return lhsData == rhsData
                default:
                    return false
                }
            }
        }
        
        // Output state
        @Published private(set) var processedText: String? = nil
        @Published private(set) var ocrProgress: Double = 0.0
        @Published private(set) var isProcessing: Bool = false
        @Published private(set) var processingError: ProcessingError? = nil // Use specific error type
        @Published private(set) var showProcessingErrorAlert: Bool = false
        @Published private(set) var generatedThumbnailData: Data? = nil
        @Published private(set) var finalDocumentData: Data? = nil // PDF or combined image PDF
        @Published private(set) var inputDataType: Input? = nil // Track original type
        
        private let persistenceController: PersistenceController
        private let openAIService: OpenAIService
        private let documentAIService: DocumentAIService
        private let adaptiveLearningClassifier: AdaptiveLearningClassifier
        private let documentProcessor: DocumentProcessor
        private let subscriptionManager: SubscriptionManager
        private var cancellables = Set<AnyCancellable>()
        private var currentInput: Input? // Keep track of the input being processed
        private var processedPDFData: Data? = nil // Store processed PDF data
        private var totalPages: Int = 0 // Store total pages
        private var completedPageCount: Int = 0 // Track completed pages
        
        // Delegate Property
        weak var delegate: DocumentProcessingServiceDelegate?

        init(appServices: AppServices, subscriptionManager: SubscriptionManager) { 
            self.persistenceController = appServices.persistenceController
            self.openAIService = appServices.openAIService
            self.documentAIService = appServices.documentAIService
            self.adaptiveLearningClassifier = appServices.adaptiveLearningClassifier
            self.subscriptionManager = subscriptionManager
            self.documentProcessor = DocumentProcessor(
                openAIService: self.openAIService,
                persistenceController: self.persistenceController,
                documentAIService: self.documentAIService,
                adaptiveLearningClassifier: self.adaptiveLearningClassifier
            )
            self.documentProcessor.delegate = self
            print("🚀 Document Processing Service Initialized")
        }

        // MARK: - Public Processing Trigger

        // Call this to start processing either images or a PDF
        func startProcessing(input: Input) {
            print("📄 Starting document processing...")
            resetProcessingState()
            currentInput = input // Store current input
            
            self.delegate?.documentProcessingServiceDidStartProcessing()
            
            // Reset specific state variables
            ocrProgress = 0.0
            totalPages = 0 // Reset total pages
            processedText = nil
            processedPDFData = nil
            
            // Determine total pages based on input
            let count: Int
            switch input {
            case .images(let images):
                count = images.count
            case .pdf(let pdfData):
                count = PDFDocument(data: pdfData)?.pageCount ?? 0
            }
            self.totalPages = count // STORE total pages
            print("📄 Total pages to process: \(self.totalPages)")

            // Start the actual DocumentProcessor
            // DocumentProcessor handles the logic for images vs PDF internally now?
            switch input {
            case .images(let images):
                guard !images.isEmpty else {
                    print("⚠️ Attempted to process empty image array.")
                    handleError(ProcessingError.noInputData, originalError: nil)
                    return
                }
                print("Processing \(images.count) images.")
                documentProcessor.processDocument(images: images)

            case .pdf(let pdfData):
                guard let pdfDocument = PDFDocument(data: pdfData) else {
                    print("❌ Failed to create PDFDocument from data.")
                    handleError(ProcessingError.invalidPDFData, originalError: nil)
                    return
                }
                self.processedPDFData = pdfData // STORE the input PDF data
                
                print("📄 Loaded PDF with \(pdfDocument.pageCount) pages. Converting to images...")
                var images: [UIImage] = []
                let conversionDispatchGroup = DispatchGroup()
                let conversionQueue = DispatchQueue(label: "com.thescanvault.pdfconversion", qos: .userInitiated, attributes: .concurrent)

                // Use a temporary array to store images in order, as appending in concurrent tasks can mess up order
                var orderedImages: [(Int, UIImage)] = []

                for i in 0..<pdfDocument.pageCount {
                    conversionDispatchGroup.enter()
                    conversionQueue.async {
                        defer { conversionDispatchGroup.leave() }
                        guard let page = pdfDocument.page(at: i) else { return }

                        // Determine render size (e.g., based on cropBox, maybe scaled)
                        // Using a fixed scale factor for now for simplicity (e.g., 2x for better OCR)
                        let scaleFactor: CGFloat = 2.0
                        let pageBounds = page.bounds(for: .cropBox)
                        let imageSize = CGSize(width: pageBounds.width * scaleFactor, height: pageBounds.height * scaleFactor)

                        #if os(macOS)
                        // macOS: Render NSImage
                        let image = NSImage(size: imageSize, flipped: false) { (rect) -> Bool in
                            guard let context = NSGraphicsContext.current?.cgContext else { return false }
                            context.saveGState()
                            context.setFillColor(NSColor.white.cgColor) // White background
                            context.fill(rect)
                            // Scale and draw the PDF page
                            context.scaleBy(x: scaleFactor, y: scaleFactor)
                            page.draw(with: .cropBox, to: context)
                            context.restoreGState()
                            return true
                        }
                        orderedImages.append((i, image)) // Append tuple with index
                        #else
                        // iOS: Render UIImage
                        let renderer = UIGraphicsImageRenderer(size: imageSize)
                        let image = renderer.image { ctx in
                            // Fill background
                            UIColor.white.setFill()
                            ctx.fill(CGRect(origin: .zero, size: imageSize))
                            // Adjust coordinate system for PDF rendering
                            ctx.cgContext.translateBy(x: 0.0, y: imageSize.height)
                            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                            // Scale PDF page content
                            ctx.cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
                            // Draw the page
                            page.draw(with: .cropBox, to: ctx.cgContext)
                        }
                        orderedImages.append((i, image)) // Append tuple with index
                        #endif
                    }
                }

                // Wait for all conversions to complete
                conversionDispatchGroup.notify(queue: .main) {
                    // Sort images by original page index
                    images = orderedImages.sorted { $0.0 < $1.0 }.map { $1 }

                    if images.count == pdfDocument.pageCount {
                        print("✅ Successfully converted \(images.count) PDF pages to images.")
                        self.documentProcessor.processDocument(images: images)
                    } else {
                        print("❌ Failed to convert all PDF pages. Expected \(pdfDocument.pageCount), got \(images.count).")
                        self.handleError(ProcessingError.pdfConversionFailed, originalError: nil)
                        // Still try processing the pages we got?
                        if !images.isEmpty {
                            print("⚠️ Proceeding with processing for \(images.count) converted pages.")
                            self.documentProcessor.processDocument(images: images)
                        } else {
                            print("🚨 No pages converted, processing cannot proceed.")
                        }
                    }
                }
            }
        }
        
        // Cancel any ongoing processing
        func cancelProcessing() {
            if isProcessing {
                print("📄 Cancelling document processing.")
                documentProcessor.cancelProcessing() // Assuming DocumentProcessor has cancel method
                resetProcessingState()
            }
        }
        
        // MARK: - Thumbnail Generation (Example for first page/image)
        // Updated thumbnail generation to handle Input enum and add TODO for PDF
        private func generateThumbnailIfNeeded() {
             // COMMENTED OUT - Comparison needs update if Input changes significantly
             // guard generatedThumbnailData == nil else { return } // Generate only once per processing session

            // let maxThumbnailSize = CGSize(width: 150, height: 200) // Example size

            // switch currentInput {
            // case .images(let images):
            //     if let firstImage = images.first {
            //         generatedThumbnailData = generateThumbnail(from: firstImage, maxSize: maxThumbnailSize)
            //         print(generatedThumbnailData != nil ? "🖼️ Generated thumbnail from first image." : "⚠️ Failed to generate thumbnail from image.")
            //     }
            // case .pdf(let pdfData):
            //     // TODO: Thumbnail generation from PDF also needs PDF rendering logic
            //     print("⚠️ Thumbnail generation from PDF not implemented yet.")
            //      if let pdfDoc = PDFDocument(data: pdfData), pdfDoc.pageCount > 0, let firstPage = pdfDoc.page(at: 0) {
            //          #if os(macOS)
            //          let image = firstPage.thumbnail(of: maxThumbnailSize, for: .cropBox)
            //          generatedThumbnailData = image.tiffRepresentation // Or other format
            //          #else
            //          // iOS: Render page to UIImage context
            //          let pdfPageRect = firstPage.bounds(for: .cropBox)
            //          let renderer = UIGraphicsImageRenderer(size: maxThumbnailSize) // Render at target size
            //          let image = renderer.image { ctx in
            //              UIColor.white.set() // Background
            //              ctx.fill(CGRect(origin: .zero, size: maxThumbnailSize)) // Fill background
            //              ctx.cgContext.translateBy(x: 0.0, y: maxThumbnailSize.height)
            //              ctx.cgContext.scaleBy(x: 1.0, y: -1.0) // Flip context
                         
            //              // Scale PDF page to fit thumbnail size
            //              let scaleFactor = min(maxThumbnailSize.width / pdfPageRect.width, maxThumbnailSize.height / pdfPageRect.height)
            //              ctx.cgContext.scaleBy(x: scaleFactor, y: scaleFactor)
                         
            //              firstPage.draw(with: .cropBox, to: ctx.cgContext)
            //          }
            //          generatedThumbnailData = image.pngData() // Or jpegData
            //          #endif
            //          print(generatedThumbnailData != nil ? "🖼️ Generated thumbnail from PDF first page." : "⚠️ Failed to generate thumbnail from PDF.")
            //      } else {
            //           print("⚠️ Could not load PDF document or PDF has no pages for thumbnail generation.")
            //      }
            // case .none:
            //      print("⚠️ Cannot generate thumbnail, no input data available.")
            // }
        }

        // Internal helper to generate thumbnail from a UIImage
        private func generateThumbnail(from image: UIImage, maxSize: CGSize) -> Data? {
            #if os(macOS)
            // macOS NSImage thumbnail generation
            let targetSize = maxSize // Example size
            if let resizedImage = image.resized(to: targetSize), 
               let tiffData = resizedImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
               return pngData
            } else {
                 print("🚨 Failed to generate thumbnail from NSImage")
                 return nil
            }
            #else
            // iOS UIImage thumbnail generation
            let targetSize = maxSize // Example size
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            return resizedImage.pngData()
            #endif
        }

        // MARK: - PDF Creation Helper
        private func createPDF(from images: [UIImage]) -> Data? {
            guard !images.isEmpty else { return nil }
            
            let pdfDocument = PDFDocument()
            for (index, image) in images.enumerated() {
                if let pdfPage = PDFPage(image: image) {
                    pdfDocument.insert(pdfPage, at: index)
                } else {
                     print("⚠️ Could not create PDF page from image at index \(index)")
                     // Optionally decide if failure to convert one image should fail the whole PDF
                }
            }
            
            if pdfDocument.pageCount == images.count && pdfDocument.pageCount > 0 {
                print("📄 Successfully created PDF document with \(pdfDocument.pageCount) pages from images.")
                return pdfDocument.dataRepresentation()
            } else if pdfDocument.pageCount > 0 {
                 print("⚠️ Created PDF with \(pdfDocument.pageCount) pages, but expected \(images.count). Some images might have failed.")
                 return pdfDocument.dataRepresentation() // Return partial PDF
            } else {
                print("🚨 Failed to create PDF document from images.")
                return nil
            }
        }

        // MARK: - DocumentProcessorDelegate Methods

        func processorDidBeginDocument(_ processor: DocumentProcessor) {
            DispatchQueue.main.async {
                print("📄 Delegate: Processor Did Start")
                self.isProcessing = true
                self.processingError = nil // Clear previous errors
                // Call the new delegate method
                self.delegate?.documentProcessingServiceDidStartProcessing()
            }
        }

        // Conforms to DocumentProcessorDelegate
        func processor(_ processor: DocumentProcessor, didCompleteOCRForPage pageIndex: Int, withText text: String) {
            DispatchQueue.main.async {
                // Calculate progress based on stored totalPages
                self.completedPageCount += 1 // Increment counter
                let currentPage = pageIndex + 1 // pageIndex is 0-based (keep for logging maybe?)
                guard self.totalPages > 0 else { return } // Avoid division by zero
                self.ocrProgress = Double(self.completedPageCount) / Double(self.totalPages)
                print("📄 Delegate: OCR Progress - Page \(currentPage) finished. Completed \(self.completedPageCount) of \(self.totalPages) (\(String(format: "%.1f", self.ocrProgress * 100))%)")
                // Call the delegate method expected by ScanViewModel with COMPLETED count
                self.delegate?.documentProcessingServiceDidUpdateOCRProgress(completedPages: self.completedPageCount, totalPages: self.totalPages)
            }
        }

        // Conforms to DocumentProcessorDelegate
        func processor(_ processor: DocumentProcessor, didCompleteAllOCRWithText text: String) {
            DispatchQueue.main.async {
                 print("📄 Delegate: All OCR Completed. Text length: \(text.count)")
                 self.processedText = text
                 // Call the delegate method
                 self.delegate?.documentProcessingServiceDidCompleteOCR(fullText: text)
            }
        }

        // Conforms to DocumentProcessorDelegate
        func processor(_ processor: DocumentProcessor, didFailWithError error: Error) {
            DispatchQueue.main.async {
                print("❌ Delegate: Processing Failed. Error: \(error.localizedDescription)")

                // Check if the error indicates a premium requirement
                // TODO: Adjust this check based on how DocumentProcessor actually signals this error.
                // Example: Check error domain/code or cast to a specific error type.
                let isPremiumError = (error as NSError).domain == "DocumentProcessorErrorDomain" && (error as NSError).code == 1001 // EXAMPLE check

                if isPremiumError {
                     print("⚠️ Delegate: Premium required error received.")
                     self.handleError(ProcessingError.requiresPremium, originalError: error) // Use specific enum
                     // Also notify ScanViewModel specifically about premium
                     self.delegate?.documentProcessingServiceRequiresPremium()
                } else {
                    // Handle other errors generally
                     self.handleError(ProcessingError.processingFailed, originalError: error) // Use generic error
                }
                // handleError automatically calls delegate?.documentProcessingServiceDidEncounterError
            }
        }
        
        // Conforms to DocumentProcessorDelegate
        func processorDidFinishProcessing(_ processor: DocumentProcessor) {
            DispatchQueue.main.async {
                 print("✅ Delegate: Processing Finished Successfully.")
                 // Retrieve the final document data if applicable (e.g., processed PDF)
                 // This might need adjustment based on how DocumentProcessor provides the final result
                 let finalData = self.processedPDFData // Or get from processor if it stores it?
                 self.isProcessing = false
                 self.ocrProgress = 1.0 // Ensure progress shows 100%
                 self.delegate?.documentProcessingServiceDidFinishProcessing(error: nil, finalDocumentData: finalData)
            }
        }
        
        // Conforms to DocumentProcessorDelegate
        func isAIEnabledForProcessor(_ processor: DocumentProcessor) -> Bool {
            let isEnabled = self.subscriptionManager.isPremium // Use .isPremium
            print("🤖 Delegate: AI Enabled Check -> \(isEnabled)")
            return isEnabled
        }
        
        // Conforms to DocumentProcessorDelegate
        func processor(_ processor: DocumentProcessor, didReceiveAISuggestions suggestions: DocumentClassifierService.DocumentSuggestions) {
            DispatchQueue.main.async {
                 print("🧠 Delegate: Received AI suggestions: Title='\(suggestions.suggestedTitle ?? "N/A")', Folder='\(suggestions.suggestedFolderName ?? "N/A")', Tags='\(suggestions.suggestedTags.joined(separator: ", "))'")
                 // Call the delegate method expected by ScanViewModel
                 self.delegate?.documentProcessingServiceDidReceiveAISuggestions(suggestions: suggestions)
            }
        }

        // MARK: - State Management
        
        private func resetProcessingState() {
            print("📄 Resetting processing state.")
            isProcessing = false
            ocrProgress = 0.0
            completedPageCount = 0 // Reset counter
            processedText = nil
            processingError = nil
            showProcessingErrorAlert = false
            generatedThumbnailData = nil
            finalDocumentData = nil
            inputDataType = nil
            currentInput = nil
            // Don't cancel processor here, let explicit cancel handle it
        }
        
        // MARK: - Errors
        // Updated signature to accept originalError
        private func handleError(_ specificError: ProcessingError, originalError: Error?) {
            DispatchQueue.main.async {
                print("❌ Processing Error: \(specificError.localizedDescription)")
                self.isProcessing = false
                self.processingError = specificError // Store the specific error
                self.showProcessingErrorAlert = true
                // Notify the delegate about the specific error
                self.delegate?.documentProcessingServiceDidEncounterError(error: specificError)
                // Also signal finish, but pass the ORIGINAL error
                self.delegate?.documentProcessingServiceDidFinishProcessing(error: originalError, finalDocumentData: nil)
            }
        }
    }
}

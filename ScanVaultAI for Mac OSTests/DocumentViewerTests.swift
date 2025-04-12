import XCTest
import CoreData
import PDFKit
import SwiftUI
@testable import ScanVaultAI_for_Mac_OS

// Create a mock DocumentViewerWindow for testing
struct MockDocumentViewerWindow: View {
    let document: NSManagedObject
    var body: some View {
        Text("Mock Document Viewer")
    }
}

// Extension for NSImage to get data representations
extension NSImage {
    var pngRepresentation: Data? {
        if let tiffData = tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            return bitmap.representation(using: .png, properties: [:])
        }
        return nil
    }
    
    var jpegRepresentation: Data? {
        if let tiffData = tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            return bitmap.representation(using: .jpeg, 
                                        properties: [.compressionFactor: 0.8])
        }
        return nil
    }
}

// Extension to help create PDF pages
extension NSRect {
    func createPDFPage() -> CGPDFPage? {
        var mediaBox = CGRect(x: self.origin.x, y: self.origin.y, width: self.size.width, height: self.size.height)
        
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }
        
        var pageRect = mediaBox
        context.beginPage(mediaBox: &pageRect)
        context.endPage()
        context.closePDF()
        
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let pdfDocument = CGPDFDocument(dataProvider),
              let pdfPage = pdfDocument.page(at: 1) else {
            return nil
        }
        
        return pdfPage
    }
}

// Adding logging helper function
extension DocumentViewerTests {
    func log(_ message: String) {
        let fileManager = FileManager.default
        let logPath = "/Users/seanwhite/Desktop/pdf_test_log.txt"
        
        if !fileManager.fileExists(atPath: logPath) {
            fileManager.createFile(atPath: logPath, contents: nil)
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
            fileHandle.seekToEndOfFile()
            if let data = "\(Date()): \(message)\n".data(using: .utf8) {
                fileHandle.write(data)
            }
            try? fileHandle.close()
        }
    }
}

final class DocumentViewerTests: XCTestCase {
    var persistenceController: PersistenceController!
    var viewContext: NSManagedObjectContext!
    var testDocument: NSManagedObject!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        viewContext = persistenceController.container.viewContext
        
        // Create a test document
        let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: viewContext)!
        testDocument = NSManagedObject(entity: documentEntity, insertInto: viewContext)
        
        let documentId = UUID()
        testDocument.setValue(documentId, forKey: "id")
        testDocument.setValue("Test Document", forKey: "title")
        
        // Safely set comments field if available
        if hasProperty("comments", in: testDocument.entity) {
            testDocument.setValue("Test Comments", forKey: "comments")
        }
        
        testDocument.setValue(Date(), forKey: "createdAt")
        
        // Create test PDF data only if the entity has this field
        if hasProperty("pdfData", in: testDocument.entity) {
            // Check if the test file exists
            if let pdfPath = Bundle.main.path(forResource: "test", ofType: "pdf"),
               let pdfData = try? Data(contentsOf: URL(fileURLWithPath: pdfPath)) {
                testDocument.setValue(pdfData, forKey: "pdfData")
            } else {
                // Create a simple PDF if test.pdf doesn't exist
                let pdfDocument = PDFDocument()
                let pdfPage = PDFPage(image: NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)!)
                pdfDocument.insert(pdfPage!, at: 0)
                testDocument.setValue(pdfDocument.dataRepresentation(), forKey: "pdfData")
            }
        } else if hasProperty("documentData", in: testDocument.entity) {
            // Alternative field name
            let pdfDocument = PDFDocument()
            let pdfPage = PDFPage(image: NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)!)
            pdfDocument.insert(pdfPage!, at: 0)
            testDocument.setValue(pdfDocument.dataRepresentation(), forKey: "documentData")
        }
        
        try? viewContext.save()
    }
    
    override func tearDown() {
        testDocument = nil
        viewContext = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // Helper to check if a property exists
    private func hasProperty(_ name: String, in entity: NSEntityDescription) -> Bool {
        return entity.propertiesByName[name] != nil
    }
    
    // Helper to get notes content - always from comments field for now
    private func getCommentsContent(from document: NSManagedObject) -> String {
        if hasProperty("comments", in: document.entity) {
            return document.value(forKey: "comments") as? String ?? ""
        }
        return ""
    }
    
    // Helper to get PDF data from document
    private func getPDFData(from document: NSManagedObject) -> Data? {
        if hasProperty("pdfData", in: document.entity) {
            return document.value(forKey: "pdfData") as? Data
        } else if hasProperty("documentData", in: document.entity) {
            return document.value(forKey: "documentData") as? Data
        }
        return nil
    }
    
    // MARK: - Document Viewer Tests
    
    func testDocumentViewerCreation() {
        // Test document reference exists
        XCTAssertNotNil(testDocument, "Test document should be created")
        
        // Test document ID
        XCTAssertNotNil(testDocument.value(forKey: "id"), "Document should have an ID")
        
        // Test document title
        XCTAssertEqual(testDocument.value(forKey: "title") as? String, "Test Document", "Document title should match")
    }
    
    func testDocumentSidebarInitialValues() {
        // Get initial values from test document
        let title = testDocument.value(forKey: "title") as? String ?? ""
        let comments = getCommentsContent(from: testDocument)
        
        // Verify the values
        XCTAssertEqual(title, "Test Document", "Document title should match")
        if hasProperty("comments", in: testDocument.entity) {
            XCTAssertEqual(comments, "Test Comments", "Document comments should match")
        }
    }
    
    func testDocumentDisplayInitialValues() {
        // Create test PDF document if PDF data exists
        if let pdfData = getPDFData(from: testDocument) {
            let pdfDocument = PDFDocument(data: pdfData)
            XCTAssertNotNil(pdfDocument, "PDF document should be created from data")
        } else {
            // Skip test if no PDF data
            print("Skipping PDF document test - no PDF data available in the entity")
        }
    }
    
    // MARK: - Window Management Tests
    
    func testWindowControllerCreation() {
        // Create a window controller
        let controller = DocumentWindowController()
        
        // Verify initial state
        XCTAssertNil(controller.window, "Window should be nil initially")
        XCTAssertNil(controller.observer, "Observer should be nil initially")
    }
    
    // MARK: - Document Type Tests
    
    func testVectorPDFViewing() {
        // Create PDF data directly
        guard let pdfData = getPDFData() else {
            XCTFail("Failed to create PDF data")
            return
        }
        
        // Verify PDF data is not empty
        XCTAssertFalse(pdfData.isEmpty, "PDF data should not be empty")
        
        // Create a PDFDocument to verify the data is valid
        let pdfDocument = PDFDocument(data: pdfData)
        XCTAssertNotNil(pdfDocument, "PDF document should not be nil")
        
        // Verify basic PDF properties
        XCTAssertEqual(pdfDocument?.pageCount, 1, "PDF should have 1 page")
    }
    
    // Helper to determine if a document is a PDF
    private func isPDF(document: NSManagedObject) -> Bool {
        guard let documentData = document.value(forKey: "documentData") as? Data else { return false }
        
        let pdfSignature = "%PDF"
        if let dataString = String(data: documentData.prefix(10), encoding: .ascii),
           dataString.hasPrefix(pdfSignature) {
            return true
        }
        return false
    }
    
    // Helper to determine if a document is a scanned PDF
    private func isScannedPDF(document: NSManagedObject) -> Bool {
        guard let pdfDocument = createPDFDocument(from: document) else { return false }
        
        // Check first 3 pages (or fewer if document has fewer pages)
        let pagesToCheck = min(3, pdfDocument.pageCount)
        var totalTextCharacters = 0
        
        for i in 0..<pagesToCheck {
            guard let page = pdfDocument.page(at: i) else { continue }
            
            // Check if the page contains selectable text
            if let pageContent = page.string {
                totalTextCharacters += pageContent.count
            }
            
            // Check for images in the page
            if hasLargeImage(page) {
                return true // If the page is dominated by an image, it's likely scanned
            }
        }
        
        // If we get here with little text, it's likely a scanned/image-based PDF
        return totalTextCharacters < 100
    }
    
    // Helper to create a PDFDocument from a Document entity
    private func createPDFDocument(from document: NSManagedObject) -> PDFDocument? {
        guard let documentData = document.value(forKey: "documentData") as? Data else { return nil }
        return PDFDocument(data: documentData)
    }
    
    private func getPDFData() -> Data? {
        // Create a PDF with text
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        
        let pdfData = NSMutableData()
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData)!, mediaBox: &mediaBox, nil) else {
            return nil
        }
        
        // Start a new page
        pdfContext.beginPage(mediaBox: &mediaBox)
        
        // Add text to make it a vector PDF with text content
        let text = "Test PDF Document with Vector Text"
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Position text in center of page
        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let xPosition = (mediaBox.width - textWidth) / 2
        let yPosition = mediaBox.height / 2
        
        // Draw the text
        pdfContext.textPosition = CGPoint(x: xPosition, y: yPosition)
        CTLineDraw(line, pdfContext)
        
        // End the page and PDF context
        pdfContext.endPage()
        pdfContext.closePDF()
        
        return pdfData as Data
    }
    
    func testScannedPDFViewing() {
        // Create a scanned PDF (image-based without text)
        let pdfDocument = PDFDocument()
        
        // Use a larger image to create a more realistic scan
        let scanImage = createTestImage(size: NSSize(width: 2000, height: 2800), withText: false)
        
        // Create a page from the image (simulating a scan)
        guard let pdfPage = PDFPage(image: scanImage) else {
            XCTFail("Failed to create PDF page from scan image")
            return
        }
        
        pdfDocument.insert(pdfPage, at: 0)
        
        // Add explicit metadata to match scanner detection patterns
        let attributes: [PDFDocumentAttribute: Any] = [
            .producerAttribute: "Canon Scanner App 2.0",
            .creatorAttribute: "NAPS2 Scanning Software",
            .titleAttribute: "Scan001",
            .subjectAttribute: "Scanned Document from Canon MF4770n",
            .keywordsAttribute: ["scan", "document", "image", "paper"],
            .authorAttribute: "Scanner User"
        ]
        pdfDocument.documentAttributes = attributes
        
        // Verify attributes were set correctly on the PDF document
        XCTAssertEqual(pdfDocument.documentAttributes?[PDFDocumentAttribute.producerAttribute] as? String, 
                      "Canon Scanner App 2.0", "Producer attribute should be set correctly")
        
        XCTAssertEqual(pdfDocument.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String, 
                      "NAPS2 Scanning Software", "Creator attribute should be set correctly")
        
        // Verify the document is detected as a scanned PDF using the isScannedPDF method
        XCTAssertTrue(pdfDocument.isScannedPDF(), "PDF should be detected as a scanned document")
        
        // Verify basic PDF properties
        XCTAssertEqual(pdfDocument.pageCount, 1, "PDF should have 1 page")
        XCTAssertTrue(hasLargeImage(pdfDocument.page(at: 0)!), "PDF page should be detected as having a large image")
    }
    
    // Helper method to check for large images (matching the one in PDFDocument extension)
    private func hasLargeImage(_ page: PDFPage) -> Bool {
        // Try to render to analyze bitmap coverage
        let thumbnail = page.thumbnail(of: CGSize(width: 300, height: 300), for: .mediaBox)
        
        // Check if image takes up significant area of the page
        if let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let imageRep = NSBitmapImageRep(cgImage: cgImage)
            
            // Count non-white pixels
            var nonWhitePixels = 0
            let totalPixels = imageRep.pixelsWide * imageRep.pixelsHigh
            
            for x in 0..<imageRep.pixelsWide {
                for y in 0..<imageRep.pixelsHigh {
                    if let color = imageRep.colorAt(x: x, y: y) {
                        // If pixel is not close to white
                        if color.brightnessComponent < 0.9 {
                            nonWhitePixels += 1
                        }
                    }
                }
            }
            
            // If more than 15% of pixels are non-white, likely an image-heavy document
            let nonWhiteRatio = Double(nonWhitePixels) / Double(totalPixels)
            if nonWhiteRatio > 0.15 {
                return true
            }
        }
        
        return false
    }
    
    // Helper to write logs to a file
    private func writeLog(_ message: String) {
        let logURL = URL(fileURLWithPath: "/Users/seanwhite/Desktop/pdf_test_log.txt")
        do {
            var existingText = ""
            if FileManager.default.fileExists(atPath: logURL.path) {
                existingText = try String(contentsOf: logURL, encoding: .utf8)
            }
            
            let newContent = existingText + message + "\n"
            try newContent.write(to: logURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing to log file: \(error)")
        }
    }
    
    func testImageDocumentViewing() {
        // Test JPEG format
        let jpegImage = createTestImage(size: NSSize(width: 800, height: 600))
        let jpegData = jpegImage.jpegRepresentation
        XCTAssertNotNil(jpegData, "JPEG data should be created")
        
        let documentEntityJPEG = NSEntityDescription.entity(forEntityName: "Document", in: viewContext)!
        let jpegDoc = NSManagedObject(entity: documentEntityJPEG, insertInto: viewContext)
        jpegDoc.setValue(UUID(), forKey: "id")
        jpegDoc.setValue("Test JPEG", forKey: "title")
        jpegDoc.setValue("test_image.jpg", forKey: "fileName")
        
        // Store the image data
        if hasProperty("imageData", in: documentEntityJPEG) {
            jpegDoc.setValue(jpegData, forKey: "imageData")
        } else if hasProperty("documentData", in: documentEntityJPEG) {
            jpegDoc.setValue(jpegData, forKey: "documentData")
        }
        
        // Test PNG format
        let pngImage = createTestImage(size: NSSize(width: 1200, height: 800))
        let pngData = pngImage.pngRepresentation
        XCTAssertNotNil(pngData, "PNG data should be created")
        
        let documentEntityPNG = NSEntityDescription.entity(forEntityName: "Document", in: viewContext)!
        let pngDoc = NSManagedObject(entity: documentEntityPNG, insertInto: viewContext)
        pngDoc.setValue(UUID(), forKey: "id")
        pngDoc.setValue("Test PNG", forKey: "title")
        pngDoc.setValue("test_image.png", forKey: "fileName")
        
        // Store the image data
        if hasProperty("imageData", in: documentEntityPNG) {
            pngDoc.setValue(pngData, forKey: "imageData")
        } else if hasProperty("documentData", in: documentEntityPNG) {
            pngDoc.setValue(pngData, forKey: "documentData")
        }
        
        // Test JPEG properties
        XCTAssertNotNil(jpegDoc, "JPEG document should be created")
        XCTAssertTrue(isImageDocument(jpegDoc), "Should be detected as an image document")
        
        if let imageData = getImageData(from: jpegDoc),
           let image = NSImage(data: imageData) {
            XCTAssertNotNil(image, "Should be able to create image from data")
            XCTAssertEqual(Int(image.size.width), 800, "Image width should match")
            XCTAssertEqual(Int(image.size.height), 600, "Image height should match")
            
            // Test image properties
            let hasSize = image.size.width > 0 && image.size.height > 0
            XCTAssertTrue(hasSize, "Image should have valid dimensions")
            
            if let tiffRep = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffRep) {
                XCTAssertTrue(bitmap.pixelsWide > 0, "Image should have valid pixel width")
                XCTAssertTrue(bitmap.pixelsHigh > 0, "Image should have valid pixel height")
            }
        } else {
            XCTFail("Failed to extract image data from JPEG document")
        }
        
        // Test PNG properties
        XCTAssertNotNil(pngDoc, "PNG document should be created")
        XCTAssertTrue(isImageDocument(pngDoc), "Should be detected as an image document")
        
        if let imageData = getImageData(from: pngDoc),
           let image = NSImage(data: imageData) {
            XCTAssertNotNil(image, "Should be able to create image from data")
            XCTAssertEqual(Int(image.size.width), 1200, "Image width should match")
            XCTAssertEqual(Int(image.size.height), 800, "Image height should match")
            
            // Test image properties
            let hasSize = image.size.width > 0 && image.size.height > 0
            XCTAssertTrue(hasSize, "Image should have valid dimensions")
            
            if let tiffRep = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffRep) {
                XCTAssertTrue(bitmap.pixelsWide > 0, "Image should have valid pixel width")
                XCTAssertTrue(bitmap.pixelsHigh > 0, "Image should have valid pixel height")
            }
        } else {
            XCTFail("Failed to extract image data from PNG document")
        }
        
        // Test filename-based detection
        if hasProperty("fileName", in: documentEntityJPEG) {
            XCTAssertTrue(jpegDoc.value(forKey: "fileName") as! String == "test_image.jpg", "Filename should be preserved")
        }
        
        if hasProperty("fileName", in: documentEntityPNG) {
            XCTAssertTrue(pngDoc.value(forKey: "fileName") as! String == "test_image.png", "Filename should be preserved")
        }
    }
    
    func testMultiPageDocumentNavigation() {
        // Create a multi-page PDF document
        let pageSize = NSSize(width: 612, height: 792)
        let pdfDocument = PDFDocument()
        
        // Create three pages
        for pageNumber in 1...3 {
            // Create a PDF page for each
            let pdfData = NSMutableData()
            var mediaBoxRect = NSRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
            
            guard let dataConsumer = CGDataConsumer(data: pdfData as CFMutableData),
                  let context = CGContext(consumer: dataConsumer, mediaBox: &mediaBoxRect, nil) else {
                XCTFail("Could not create PDF context for page \(pageNumber)")
                continue
            }
            
            var pageRect = mediaBoxRect
            context.beginPage(mediaBox: &pageRect)
            
            // Draw page number text
            let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
            let text = "Page \(pageNumber)"
            let attributedString = NSAttributedString(string: text, attributes: [.font: font])
            let line = CTLineCreateWithAttributedString(attributedString)
            
            // Position the text in the center of the page
            context.textPosition = CGPoint(x: pageSize.width / 2 - 50, y: pageSize.height / 2)
            CTLineDraw(line, context)
            
            context.endPage()
            context.closePDF()
            
            // Create a PDF document from the page data
            if let tempPDF = PDFDocument(data: pdfData as Data),
               let page = tempPDF.page(at: 0) {
                pdfDocument.insert(page, at: pageNumber - 1)
            }
        }
        
        // Set up test document with the multi-page PDF
        let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: viewContext)!
        let multiPageDoc = NSManagedObject(entity: documentEntity, insertInto: viewContext)
        multiPageDoc.setValue(UUID(), forKey: "id")
        multiPageDoc.setValue("Multi-Page PDF Test", forKey: "title")
        
        // Store the PDF data
        if hasProperty("pdfData", in: documentEntity) {
            multiPageDoc.setValue(pdfDocument.dataRepresentation(), forKey: "pdfData")
        } else if hasProperty("documentData", in: documentEntity) {
            multiPageDoc.setValue(pdfDocument.dataRepresentation(), forKey: "documentData")
        }
        
        // Test PDF properties
        XCTAssertNotNil(multiPageDoc, "Multi-page PDF document should be created")
        
        // Verify PDF data
        if let pdfData = getPDFData(from: multiPageDoc),
           let testPDF = PDFDocument(data: pdfData) {
            // Test navigation between pages
            XCTAssertEqual(testPDF.pageCount, 3, "PDF should have three pages")
            
            // Check content of each page
            for i in 0..<testPDF.pageCount {
                if let page = testPDF.page(at: i),
                   let content = page.string {
                    XCTAssertTrue(content.contains("Page \(i+1)"), "Page \(i+1) should contain its page number")
                }
            }
        } else {
            XCTFail("Failed to extract PDF data from multi-page document")
        }
    }
    
    // MARK: - Helper Methods
    
    // Helper to check if document is an image
    private func isImageDocument(_ document: NSManagedObject) -> Bool {
        // Check for image properties
        let imageProps = ["imageData", "image", "originalImage"]
        for prop in imageProps {
            if hasProperty(prop, in: document.entity),
               let data = document.value(forKey: prop) as? Data,
               !data.isEmpty,
               NSImage(data: data) != nil {
                return true
            }
        }
        
        // Check filename
        if hasProperty("fileName", in: document.entity),
           let fileName = document.value(forKey: "fileName") as? String {
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff"]
            if imageExtensions.contains(where: { fileName.lowercased().hasSuffix(".\($0)") }) {
                return true
            }
        }
        
        return false
    }
    
    // Helper to get image data from document
    private func getImageData(from document: NSManagedObject) -> Data? {
        let imageProps = ["imageData", "image", "originalImage", "documentData", "data"]
        for prop in imageProps {
            if hasProperty(prop, in: document.entity),
               let data = document.value(forKey: prop) as? Data,
               !data.isEmpty {
                return data
            }
        }
        return nil
    }
    
    // Helper to create test image with text
    private func createTestImage(size: NSSize = NSSize(width: 800, height: 600), withText: Bool = true) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Create gradient background
        let gradient = NSGradient(colors: [NSColor.blue, NSColor.purple])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        // Draw some text
        let text = "Test Image" as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 36),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: textAttributes)
        let textPoint = NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )
        text.draw(at: textPoint, withAttributes: textAttributes)
        
        image.unlockFocus()
        return image
    }
}

//
//  ContentView.swift
//  ScanVaultAI for Mac OS
//
//  Created by SEAN WHITE on 3/28/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import CoreData
import Combine

// Make sure you're importing the Core Data models - add at the top of the file
// If you're using the .xcdatamodeld file directly, this should be enough

// Add this extension at the top of the file to reference your Core Data entities
extension NSManagedObject {
    // This is a convenience initializer
    static func createDocument(in context: NSManagedObjectContext, title: String, pdfData: Data) -> NSManagedObject {
        let newDocument = NSEntityDescription.insertNewObject(forEntityName: "Document", into: context)
        newDocument.setValue(UUID(), forKey: "id")
        newDocument.setValue(Date(), forKey: "createdAt")
        newDocument.setValue(title, forKey: "title")
        newDocument.setValue(pdfData, forKey: "pdfData")
        
        // Extract text
        var pdfText = ""
        if let pdfDocument = PDFDocument(data: pdfData) {
            for i in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: i), let text = page.string {
                    pdfText += text + "\n"
                }
            }
        }
        newDocument.setValue(pdfText, forKey: "text")
        
        return newDocument
    }
}

struct ContentView: View {
    @State private var documents: [NSManagedObject] = []
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            FoldersView()
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem {
                Button(action: importPDF) {
                    Label("Import PDF", systemImage: "plus")
                }
            }
        }
    }
    
    func importPDF() {
        // Show PDF import dialog - implements file picker
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.pdf]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                importPDFFromURL(url)
            }
        }
    }
    
    func importPDFFromURL(_ url: URL) {
        do {
            let pdfData = try Data(contentsOf: url)
            if let pdfDocument = PDFDocument(data: pdfData) {
                let _ = NSManagedObject.createDocument(in: viewContext, title: url.lastPathComponent, pdfData: pdfData)
                
                // Extract text and save...
                try viewContext.save()
                print("PDF imported: \(url.lastPathComponent)")
            }
        } catch {
            print("Error importing PDF: \(error)")
        }
    }
}

struct PDFImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isShowingImporter = false
    
    var body: some View {
        VStack {
            Button("Import PDF") {
                isShowingImporter = true
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: true
        ) { result in
            do {
                let fileURLs = try result.get()
                importPDFs(from: fileURLs)
            } catch {
                print("Error selecting PDFs: \(error.localizedDescription)")
            }
        }
    }
    
    func importPDFs(from urls: [URL]) {
        for url in urls {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access the file")
                continue
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                // Read PDF data
                let pdfData = try Data(contentsOf: url)
                
                // Create PDF document to extract info
                if let pdfDocument = PDFDocument(data: pdfData) {
                    // Save to Core Data
                    saveDocument(pdfData: pdfData, pdfDocument: pdfDocument, fileName: url.lastPathComponent)
                }
            } catch {
                print("Error reading PDF: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveDocument(pdfData: Data, pdfDocument: PDFDocument, fileName: String) {
        let newDocument = NSManagedObject.createDocument(in: viewContext, title: fileName, pdfData: pdfData)
        
        // Extract and set text content for searching
        let pdfText = extractTextFromPDF(pdfDocument)
        newDocument.setValue(pdfText, forKey: "text")
        
        // Store PDF data - consider chunking for large files
        if pdfData.count <= 10_000_000 { // ~10MB
            newDocument.setValue(pdfData, forKey: "pdfData")
        } else {
            // Handle large files
            handleLargeFile(pdfData: pdfData, document: newDocument)
        }
        
        // Save the context
        do {
            try viewContext.save()
            print("Successfully saved document: \(fileName)")
        } catch {
            print("Error saving PDF to Core Data: \(error.localizedDescription)")
        }
    }
    
    private func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String {
        var fullText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        return fullText
    }
    
    private func handleLargeFile(pdfData: Data, document: NSManagedObject) {
        // Create a temporary file URL in the app's cache directory
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cacheDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        
        do {
            // Write the PDF data to the temporary file
            try pdfData.write(to: fileURL)
            
            // Create a CKAsset from the file URL
            document.setValue(fileURL.path, forKey: "pdfAsset")
        } catch {
            print("Error handling large file: \(error.localizedDescription)")
        }
    }
}

struct DragDropPDFView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isLoading = false
    @State private var dragOver = false
    
    var body: some View {
        VStack {
            // Your other UI elements...
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(dragOver ? Color.blue : Color.gray, lineWidth: 2)
                    .frame(height: 150)
                    .background(Color.gray.opacity(0.1))
                
                VStack {
                    Image(systemName: "doc.fill")
                        .font(.largeTitle)
                    Text("Drag and Drop PDFs Here")
                        .font(.headline)
                    Text("Or click to browse files")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .onDrop(of: [UTType.pdf.identifier], isTargeted: $dragOver) { providers in
                Task {
                    await handleDrop(providers: providers)
                }
                return true
            }
            .onTapGesture {
                // Show file picker
                // This would call the fileImporter code from example 1
            }
            
            if isLoading {
                ProgressView("Importing documents...")
            }
        }
    }
    
    @MainActor
    func handleDrop(providers: [NSItemProvider]) {
        isLoading = true
        
        Task {
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    do {
                        // Explicitly create a loadable copy
                        let providerCopy = provider
                        
                        // Load item in a detached task
                        let url = try await Task.detached {
                            return try await providerCopy.loadItem(forTypeIdentifier: UTType.pdf.identifier) as! URL
                        }.value
                        
                        let pdfData = try Data(contentsOf: url)
                        
                        if let pdfDocument = PDFDocument(data: pdfData) {
                            // Back on the main actor
                            await MainActor.run {
                                saveDocument(pdfData: pdfData, pdfDocument: pdfDocument, fileName: url.lastPathComponent)
                                isLoading = false
                            }
                        }
                    } catch {
                        print("Error loading PDF from drop: \(error.localizedDescription)")
                        await MainActor.run {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    private func saveDocument(pdfData: Data, pdfDocument: PDFDocument, fileName: String) {
        let newDocument = NSManagedObject.createDocument(in: viewContext, title: fileName, pdfData: pdfData)
        
        // Extract and set text content for searching
        let pdfText = extractTextFromPDF(pdfDocument)
        newDocument.setValue(pdfText, forKey: "text")
        
        // Store PDF data - consider chunking for large files
        if pdfData.count <= 10_000_000 { // ~10MB
            newDocument.setValue(pdfData, forKey: "pdfData")
        } else {
            // Handle large files
            handleLargeFile(pdfData: pdfData, document: newDocument)
        }
        
        // Save the context
        do {
            try viewContext.save()
            print("Successfully saved document: \(fileName)")
        } catch {
            print("Error saving PDF to Core Data: \(error.localizedDescription)")
        }
    }
    
    private func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String {
        var fullText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        return fullText
    }
    
    private func handleLargeFile(pdfData: Data, document: NSManagedObject) {
        // Create a temporary file URL in the app's cache directory
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cacheDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        
        do {
            // Write the PDF data to the temporary file
            try pdfData.write(to: fileURL)
            
            // Create a CKAsset from the file URL
            document.setValue(fileURL.path, forKey: "pdfAsset")
        } catch {
            print("Error handling large file: \(error.localizedDescription)")
        }
    }
}

struct PDFPreviewView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Update if needed
    }
}

// Alternative version that uses Data directly
struct PDFDataView: NSViewRepresentable {
    let pdfData: Data
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Update if needed
    }
}

#Preview {
    ContentView()
}

import SwiftUI

// MARK: - About View
struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image("ScanVaultLogoforAppTM")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220)
                        .padding(.top, 20)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("ScanVault is an iPhone application designed to facilitate quick document scanning using Apple's native document scanner. Users can organize their scanned documents using a flexible tagging and folder system, managed within the app's Vault.")
                            .font(.body)
                        
                        Text("Features")
                            .font(.headline)
                            .padding(.top)
                        
                        Feature(icon: "doc.text.viewfinder", title: "Quick Scanning", description: "Scan documents with a single tap using Apple's native scanner.")
                        
                        Feature(icon: "tag", title: "Tags & Folders", description: "Organize your documents with a flexible tagging and folder system.")
                        
                        Feature(icon: "magnifyingglass", title: "Powerful Search", description: "Easily find documents by title, date, tags, or folders.")
                        
                        Text("Advanced Features (Premium)")
                            .font(.headline)
                            .padding(.top)
                        
                        Feature(icon: "text.viewfinder", title: "OCR Document Scanning", description: "ScanVault uses advanced Optical Character Recognition (OCR) technology to extract text from your documents. This allows you to search through the content of your documents even if they're images or PDFs.")
                        
                        Feature(icon: "magnifyingglass.circle", title: "Full Text Search", description: "Find any document instantly with powerful full-text search. ScanVault indexes all the text in your documents, allowing you to search for specific words or phrases contained anywhere in your documents.")
                        
                        Feature(icon: "brain", title: "Adaptive Learning", description: "ScanVault learns from your document organization habits to provide increasingly accurate suggestions for titles, folders, and tags over time.")
                        
                        Feature(icon: "icloud", title: "iCloud Sync", description: "Premium subscribers can sync their documents across all their devices with iCloud, ensuring access to important documents wherever you are.")
                        
                        // New Privacy Section
                        Text("Your Data Privacy")
                            .font(.headline)
                            .padding(.top)
                        
                        HStack(alignment: .top, spacing: 15) {
                            Image(systemName: "lock.shield")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You Own Your Data")
                                    .font(.headline)
                                
                                Text("ScanVault stores your documents in your personal iCloud Private Database. This means you maintain complete ownership and control of your data.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        HStack(alignment: .top, spacing: 15) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Private & Secure")
                                    .font(.headline)
                                
                                Text("Your documents are stored in your personal iCloud account, encrypted with your credentials. Our app cannot access your data without your permission.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        HStack(alignment: .top, spacing: 15) {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your iCloud Storage")
                                    .font(.headline)
                                
                                Text("Documents are stored in your iCloud account and count toward your personal storage quota. This ensures your data remains under your control, even if you discontinue using ScanVault.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if let expandedLearningDescription = expandedAdaptiveLearningDescription {
                            Text("How Adaptive Learning Works")
                                .font(.headline)
                                .padding(.top)
                            
                            Text(expandedLearningDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("© \(Calendar.current.component(.year, from: Date())) ScanVault. All rights reserved.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("About ScanVault")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var expandedAdaptiveLearningDescription: String? {
        """
        ScanVault incorporates an innovative Adaptive Learning system that learns from your document organization habits to provide increasingly accurate suggestions.

        How it works:
        • When you scan a document, AI analyzes the content to suggest a title, folder, and relevant tags.
        • If you modify these suggestions, ScanVault records the difference between the AI suggestion and your final choice.
        • Over time, the system recognizes patterns in your preferences, such as how you name certain types of documents or which folders you prefer for specific content.
        • These learned patterns are used to enhance future suggestions, making them align better with your personal organization style.
        
        For example, if you consistently move medical documents from "Personal" to "Medical" folders, ScanVault will learn to suggest "Medical" directly for similar documents in the future. The more you use ScanVault, the smarter it becomes at predicting how you want to organize your documents.
        """
    }
}

// MARK: - Feature Component
struct Feature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 
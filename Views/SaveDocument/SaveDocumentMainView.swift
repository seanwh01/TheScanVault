import SwiftUI
import CoreData
import Combine

// Core implementation of the SaveDocument view
// This maintains UI consistency with DocumentDetailView for folder and tag management
extension Views_SaveDocument {
    struct SaveDocumentMainView: View {
        @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
        @Environment(\.presentationMode) private var presentationMode
        @EnvironmentObject private var appServices: AppServices
        @EnvironmentObject private var subscriptionManager: SubscriptionManager
        
        // State variables
        @State private var documentTitle: String = ""
        @State private var selectedFolder: UUID? = nil
        @State private var selectedFolderName: String = ""
        @State private var tagsText: String = ""
        @State private var comments: String = ""
        @State private var newTagText: String = ""
        @State private var pendingTagId: UUID? = nil
        @State private var showActivityIndicator: Bool = false
        @State private var showAIConfirmation: Bool = false
        @State private var showTagConfirmation: Bool = false
        @State private var showFolderConfirmation: Bool = false
        @State private var showTagEditSheet: Bool = false
        @State private var showFolderEditSheet: Bool = false
        @State private var isDismissingView: Bool = false
        
        var body: some View {
            ZStack {
                NavigationView {
                    Form {
                        SDV_TitleView(viewModel: viewModel, documentTitle: $documentTitle, showAIConfirmation: $showAIConfirmation)
                        
                        SDV_FolderView(viewModel: viewModel, 
                                    selectedFolder: $selectedFolder, 
                                    selectedFolderName: $selectedFolderName, 
                                    showFolderConfirmation: $showFolderConfirmation,
                                    showFolderEditSheet: $showFolderEditSheet)
                        
                        SDV_TagsView(viewModel: viewModel, 
                                   tagsText: $tagsText,
                                   showTagConfirmation: $showTagConfirmation,
                                   showTagEditSheet: $showTagEditSheet)
                        
                        SDV_CommentsView(viewModel: viewModel, comments: $comments)
                        
                        Section(header: Text("AI ANALYSIS")) {
                            SDV_AIAnalysisView(viewModel: viewModel)
                        }
                    }
                    .navigationBarTitle("Save Document", displayMode: .inline)
                    .navigationBarItems(
                        leading: leadingBarButton,
                        trailing: trailingBarButton
                    )
                }
                
                // Overlay indicators and progress displays
                if showActivityIndicator {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                        
                        Text("Saving document...")
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                if showAIConfirmation {
                    ZStack {
                        Color.white
                            .frame(width: 300, height: 60)
                            .cornerRadius(8)
                            .shadow(radius: 10)
                        
                        Text("AI Analysis Complete")
                            .foregroundColor(.green)
                            .padding()
                    }
                }
                
                if showTagConfirmation {
                    ZStack {
                        Color.white
                            .frame(width: 300, height: 60)
                            .cornerRadius(8)
                            .shadow(radius: 10)
                        
                        Text("Tag Added")
                            .foregroundColor(.green)
                            .padding()
                    }
                }
                
                if showFolderConfirmation {
                    ZStack {
                        Color.white
                            .frame(width: 300, height: 60)
                            .cornerRadius(8)
                            .shadow(radius: 10)
                        
                        Text("Folder Selected")
                            .foregroundColor(.green)
                            .padding()
                    }
                }
            }
            .onAppear(perform: syncWithViewModel)
            .onAppear {
                // Set up notification observer for hiding folder confirmation
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("HideFolderConfirmation"),
                    object: nil,
                    queue: .main
                ) { _ in
                    withAnimation {
                        self.showFolderConfirmation = false
                    }
                }
                
                // Set up notification observer for hiding tag confirmation
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("HideTagConfirmation"),
                    object: nil,
                    queue: .main
                ) { _ in
                    withAnimation {
                        self.showTagConfirmation = false
                    }
                }
                
                // Set up notification observer for hiding AI confirmation
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("HideAIConfirmation"),
                    object: nil,
                    queue: .main
                ) { _ in
                    withAnimation {
                        self.showAIConfirmation = false
                    }
                }
            }
            .onDisappear {
                // Remove notification observers when view disappears
                NotificationCenter.default.removeObserver(
                    self,
                    name: Notification.Name("HideFolderConfirmation"),
                    object: nil
                )
                
                NotificationCenter.default.removeObserver(
                    self,
                    name: Notification.Name("HideTagConfirmation"),
                    object: nil
                )
                
                NotificationCenter.default.removeObserver(
                    self,
                    name: Notification.Name("HideAIConfirmation"),
                    object: nil
                )
            }
            .sheet(isPresented: $showTagEditSheet) {
                SDV_TagEntryView(viewModel: viewModel)
                .environmentObject(appServices)
                .onDisappear(perform: syncWithViewModel)
            }
            .sheet(isPresented: $showFolderEditSheet) {
                SDV_FolderEditView(viewModel: viewModel)
                .environmentObject(appServices)
                .onDisappear(perform: syncWithViewModel)
            }
            .onChange(of: isDismissingView) { newValue in
                if newValue {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        // MARK: - Toolbar Content
        
        private var leadingBarButton: some View {
            Button("Cancel") {
                self.isDismissingView = true
            }
        }
        
        private var trailingBarButton: some View {
            Button("Save") {
                saveDocument()
            }
            .opacity(showActivityIndicator ? 0.0 : 1.0)
            .disabled(showActivityIndicator)
        }
        
        // MARK: - Actions
        
        // Save the document
        private func saveDocument() {
            // Show activity indicator during save operation
            showActivityIndicator = true
            
            // Ensure tags and folder are synced before saving
            SDV_TagsHelpers.syncTagsWithViewModel(viewModel: viewModel)
            SDV_FolderHelpers.syncFolderSelection(
                viewModel: viewModel,
                currentFolder: &selectedFolder,
                folderName: &selectedFolderName
            )
            
            // Process the save operation on a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                // Call saveDocument without trailing closure
                viewModel.saveDocument()
                
                // Handle completion on the main thread after a short delay
                DispatchQueue.main.async {
                    // Give the save operation time to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showActivityIndicator = false
                        
                        // Since we don't have a direct success callback, assume success and dismiss
                        // This matches the behavior in the original SaveDocumentView
                        print("✅ Document save operation completed")
                        isDismissingView = true
                    }
                }
            }
        }
        
        // MARK: - State Synchronization
        
        // Function to sync the view state with the view model
        func syncWithViewModel() {
            if !viewModel.documentTitle.isEmpty && documentTitle != viewModel.documentTitle {
                documentTitle = viewModel.documentTitle
                print("📝 Updated title to: \(documentTitle)")
            }
            
            // Sync folder selection using the helper
            SDV_FolderHelpers.syncFolderSelection(
                viewModel: viewModel,
                currentFolder: &selectedFolder,
                folderName: &selectedFolderName
            )
            
            // Sync tags using the helpers - critical for tag deletion bug fix
            if !viewModel.metadataManager.selectedTagIds.isEmpty { 
                print("🏷️ Syncing \(viewModel.metadataManager.selectedTagIds.count) tag IDs from ViewModel")
                
                let newTagsText = viewModel.getTagsTextFromSelectedIds()
                
                let shouldUpdate = tagsText != newTagsText || tagsText.isEmpty
                
                if shouldUpdate {
                    print("🏷️ Updating tags text from: '\(tagsText)' to: '\(newTagsText)'")
                    tagsText = newTagsText
                }
            } else if !tagsText.isEmpty && viewModel.metadataManager.selectedTagIds.isEmpty {
                tagsText = ""
            }
            
            if comments != viewModel.comments {
                comments = viewModel.comments
            }
        }
    }
}

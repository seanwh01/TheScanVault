import SwiftUI
import CoreData
import Combine

// MARK: - SaveDocumentView
// Proxy implementation that forwards to the refactored components
// This preserves backward compatibility while maintaining all critical fixes

struct SaveDocumentView: View {
    // MARK: - Environment
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appServices: AppServices
    
    // MARK: - View Model
    @ObservedObject var viewModel: ViewModels_Scan.ScanViewModel
    
    // MARK: - Body
    
    var body: some View {
        // Forward to the refactored implementation with required environment objects
        Views_SaveDocument.SDV_MainView(viewModel: viewModel)
            .environmentObject(appServices)
            .environmentObject(subscriptionManager)
            .onAppear {
                print("📄 [SaveDocumentView Proxy] Forwarding to refactored implementation")
                syncWithViewModel()
            }
    }
    
    // MARK: - State Synchronization
    
    // This function is preserved for backward compatibility
    // It's crucial for the tag handling bug fix mentioned in the memories
    func syncWithViewModel() {
        print("💫 [SaveDocumentView Proxy] Synchronizing tags with ViewModel...")
        print("Tags before sync: VM has \(viewModel.selectedTagIds.count) tags, Manager has \(viewModel.metadataManager.selectedTagIds.count) tags")
        
        // CRITICAL: Always update the viewModel from the metadataManager (source of truth)
        // This is the pattern that fixed the tag deletion bug mentioned in the memories
        viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
        
        // Force UI updates on main thread
        DispatchQueue.main.async {
            viewModel.objectWillChange.send()
        }
        
        print("Tags after sync: VM has \(viewModel.selectedTagIds.count) tags, Manager has \(viewModel.metadataManager.selectedTagIds.count) tags")
    }
    
    // MARK: - Tag Selection Logic
    
    // Critical function for removing a tag - uses the correct tag removal pattern 
    // that prevents the tag deletion bug mentioned in the memories
    func removeTag(tagId: UUID) {
        print("⚠️ [SaveDocumentView Proxy] Removing tag ID: \(tagId)")
        print("⚠️ Before removal: selected tags = \(viewModel.metadataManager.selectedTagIds.count)")
        
        // CRITICAL: This pattern must be preserved for proper tag deletion handling
        // It uses metadataManager.toggleTagSelection as the single source of truth
        viewModel.metadataManager.toggleTagSelection(tagId)
        
        // Force UI updates on main thread
        DispatchQueue.main.async {
            // Critical: Update view model from metadata manager
            viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
            
            // Log after operation 
            print("✅ After removal: selected tags = \(viewModel.metadataManager.selectedTagIds.count)")
            
            // Force view to update
            viewModel.objectWillChange.send()
        }
    }
}

import Foundation
import CoreData

/// Utility to help identify and fix keychain-related issues
class KeychainFixUtility {
    static let shared = KeychainFixUtility()
    
    private init() {}
    
    /// A centralized method to handle folder storage with proper error handling
    /// Use this method instead of direct keychain access for folder information
    /// - Parameters:
    ///   - documentId: Document ID in any format (String, UUID, etc)
    ///   - folder: Folder name (can be nil)
    ///   - folderId: Folder UUID (can be nil)
    /// - Returns: Success status
    func storeFolderInfo(documentId: Any?, folder: String?, folderId: UUID?) -> Bool {
        // Convert documentId to string
        var documentIdString = ""
        
        // Handle various document ID types
        if let stringValue = documentId as? String {
            documentIdString = stringValue
        } else if let uuidValue = documentId as? UUID {
            documentIdString = uuidValue.uuidString
        } else if let nsStringValue = documentId as? NSString {
            documentIdString = nsStringValue as String
        } else if let anyObject = documentId {
            // Convert any object to string representation
            documentIdString = String(describing: anyObject)
        }
        
        // Store folder ID
        let folderIdSuccess = KeychainManager.shared.saveAPIKey(
            key: folderId?.uuidString ?? "",
            service: "TheScanVault.Folders",
            account: "\(documentIdString)_FolderID"
        )
        
        // Store folder name
        let folderNameSuccess = KeychainManager.shared.saveAPIKey(
            key: folder ?? "",
            service: "TheScanVault.Folders",
            account: "\(documentIdString)_FolderName"
        )
        
        return folderIdSuccess && folderNameSuccess
    }
    
    /// Retrieves folder information safely
    /// - Parameter documentId: Document ID in any format
    /// - Returns: A tuple with folder ID and name
    func getFolderInfo(documentId: Any?) -> (folderId: UUID?, folderName: String?) {
        var documentIdString = ""
        
        // Handle various document ID types
        if let stringValue = documentId as? String {
            documentIdString = stringValue
        } else if let uuidValue = documentId as? UUID {
            documentIdString = uuidValue.uuidString
        } else if let nsStringValue = documentId as? NSString {
            documentIdString = nsStringValue as String
        } else if let anyObject = documentId {
            // Convert any object to string representation
            documentIdString = String(describing: anyObject)
        }
        
        // Get folder ID
        let folderIdString = KeychainManager.shared.getAPIKey(
            service: "TheScanVault.Folders",
            account: "\(documentIdString)_FolderID"
        )
        
        // Convert to UUID if possible
        var folderId: UUID? = nil
        if let idStr = folderIdString, !idStr.isEmpty {
            folderId = UUID(uuidString: idStr)
        }
        
        // Get folder name
        let folderName = KeychainManager.shared.getAPIKey(
            service: "TheScanVault.Folders",
            account: "\(documentIdString)_FolderName"
        )
        
        return (folderId, folderName)
    }
    
    /// Fixes common keychain issues by scanning documents and ensuring folder info is stored correctly
    func detectAndFixKeyChainIssues() {
        print("🛠️ Running keychain folder info fixer...")
        
        // Get managed object context
        let context = PersistenceController.shared.container.viewContext
        
        // Fetch all documents
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Document")
        
        do {
            let documents = try context.fetch(fetchRequest)
            print("📄 Found \(documents.count) documents to check")
            
            var fixedCount = 0
            
            for document in documents {
                // Get document ID
                if let documentId = document.value(forKey: "id") as? UUID {
                    
                    // Get folder ID
                    let folderId = document.value(forKey: "folderId") as? UUID
                    
                    // Get folder name if available
                    var folderName: String? = nil
                    if let fId = folderId {
                        // Try to look up folder name from Core Data
                        let folderRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
                        folderRequest.predicate = NSPredicate(format: "id == %@", fId as CVarArg)
                        folderRequest.fetchLimit = 1
                        
                        if let folders = try? context.fetch(folderRequest),
                           let folder = folders.first,
                           let name = folder.value(forKey: "name") as? String {
                            folderName = name
                        }
                    }
                    
                    // Check if keychain entry exists and is valid
                    let (storedFolderId, storedFolderName) = getFolderInfo(documentId: documentId)
                    
                    // If there's a mismatch, update the keychain
                    if storedFolderId != folderId || (folderName != nil && storedFolderName != folderName) {
                        if storeFolderInfo(documentId: documentId, folder: folderName, folderId: folderId) {
                            fixedCount += 1
                        }
                    }
                }
            }
            
            print("✅ Fixed keychain entries for \(fixedCount) documents")
        } catch {
            print("❌ Error fetching documents: \(error.localizedDescription)")
        }
    }
} 
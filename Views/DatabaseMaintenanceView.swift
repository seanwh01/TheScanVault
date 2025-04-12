import SwiftUI
import CoreData

struct DatabaseMaintenanceView: View {
    @State private var isCleaningTags = false
    @State private var isCleaningFolders = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var tagsDeleted = 0
    @State private var foldersDeleted = 0
    @State private var showDeleteConfirmation = false
    @State private var pendingTagsToDelete: [Tag] = []
    @State private var pendingFoldersToDelete: [Folder] = []
    @State private var cleanupType: String = "" // "tags" or "folders"
    @State private var itemCount: Int = 0
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            List {
                // Header section with explanation
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Database Maintenance")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Text("These tools help you keep your database organized by removing unused items.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Warning: These operations cannot be undone.")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                // Tag cleanup section
                Section(header: Text("TAG MANAGEMENT")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unused Tags")
                            .font(.headline)
                        
                        Text("Remove tags that aren't associated with any documents.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        Button(action: {
                            print("🏷️ ISOLATED TAG CLEANUP STARTING")
                            do {
                                try cleanupUnusedTags()
                            } catch {
                                print("❌ Error cleaning up tags: \(error.localizedDescription)")
                                alertTitle = "Error"
                                alertMessage = "Failed to clean up tags: \(error.localizedDescription)"
                                showAlert = true
                                isCleaningTags = false
                            }
                        }) {
                            HStack {
                                if isCleaningTags {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                    Text("Cleaning Tags...")
                                } else {
                                    Image(systemName: "tag.slash")
                                        .foregroundColor(.blue)
                                    Text("Clean Up Unused Tags")
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .disabled(isCleaningTags || isCleaningFolders)
                    }
                    .padding(.vertical, 8)
                }
                
                // Folder cleanup section
                Section(header: Text("FOLDER MANAGEMENT")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unused Folders")
                            .font(.headline)
                        
                        Text("Remove folders that don't contain any documents.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        Button(action: {
                            print("📁 ISOLATED FOLDER CLEANUP STARTING")
                            do {
                                try cleanupUnusedFolders()
                            } catch {
                                print("❌ Error cleaning up folders: \(error.localizedDescription)")
                                alertTitle = "Error"
                                alertMessage = "Failed to clean up folders: \(error.localizedDescription)"
                                showAlert = true
                            }
                        }) {
                            HStack {
                                if isCleaningFolders {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                    Text("Cleaning Folders...")
                                } else {
                                    Image(systemName: "folder.badge.minus")
                                        .foregroundColor(.blue)
                                    Text("Clean Up Unused Folders")
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .disabled(isCleaningTags || isCleaningFolders)
                    }
                    .padding(.vertical, 8)
                }
                
                // Statistics section
                Section(header: Text("CLEANUP STATISTICS")) {
                    HStack {
                        Text("Last Tag Cleanup")
                        Spacer()
                        Text("\(tagsDeleted) tags removed")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Folder Cleanup")
                        Spacer()
                        Text("\(foldersDeleted) folders removed")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Database Maintenance")
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    primaryButton: .destructive(Text("Delete")) {
                        if cleanupType == "tags" {
                            deleteConfirmedTags()
                        } else {
                            deleteConfirmedFolders()
                        }
                    },
                    secondaryButton: .cancel {
                        pendingTagsToDelete = []
                        pendingFoldersToDelete = []
                        isCleaningTags = false
                        isCleaningFolders = false
                    }
                )
            }
        }
    }
    
    // ISOLATED TAG CLEANUP FUNCTION
    private func cleanupUnusedTags() {
        isCleaningTags = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: DispatchWorkItem(block: {
            do {
                print("🎯 ENTERING TAG CLEANUP - Completely Isolated")
                
                // Step 1: Get all tags
                let tagFetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                let allTags = try viewContext.fetch(tagFetchRequest)
                print("🏷️ Found \(allTags.count) tags in database")
                
                if allTags.isEmpty {
                    alertTitle = "No Action Needed"
                    alertMessage = "No tags found in the database."
                    showAlert = true
                    isCleaningTags = false
                    return
                }
                
                // Get all documents
                let documentFetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
                let allDocuments = try viewContext.fetch(documentFetchRequest)
                print("📄 Found \(allDocuments.count) documents in database")
                
                // Track which tags to keep and which to delete
                var tagsToDelete = [Tag]()
                var tagsToKeep = [Tag]()
                
                // For each tag, check if it's referenced by any documents
                for tag in allTags {
                    let tagName = tag.value(forKey: "name") as? String ?? "unnamed"
                    
                    // Create a fetch request to find documents that reference this tag
                    let docFetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
                    docFetchRequest.predicate = NSPredicate(format: "tags CONTAINS %@", tag)
                    docFetchRequest.fetchLimit = 1 // We only need to know if at least one document uses it
                    
                    do {
                        let count = try viewContext.count(for: docFetchRequest)
                        
                        // If no documents reference this tag, mark it for deletion
                        if count == 0 {
                            tagsToDelete.append(tag)
                            print("🗑️ Marking unused tag for deletion: '\(tagName)'")
                        } else {
                            tagsToKeep.append(tag)
                            print("✅ Keeping tag in use: '\(tagName)' (used by \(count) document(s))")
                        }
                    } catch {
                        print("⚠️ Error checking usage for tag '\(tagName)': \(error.localizedDescription)")
                    }
                }
                
                // If no tags to delete, report and return
                if tagsToDelete.isEmpty {
                    print("ℹ️ No unused tags to delete")
                    alertTitle = "No Action Needed"
                    alertMessage = "All tags are currently in use by documents. No tags were deleted."
                    showAlert = true
                    isCleaningTags = false
                    return
                }
                
                // Safety check - warn if we'd delete all tags when documents exist
                if tagsToKeep.isEmpty && !allDocuments.isEmpty {
                    print("⚠️ WARNING: Would delete all tags despite having documents in the database")
                }
                
                // Show confirmation before deletion
                pendingTagsToDelete = tagsToDelete
                cleanupType = "tags"
                itemCount = tagsToDelete.count
                
                alertTitle = "Confirm Deletion"
                alertMessage = "Are you sure you want to delete \(itemCount) unused tags?"
                showDeleteConfirmation = true
                
            } catch {
                print("❌ Error cleaning up tags: \(error.localizedDescription)")
                alertTitle = "Error"
                alertMessage = "Failed to clean up tags: \(error.localizedDescription)"
                showAlert = true
                isCleaningTags = false
            }
        }))
    }
    
    // Add this new function to delete tags after confirmation
    private func deleteConfirmedTags() {
        do {
            // Delete the tags
            for tag in pendingTagsToDelete {
                let tagName = tag.value(forKey: "name") as? String ?? "unnamed"
                viewContext.delete(tag)
                print("🗑️ Deleted unused tag: '\(tagName)'")
            }
            
            // Save changes
            try viewContext.save()
            tagsDeleted = pendingTagsToDelete.count
            print("✅ Deleted \(tagsDeleted) unused tag(s)")
            
            // Show results
            alertTitle = "Tags Cleanup"
            alertMessage = "Successfully removed \(tagsDeleted) unused tag(s)."
            showAlert = true
            
        } catch {
            print("❌ Error deleting tags: \(error.localizedDescription)")
            alertTitle = "Error"
            alertMessage = "Failed to delete tags: \(error.localizedDescription)"
            showAlert = true
        }
        
        pendingTagsToDelete = []
        isCleaningTags = false
    }
    
    // ISOLATED FOLDER CLEANUP FUNCTION
    private func cleanupUnusedFolders() {
        isCleaningFolders = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: DispatchWorkItem(block: {
            do {
                print("📂 BEGINNING ISOLATED FOLDER CLEANUP")
                
                // Step 1: Get all folders
                let folderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
                let allFolders = try viewContext.fetch(folderFetchRequest)
                print("📂 Found \(allFolders.count) folders in database")
                
                // Log all folder identifiers to check uniqueness
                print("🆔 ALL FOLDER IDENTIFIERS:")
                var folderIds = Set<String>()
                var duplicateFound = false
                
                for folder in allFolders {
                    let folderName = folder.value(forKey: "name") as? String ?? "unnamed"
                    let folderId = folder.objectID.uriRepresentation().absoluteString
                    
                    // Try to get any other identifiers that might exist
                    let possibleIdKeys = ["id", "uuid", "identifier", "folderID"]
                    var additionalIds = [String]()
                    
                    for key in possibleIdKeys {
                        // First check if the key exists in the folder entity
                        if folder.entity.attributesByName[key] != nil {
                            // Only then try to access the value
                            if let value = folder.value(forKey: key) as? String, !value.isEmpty {
                                additionalIds.append("\(key): \(value)")
                            }
                        }
                    }
                    
                    // Check if this folder's ID is unique
                    if folderIds.contains(folderId) {
                        print("⚠️ DUPLICATE FOLDER ID FOUND: \(folderId) for folder '\(folderName)'")
                        duplicateFound = true
                    } else {
                        folderIds.insert(folderId)
                    }
                    
                    // Log all identifiers
                    print("📂 Folder: '\(folderName)' - CoreData ObjectID: \(folderId) \(additionalIds.isEmpty ? "" : "- Additional IDs: \(additionalIds.joined(separator: ", "))")")
                }
                
                if duplicateFound {
                    print("⚠️ WARNING: DUPLICATE FOLDER IDs DETECTED - THIS MAY CAUSE INCORRECT DELETION")
                }
                
                // Step 2: Get all documents
                let documentFetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
                let allDocuments = try viewContext.fetch(documentFetchRequest)
                print("📄 Found \(allDocuments.count) documents in database")
                
                // Collection of folder names/IDs actually in use
                var usedFolderIdentifiers = Set<String>()
                
                // Get document entity info
                guard let documentEntity = NSEntityDescription.entity(forEntityName: "Document", in: viewContext) else {
                    print("❌ Could not find Document entity")
                    alertTitle = "Error"
                    alertMessage = "Could not find Document entity"
                    showAlert = true
                    isCleaningFolders = false
                    return
                }
                
                let documentAttributes = documentEntity.attributesByName.keys
                print("📝 Available Document attributes: \(documentAttributes)")
                
                // TEMPORARY DIAGNOSTIC MODE: Print all document properties for the first 3 documents
                print("🔬 DETAILED DOCUMENT ANALYSIS (First 3 documents):")
                for (index, document) in allDocuments.prefix(3).enumerated() {
                    print("\n📄 DOCUMENT #\(index+1):")
                    for attr in documentAttributes {
                        if let value = document.value(forKey: attr) {
                            print("   - \(attr): \(value)")
                        } else {
                            print("   - \(attr): nil")
                        }
                    }
                }
                
                // CRITICAL FIX: Check for multiple possible folder reference formats
                // 1. Look for a property named 'folderId' that might match a folder's name
                // 2. Look for exact case-insensitive matches on folder names
                // 3. Look for relationship called 'folder'
                
                print("\n📊 DOCUMENT-FOLDER RELATIONSHIP ANALYSIS:")
                for (index, document) in allDocuments.enumerated() {
                    let docTitle = document.value(forKey: "title") as? String ?? "Untitled"
                    print("\n📄 Document #\(index+1): '\(docTitle)'")
                    
                    // Try standard "folderId" attribute - HANDLE AS UUID
                    if documentAttributes.contains("folderId") {
                        if let folderUUID = document.value(forKey: "folderId") as? UUID {
                            print("  ✓ Has folderId (UUID): '\(folderUUID)'")
                            
                            // Add the UUID string representation to used folders
                            usedFolderIdentifiers.insert(folderUUID.uuidString)
                            
                            // Also try to find matching folder by ID to log the folder name
                            let matchingFolder = allFolders.first { folder in
                                if let folderId = folder.value(forKey: "id") as? UUID {
                                    return folderId == folderUUID
                                }
                                return false
                            }
                            
                            if let folder = matchingFolder, 
                               let folderName = folder.value(forKey: "name") as? String {
                                print("  ✓ Matched to folder: '\(folderName)'")
                            }
                        }
                    }
                    
                    // Try any attribute with "folder" in the name
                    for attr in documentAttributes where attr.lowercased().contains("folder") {
                        if let value = document.value(forKey: attr) as? String, !value.isEmpty {
                            print("  ✓ Has \(attr): '\(value)'")
                            usedFolderIdentifiers.insert(value)
                        }
                    }
                    
                    // Check for folder relationship (less common in your model it seems)
                    if documentEntity.relationshipsByName.keys.contains("folder") {
                        if let folder = document.value(forKey: "folder") as? Folder,
                           let folderName = folder.value(forKey: "name") as? String {
                            print("  ✓ Has relationship to folder: '\(folderName)'")
                            usedFolderIdentifiers.insert(folderName)
                        }
                    }
                }
                
                print("\n🔍 Found \(usedFolderIdentifiers.count) folder references in documents: \(usedFolderIdentifiers)")
                
                // Step 3: Mark folders not explicitly used for deletion
                var foldersToDelete = [Folder]()
                
                for folder in allFolders {
                    let folderName = folder.value(forKey: "name") as? String ?? "unnamed"
                    let objectId = folder.objectID.uriRepresentation().absoluteString
                    
                    print("\n📂 Checking folder: '\(folderName)' (ObjectID: \(objectId))")
                    
                    // Check if the folder name is used directly
                    if usedFolderIdentifiers.contains(folderName) {
                        print("  ✅ KEEPING: Folder name '\(folderName)' is directly referenced by documents")
                        continue
                    }
                    
                    // Check folder UUID (this is the critical fix)
                    if let folderUUID = folder.value(forKey: "id") as? UUID {
                        let uuidString = folderUUID.uuidString
                        if usedFolderIdentifiers.contains(uuidString) {
                            print("  ✅ KEEPING: Folder with UUID '\(uuidString)' is referenced by documents")
                            continue
                        }
                    }
                    
                    // Extra safety check: look for partial matches or case-insensitive matches
                    let caseInsensitiveMatch = usedFolderIdentifiers.contains { $0.lowercased() == folderName.lowercased() }
                    
                    if caseInsensitiveMatch {
                        print("  ✅ KEEPING: Folder '\(folderName)' matches a reference case-insensitively")
                        continue
                    }
                    
                    let partialMatch = usedFolderIdentifiers.contains { $0.contains(folderName) || folderName.contains($0) }
                    
                    if partialMatch {
                        print("  ✅ KEEPING: Folder '\(folderName)' partially matches a reference")
                        continue
                    }
                    
                    // If we've reached here, the folder isn't referenced
                    print("  🗑️ MARKING FOR DELETION: Folder '\(folderName)' isn't referenced by any document")
                    foldersToDelete.append(folder)
                }
                
                // If no folders to delete, report and return
                if foldersToDelete.isEmpty {
                    print("ℹ️ No unused folders to delete")
                    alertTitle = "No Action Needed"
                    alertMessage = "All folders are currently in use by documents. No folders were deleted."
                    showAlert = true
                    isCleaningFolders = false
                    return
                }
                
                // Show confirmation before deletion
                pendingFoldersToDelete = foldersToDelete
                cleanupType = "folders"
                itemCount = foldersToDelete.count
                
                alertTitle = "Confirm Deletion"
                alertMessage = "Are you sure you want to delete \(itemCount) unused folders?"
                showDeleteConfirmation = true
                
            } catch {
                print("❌ Error cleaning up folders: \(error.localizedDescription)")
                alertTitle = "Error"
                alertMessage = "Failed to clean up folders: \(error.localizedDescription)"
                showAlert = true
            }
            
            isCleaningFolders = false
        }))
    }
    
    private func deleteConfirmedFolders() {
        do {
            // Delete the folders
            for folder in pendingFoldersToDelete {
                let folderName = folder.value(forKey: "name") as? String ?? "unnamed"
                let objectId = folder.objectID.uriRepresentation().absoluteString
                print("🗑️ Deleted unused folder: '\(folderName)' (ObjectID: \(objectId))")
                viewContext.delete(folder)
            }
            
            // Save changes
            try viewContext.save()
            foldersDeleted = pendingFoldersToDelete.count
            print("✅ Deleted \(foldersDeleted) unused folder(s)")
            
            // Show results
            alertTitle = "Folders Cleanup"
            alertMessage = "Successfully removed \(foldersDeleted) unused folder(s)."
            showAlert = true
            
        } catch {
            print("❌ Error deleting folders: \(error.localizedDescription)")
            alertTitle = "Error"
            alertMessage = "Failed to delete folders: \(error.localizedDescription)"
            showAlert = true
        }
        
        pendingFoldersToDelete = []
        isCleaningFolders = false
    }
} 
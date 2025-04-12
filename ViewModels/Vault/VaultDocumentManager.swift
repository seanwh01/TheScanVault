import SwiftUI
import CoreData
import Combine
import Foundation

extension ViewModels_Vault {
    class VaultDocumentManager {
        // Persistence controller and context
        private(set) var persistenceController: PersistenceController
        var viewContext: NSManagedObjectContext {
            return persistenceController.container.viewContext
        }
        
        // MARK: - Initialization
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
        }
        
        // MARK: - Document Operations
        
        func fetchDocument(_ id: UUID) -> Document? {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try viewContext.fetch(fetchRequest)
                return results.first
            } catch {
                print("Error fetching document with ID \(id): \(error)")
                return nil
            }
        }
        
        func deleteDocument(_ id: UUID) {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                if let document = try viewContext.fetch(fetchRequest).first {
                    viewContext.delete(document)
                    try viewContext.save()
                    
                    // Post notification for document deletion
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DocumentDeleted"),
                        object: nil,
                        userInfo: [
                            "documentId": id,
                            "forceFullRefresh": true
                        ]
                    )
                }
            } catch {
                print("Error deleting document: \(error)")
            }
        }
        
        func checkIfDocumentExists(id: UUID) -> Bool {
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let count = try viewContext.count(for: fetchRequest)
                print("Document with ID \(id) exists: \(count > 0)")
                return count > 0
            } catch {
                print("Error checking if document exists: \(error)")
                return false
            }
        }
        
        // MARK: - OCR Text Management
        
        func cleanupOCRInComments() {
            print("🧹 Removing OCR text from comments fields...")
            
            // Get all documents where text and comments are the same (likely OCR text in comments)
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "text != nil AND comments == text")
            
            PersistenceController.shared.container.performBackgroundTask { context in
                do {
                    let documentsToFix = try context.fetch(fetchRequest)
                    print("Found \(documentsToFix.count) documents with OCR text in comments")
                    
                    var cleaned = 0
                    for document in documentsToFix {
                        // Keep the text field (for search) but clear comments
                        document.comments = nil
                        cleaned += 1
                    }
                    
                    if cleaned > 0 {
                        try context.save()
                        print("✅ Cleaned OCR text from \(cleaned) documents")
                    }
                } catch {
                    print("Error cleaning OCR from comments: \(error)")
                }
            }
        }
        
        func moveAllOCRFromCommentsToTextField() {
            print("🧹 Moving OCR text from comments to text field...")
            
            // Get all documents that have comments but no text (likely OCR only in comments)
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "comments != nil AND text == nil")
            
            PersistenceController.shared.container.performBackgroundTask { context in
                do {
                    let documentsToFix = try context.fetch(fetchRequest)
                    print("Found \(documentsToFix.count) documents with OCR text in comments only")
                    
                    var moved = 0
                    for document in documentsToFix {
                        // Move comments text to the text field for search
                        document.text = document.comments
                        document.comments = nil
                        moved += 1
                    }
                    
                    if moved > 0 {
                        try context.save()
                        print("✅ Moved OCR text from comments to text field for \(moved) documents")
                    }
                } catch {
                    print("Error cleaning OCR from comments: \(error)")
                }
            }
        }
        
        func checkOCRTextAvailability() {
            print("📊 Checking OCR text availability in documents...")
            
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Document.createdAt, ascending: false)]
            
            PersistenceController.shared.container.performBackgroundTask { context in
                do {
                    let allDocuments = try context.fetch(fetchRequest)
                    print("Found \(allDocuments.count) total documents.")
                    
                    var documentsWithOCR = 0
                    var documentsWithoutOCR = 0
                    
                    for document in allDocuments {
                        if let text = document.text, !text.isEmpty {
                            documentsWithOCR += 1
                            print("✓ Doc '\(document.title ?? "Untitled")' has OCR text (\(text.count) chars)")
                        } else {
                            documentsWithoutOCR += 1
                            print("✗ Doc '\(document.title ?? "Untitled")' has NO OCR text")
                        }
                    }
                    
                    print("📊 OCR Summary: \(documentsWithOCR) documents with OCR text, \(documentsWithoutOCR) without OCR text")
                } catch {
                    print("Error checking OCR text: \(error)")
                }
            }
        }
        
        func checkDocumentsInFolder(folderId: UUID?) {
            print("🔍 Checking documents in folder: \(folderId?.uuidString ?? "No Folder")")
            
            let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
            
            if let folderId = folderId {
                fetchRequest.predicate = NSPredicate(format: "folderId == %@", folderId as CVarArg)
            } else {
                fetchRequest.predicate = NSPredicate(format: "folderId == nil")
            }
            
            do {
                let documents = try viewContext.fetch(fetchRequest)
                print("📁 Found \(documents.count) documents in folder")
                
                // Check each document for OCR text
                for document in documents {
                    if let text = document.text, !text.isEmpty {
                        print(" - \(document.title ?? "Untitled") has OCR text (\(text.count) chars)")
                    } else {
                        print(" - \(document.title ?? "Untitled") has NO OCR text")
                    }
                }
            } catch {
                print("❌ Error checking folder contents: \(error)")
            }
        }
    }
} 
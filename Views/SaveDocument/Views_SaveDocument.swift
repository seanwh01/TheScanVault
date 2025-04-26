import SwiftUI
import CoreData
import Combine

// Namespace for SaveDocument view components
enum Views_SaveDocument {
    // This namespace will contain all SaveDocument components
    
    // Helper struct for tag item - mirror of the existing type in the main app
    struct TagItem: Identifiable {
        let id: UUID
        let name: String
    }
    
    // Helper struct for folder item - mirror of the existing type in the main app
    struct FolderItem: Identifiable {
        let id: UUID
        let name: String
    }
}

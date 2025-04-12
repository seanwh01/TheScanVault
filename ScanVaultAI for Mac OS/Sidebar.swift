import SwiftUI

struct Sidebar: View {
    @State private var selection: String? = "home"
    
    var body: some View {
        List(selection: $selection) {
            NavigationLink(destination: HomeView(), tag: "home", selection: $selection) {
                Label("Home", systemImage: "house")
            }
            
            NavigationLink(destination: DocumentsView(), tag: "documents", selection: $selection) {
                Label("Documents", systemImage: "doc.text")
            }
            
            NavigationLink(destination: FoldersView(), tag: "folders", selection: $selection) {
                Label("Folders", systemImage: "folder")
            }
            
            NavigationLink(destination: SettingsView(), tag: "settings", selection: $selection) {
                Label("Settings", systemImage: "gear")
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

// Basic placeholder views until you create full implementations
struct HomeView: View {
    var body: some View {
        Text("Welcome to ScanVaultAI")
            .font(.title)
    }
}

struct DocumentsView: View {
    var body: some View {
        Text("Documents will appear here")
            .font(.title)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.title)
    }
} 
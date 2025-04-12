import SwiftUI
import CoreData

struct AdaptiveLearningSection: View {
    @Binding var showLearningPatterns: Bool
    
    @AppStorage("enableAdaptiveLearning") private var enableAdaptiveLearning: Bool = true
    @AppStorage("adaptiveLearningThreshold") private var adaptiveLearningThreshold: Double = 0.6
    @AppStorage("maxLearningExamples") private var maxLearningExamples: Int = 100
    
    var body: some View {
        Section(header: Text("Adaptive Learning")) {
            Toggle(isOn: $enableAdaptiveLearning) {
                Text("Enable Adaptive Learning")
            }
            
            Text("When enabled, the app learns from your document classifications to improve future suggestions.")
                .font(.caption)
                .foregroundColor(.gray)
            
            if enableAdaptiveLearning {
                VStack {
                    HStack {
                        Text("Learning Threshold")
                        Spacer()
                        Text(String(format: "%.0f%%", adaptiveLearningThreshold * 100))
                            .foregroundColor(.gray)
                    }
                    
                    Slider(value: $adaptiveLearningThreshold, in: 0.1...0.9, step: 0.1)
                }
                
                Text("Confidence threshold for AI to learn from a classification. Higher values mean learning only from highly confident classifications.")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                VStack {
                    HStack {
                        Text("Max Learning Examples")
                        Spacer()
                        Text("\(maxLearningExamples)")
                            .foregroundColor(.gray)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(maxLearningExamples) },
                        set: { maxLearningExamples = Int($0) }
                    ), in: 10...500, step: 10)
                }
                
                Text("Maximum number of examples to store for learning. Higher values improve accuracy but use more storage.")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: {
                    showLearningPatterns = true
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("View Learning Patterns")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct AILearningView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LearningExample.timestamp, ascending: false)],
        animation: .default)
    private var learningExamples: FetchedResults<LearningExample>
    
    var body: some View {
        List {
            if learningExamples.isEmpty {
                Text("No learning examples found")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(learningExamples, id: \.id) { example in
                    VStack(alignment: .leading, spacing: 8) {
                        // Safely access data, or display a placeholder
                        Text(getDocumentText(from: example))
                            .lineLimit(2)
                            .font(.headline)
                        
                        HStack {
                            Text("Document:")
                                .font(.subheadline)
                            Text(getDocumentFingerprint(from: example))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        if let timestamp = example.timestamp {
                            Text(dateFormatter.string(from: timestamp))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteLearningExamples)
            }
        }
        .navigationTitle("Learning Examples")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    // Helper function to extract document text from the model
    private func getDocumentText(from example: LearningExample) -> String {
        // Here we would normally decode the stored data to get the text
        // For now, return a placeholder or the fingerprint
        return example.documentFingerprint ?? "Unknown Document"
    }
    
    // Helper function to get a displayable document ID
    private func getDocumentFingerprint(from example: LearningExample) -> String {
        if let fingerprint = example.documentFingerprint {
            // Truncate long fingerprints for display
            if fingerprint.count > 20 {
                return String(fingerprint.prefix(20)) + "..."
            }
            return fingerprint
        }
        return "Unknown"
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private func deleteLearningExamples(offsets: IndexSet) {
        withAnimation {
            offsets.map { learningExamples[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                // Handle the error
                print("Error deleting learning examples: \(error)")
            }
        }
    }
}

struct DeletedItemsHistoryView: View {
    @State private var deletedItems: [DeletedItem] = []
    
    var body: some View {
        List {
            ForEach(deletedItems.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    Text(deletedItems[index].name)
                        .font(.headline)
                    
                    HStack {
                        Text(deletedItems[index].type)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(deletedItems[index].date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("Deleted Items History")
        .onAppear {
            // Fetch deleted items history
            loadDeletedItems()
        }
    }
    
    private func loadDeletedItems() {
        // Simulate loading deleted items
        // In a real app, this would fetch from a database
        deletedItems = [
            DeletedItem(name: "Tax Return 2021", type: "Document", date: "Apr 5, 2023"),
            DeletedItem(name: "Medical", type: "Folder", date: "Mar 22, 2023"),
            DeletedItem(name: "Invoice #103", type: "Document", date: "Mar 15, 2023"),
            DeletedItem(name: "Car Registration", type: "Document", date: "Feb 10, 2023")
        ]
    }
}

struct DeletedItem {
    let name: String
    let type: String
    let date: String
}

struct FolderTagPatternsView: View {
    @State private var patterns: [FolderTagPattern] = []
    
    var body: some View {
        List {
            ForEach(patterns.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Text(patterns[index].folderName)
                        .font(.headline)
                    
                    Text("Common Tags:")
                        .font(.subheadline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(patterns[index].commonTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    Text("Confidence: \(String(format: "%.0f%%", patterns[index].confidence * 100))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Folder-Tag Patterns")
        .onAppear {
            loadPatterns()
        }
    }
    
    private func loadPatterns() {
        // Simulate loading patterns
        // In a real app, this would fetch from a service or database
        patterns = [
            FolderTagPattern(
                folderName: "Taxes",
                commonTags: ["Tax Return", "W2", "1099", "Financial"],
                confidence: 0.92
            ),
            FolderTagPattern(
                folderName: "Medical",
                commonTags: ["Health", "Insurance", "Doctor", "Prescription"],
                confidence: 0.85
            ),
            FolderTagPattern(
                folderName: "Utilities",
                commonTags: ["Bill", "Electric", "Water", "Internet", "Monthly"],
                confidence: 0.78
            )
        ]
    }
}

struct FolderTagPattern {
    let folderName: String
    let commonTags: [String]
    let confidence: Double
}

// A helper view to create a flowing layout of tags
struct FlowLayout: View {
    let spacing: CGFloat
    let children: [AnyView]
    
    init<Content: View>(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.children = [AnyView(content())]
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(0..<children.count, id: \.self) { index in
                children[index]
                    .padding([.horizontal, .vertical], spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if index == children.count - 1 {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == children.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
    }
} 
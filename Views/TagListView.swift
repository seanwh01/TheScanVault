import SwiftUI

struct TagListView: View {
    let selectedTagIds: Set<UUID>
    let pendingTagNames: [String]
    let allTags: [TagItem]
    let onRemoveTagId: (UUID) -> Void
    let onRemovePendingTag: (String) -> Void
    let isEditable: Bool

    init(
        selectedTagIds: Set<UUID>,
        pendingTagNames: [String],
        allTags: [TagItem],
        onRemoveTagId: @escaping (UUID) -> Void,
        onRemovePendingTag: @escaping (String) -> Void,
        isEditable: Bool = true
    ) {
        self.selectedTagIds = selectedTagIds
        self.pendingTagNames = pendingTagNames
        self.allTags = allTags
        self.onRemoveTagId = onRemoveTagId
        self.onRemovePendingTag = onRemovePendingTag
        self.isEditable = isEditable
    }

    // Computed property to get TagItems from selected IDs
    private var selectedTags: [TagItem] {
        allTags.filter { selectedTagIds.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        // Use VStack+ScrollView instead of FlowLayout for more reliable rendering
        VStack(alignment: .leading, spacing: 4) {
            // If no tags, show a message
            if selectedTags.isEmpty && pendingTagNames.isEmpty {
                Text("No tags")
                    .foregroundColor(.gray)
                    .italic()
            } else {
                // Wrap in a ScrollView to support many tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Display selected tags with explicit ID binding for stability
                        ForEach(selectedTags, id: \.id) { tagItem in 
                            // Use the more reliable blue capsule style from search results
                            BlueTagCapsule(
                                tagName: tagItem.name, 
                                isRemovable: isEditable,
                                onRemove: { onRemoveTagId(tagItem.id) } 
                            )
                        }

                        // Display pending tags with explicit string ID
                        ForEach(pendingTagNames, id: \.self) { tagName in
                            BlueTagCapsule(
                                tagName: tagName,
                                isRemovable: isEditable,
                                isPending: true,
                                onRemove: { onRemovePendingTag(tagName) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// Improved tag capsule for better visibility and consistent style with search results
struct BlueTagCapsule: View {
    let tagName: String
    var isRemovable: Bool = true
    var isPending: Bool = false
    var onRemove: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tagName)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
            
            if isRemovable {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isPending ? Color.orange : Color.blue
        )
        .cornerRadius(12)
    }
}

// Keep the original TagCapsule for backward compatibility
struct TagCapsule: View {
    let tagName: String
    let isPending: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tagName)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(BorderlessButtonStyle()) 
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isPending ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
        .clipShape(Capsule())
    }
}

// Basic Preview
struct TagListView_Previews: PreviewProvider {
    // Create some mock TagItems for preview
    static let mockTags: [TagItem] = {
        let tag1 = TagItem(id: UUID(), name: "Work")
        let tag2 = TagItem(id: UUID(), name: "Personal")
        let tag3 = TagItem(id: UUID(), name: "Urgent")
        return [tag1, tag2, tag3]
    }()

    static var previews: some View {
        VStack {
            TagListView(
                selectedTagIds: [mockTags[0].id, mockTags[2].id], 
                pendingTagNames: ["New Project", "Review"],
                allTags: mockTags,
                onRemoveTagId: { id in print("Remove tag ID: \(id)") },
                onRemovePendingTag: { name in print("Remove pending tag: \(name)") }
            )
            Spacer() 
        }
        .padding()
    }
}

// Note: You might need a FlowLayout implementation or adjust the layout.
// A simple Horizontal ScrollView with HStack can be a starting point if FlowLayout isn't available.
// Example using ScrollView + HStack:
// ScrollView(.horizontal, showsIndicators: false) {
//     HStack {
//         ForEach(selectedTags) { ... }
//         ForEach(pendingTagNames, id: \.self) { ... }
//     }
// }

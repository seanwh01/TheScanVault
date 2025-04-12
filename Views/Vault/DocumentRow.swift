import SwiftUI

// MARK: - Document Row
struct DocumentRow: View {
    let document: DocumentListItem
    let folderName: String?
    let onDelete: () -> Void
    let onLock: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)
                    if document.isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                            .accessibilityLabel("Locked")
                    }
                }
                
                if !document.tagNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(document.tagNames, id: \.self) { tagName in
                                Text(tagName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                                    .accessibilityLabel(tagName)
                            }
                        }
                    }
                    .frame(height: 26)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .zIndex(1) // Helps with gesture recognition
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onLock()
            } label: {
                Label(document.isLocked ? "Unlock" : "Lock", systemImage: document.isLocked ? "lock.open" : "lock")
            }
            .tint(Color.blue.opacity(0.8))
        }
    }
} 
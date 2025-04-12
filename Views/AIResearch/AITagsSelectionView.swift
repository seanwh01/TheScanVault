import SwiftUI

extension Views_AIResearch {
    // Flow layout component for tag selection
    struct TagFlowLayout<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {
        let items: Data
        let itemSpacing: CGFloat
        let lineSpacing: CGFloat
        let content: (Data.Element) -> Content
        
        init(items: Data, itemSpacing: CGFloat = 8, lineSpacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
            self.items = items
            self.itemSpacing = itemSpacing
            self.lineSpacing = lineSpacing
            self.content = content
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
                ForEach(items) { item in
                    content(item)
                        .padding(.horizontal, itemSpacing / 2)
                        .padding(.vertical, lineSpacing / 2)
                        .alignmentGuide(.leading) { dimension in
                            if abs(width - dimension.width) > geometry.size.width {
                                width = 0
                                height -= dimension.height + lineSpacing
                            }
                            let result = width
                            if item.id == items.last?.id {
                                width = 0
                            } else {
                                width -= dimension.width + itemSpacing
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if item.id == items.last?.id {
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
    }
    
    // Tag selection view with flowLayout
    struct AITagsSelectionView: View {
        @ObservedObject var viewModel: AIResearchViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Top controls with Reset and Select All buttons
                HStack {
                    Button(action: {
                        viewModel.resetTagSelection()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.footnote)
                            Text("Reset")
                                .font(.footnote)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        viewModel.selectAllTags()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.footnote)
                            Text("Select All")
                                .font(.footnote)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.vertical, 6)
                
                // Tags in flow layout
                ScrollView {
                    TagFlowLayout(items: viewModel.allTags, itemSpacing: 8, lineSpacing: 8) { tag in
                        AITagRow(tag: tag, viewModel: viewModel)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    // Individual tag row
    struct AITagRow: View {
        // Use the correct type that the viewModel works with
        let tag: TagItem
        @ObservedObject var viewModel: AIResearchViewModel
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.white)
                    .font(.caption)
                
                Text(tag.name)
                    .foregroundColor(.white)
                    .font(.footnote)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                toggleTagSelection()
            }
        }
        
        private var isSelected: Bool {
            if viewModel.tagSelectionMode == .allTags {
                return false
            } else if viewModel.tagSelectionMode == .selectedTags {
                return viewModel.selectedTagIds.contains(tag.id)
            } else {
                return false
            }
        }
        
        private func toggleTagSelection() {
            if viewModel.selectedTagIds.contains(tag.id) {
                viewModel.selectedTagIds.remove(tag.id)
                // Also update selectedTags for backward compatibility
                viewModel.selectedTags.remove(tag.id)
                
                if viewModel.selectedTagIds.isEmpty {
                    viewModel.tagSelectionMode = .allTags
                }
            } else {
                viewModel.selectedTagIds.insert(tag.id)
                // Also update selectedTags for backward compatibility
                viewModel.selectedTags.insert(tag.id)
                
                viewModel.tagSelectionMode = .selectedTags
            }
        }
    }
} 
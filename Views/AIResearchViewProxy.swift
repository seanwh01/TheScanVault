import SwiftUI

// This is a proxy implementation that forwards to the new AIResearchView implementation
// We're using a different file name to avoid naming conflicts
struct AIResearchView: View {
    var body: some View {
        AIResearch.AIResearchView()
    }
} 
import SwiftUI

// New view for AI usage statistics
struct AIUsageView: View {
    @State private var usageData: [UsageRecord] = []
    @State private var totalTokensUsed: Int = 0
    @State private var totalCost: Double = 0.0
    @State private var isLoading = true
    
    var body: some View {
        List {
            Section(header: Text("Usage Summary")) {
                VStack(alignment: .leading, spacing: 10) {
                    UsageSummaryRow(title: "Total Tokens Used", value: "\(totalTokensUsed)")
                    UsageSummaryRow(title: "Estimated Cost", value: "$\(String(format: "%.2f", totalCost))")
                    UsageSummaryRow(title: "Documents Processed", value: "\(usageData.count)")
                }
                .padding(.vertical, 10)
            }
            
            Section(header: Text("Recent Activity")) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if usageData.isEmpty {
                    Text("No AI document processing activity yet")
                        .italic()
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(usageData) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.documentTitle)
                                .font(.headline)
                            
                            Text("Model: \(record.modelName)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            HStack {
                                Text("Tokens: \(record.totalTokens)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("$\(String(format: "%.4f", record.cost))")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            Text(record.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("AI Usage")
        .onAppear {
            // Simulate loading usage data
            loadUsageData()
        }
    }
    
    private func loadUsageData() {
        // This would load actual usage data from a local database
        // For this demo, we'll use generic sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let sampleData = [
                UsageRecord(
                    id: UUID(),
                    documentTitle: "Document A",
                    date: Date().addingTimeInterval(-86400),
                    modelName: "GPT-3.5 Turbo",
                    promptTokens: 450,
                    completionTokens: 120,
                    totalTokens: 570,
                    // GPT-3.5 Turbo: $0.50/million input, $1.50/million output
                    cost: calculateCost(modelName: "GPT-3.5 Turbo", promptTokens: 450, completionTokens: 120)
                ),
                UsageRecord(
                    id: UUID(),
                    documentTitle: "Document B",
                    date: Date().addingTimeInterval(-172800),
                    modelName: "GPT-4o",
                    promptTokens: 850,
                    completionTokens: 180,
                    totalTokens: 1030,
                    // GPT-4o: $2.50/million input, $10.00/million output
                    cost: calculateCost(modelName: "GPT-4o", promptTokens: 850, completionTokens: 180)
                ),
                UsageRecord(
                    id: UUID(),
                    documentTitle: "Document C",
                    date: Date().addingTimeInterval(-259200),
                    modelName: "GPT-4 Turbo",
                    promptTokens: 760,
                    completionTokens: 140,
                    totalTokens: 900,
                    // GPT-4 Turbo: $10.00/million input, $30.00/million output
                    cost: calculateCost(modelName: "GPT-4 Turbo", promptTokens: 760, completionTokens: 140)
                )
            ]
            
            self.usageData = sampleData
            self.totalTokensUsed = sampleData.reduce(0) { $0 + $1.totalTokens }
            self.totalCost = sampleData.reduce(0.0) { $0 + $1.cost }
            self.isLoading = false
        }
    }
    
    private func calculateCost(modelName: String, promptTokens: Int, completionTokens: Int) -> Double {
        // Convert counts to millions of tokens
        let promptMillions = Double(promptTokens) / 1_000_000
        let completionMillions = Double(completionTokens) / 1_000_000
        
        // Apply correct pricing based on model
        switch modelName {
        case "GPT-3.5 Turbo":
            // $0.50/million input, $1.50/million output
            return (promptMillions * 0.50) + (completionMillions * 1.50)
        case "GPT-4o":
            // $2.50/million input, $10.00/million output
            return (promptMillions * 2.50) + (completionMillions * 10.00)
        case "GPT-4 Turbo":
            // $10.00/million input, $30.00/million output
            return (promptMillions * 10.00) + (completionMillions * 30.00)
        default:
            // Default to GPT-3.5 Turbo pricing if model not recognized
            return (promptMillions * 0.50) + (completionMillions * 1.50)
        }
    }
}

// Helper components
struct UsageSummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// Model for usage data
struct UsageRecord: Identifiable {
    let id: UUID
    let documentTitle: String
    let date: Date
    let modelName: String
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let cost: Double
} 
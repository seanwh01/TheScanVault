import SwiftUI
import CoreData
import Combine

// Helper extension for AI suggestions in SaveDocumentView
extension Views_SaveDocument {
    struct SDV_AIHelpers {
        
        // Helper to run AI analysis with proper constraints
        @MainActor
        static func ensureAIAnalysis(viewModel: ViewModels_Scan.ScanViewModel, 
                                    isPremium: Bool) {
            let shouldRunAIAnalysis = isPremium && 
                                  UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled") &&
                                  viewModel.aiSuggestions == nil &&
                                  viewModel.extractedOCRText != nil && 
                                  !viewModel.extractedOCRText!.isEmpty
            
            if shouldRunAIAnalysis {
                print("📊 No AI suggestions yet - requesting analysis")
                viewModel.ensureAIAnalysisWithMetadataContext()
            } else {
                if viewModel.aiSuggestions != nil {
                    print("📊 AI suggestions already exist - skipping duplicate analysis")
                } else {
                    print("⚠️ Skipping AI analysis: isPremium=\(isPremium), AIEnabled=\(UserDefaults.standard.bool(forKey: "AIDocumentClassificationEnabled"))")
                }
            }
        }
        
        // Handle title suggestion selection
        @MainActor
        static func selectSuggestedTitle(viewModel: ViewModels_Scan.ScanViewModel,
                                        title: String,
                                        documentTitle: inout String,
                                        showConfirmation: inout Bool) {
            documentTitle = title
            viewModel.documentTitle = title
            
            // Show confirmation
            withAnimation {
                showConfirmation = true
            }
            // Auto-hide after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    // Use notification to avoid capturing inout parameter in escaping closure
                    NotificationCenter.default.post(
                        name: Notification.Name("HideAIConfirmation"),
                        object: nil
                    )
                }
            }
        }
        
        // Calculate cost based on token usage
        static func calculateCost(promptTokens: Int, completionTokens: Int) -> Double {
            // Cost rates per million tokens (typical GPT-3.5 pricing)
            let inputCostPerMillion = 0.50  // $0.50 per million input tokens
            let outputCostPerMillion = 1.50 // $1.50 per million output tokens
            
            let inputCost = Double(promptTokens) * (inputCostPerMillion / 1_000_000)
            let outputCost = Double(completionTokens) * (outputCostPerMillion / 1_000_000)
            
            return inputCost + outputCost
        }
        
        // Helper to get model name from preferences
        static func getSelectedModelName() -> String {
            let modelKey = UserDefaults.standard.string(forKey: "AIClassifierModelPreference") ?? "gpt-3.5-turbo-0125"
            return modelDisplayName(for: modelKey)
        }
        
        // Helper to get display name for model
        static func modelDisplayName(for modelName: String) -> String {
            switch modelName {
            case "gpt-4o":
                return "GPT-4o"
            case "gpt-4-turbo":
                return "GPT-4 Turbo"
            default:
                return "GPT-3.5 Turbo"
            }
        }
        
        // Generate debug text for AI context
        @MainActor
        static func generateMetadataDebugText(viewModel: ViewModels_Scan.ScanViewModel) -> String {
            var result = ""
            
            if let ocrText = viewModel.extractedOCRText {
                result = "OCR Text Preview (first 100 chars): \n\(ocrText.prefix(100))...\n\n"
                
                var existingTitles: [String] = []
                var existingTags: [String] = []
                var existingFolders: [String] = []
                
                // Extract potential document titles (proper nouns, acronyms, document IDs)
                let titleRegex = try? NSRegularExpression(pattern: "([A-Z][a-z]+\\s?)+|[A-Z]{2,}|[A-Z0-9]+-[0-9]+")
                if let matches = titleRegex?.matches(in: ocrText, range: NSRange(ocrText.startIndex..., in: ocrText)) {
                    for match in matches {
                        let range = Range(match.range, in: ocrText)!
                        let title = String(ocrText[range])
                        if title.count > 3 && !existingTitles.contains(title) {
                            existingTitles.append(title)
                            if existingTitles.count >= 10 { break }
                        }
                    }
                }
                
                // Extract potential tags (single words or short phrases with special meaning)
                let tagRegex = try? NSRegularExpression(pattern: "\\b(invoice|receipt|contract|report|statement|bill|form|application|letter|memo)\\b")
                if let matches = tagRegex?.matches(in: ocrText.lowercased(), range: NSRange(ocrText.startIndex..., in: ocrText)) {
                    for match in matches {
                        let range = Range(match.range, in: ocrText.lowercased())!
                        let tag = String(ocrText.lowercased()[range])
                        if !existingTags.contains(tag) {
                            existingTags.append(tag)
                        }
                    }
                }
                
                // Extract potential folders (categories like finance, health, etc.)
                let folderRegex = try? NSRegularExpression(pattern: "\\b(finance|medical|health|insurance|tax|legal|personal|work|education|travel)\\b")
                if let matches = folderRegex?.matches(in: ocrText.lowercased(), range: NSRange(ocrText.startIndex..., in: ocrText)) {
                    for match in matches {
                        let range = Range(match.range, in: ocrText.lowercased())!
                        let folder = String(ocrText.lowercased()[range])
                        if !existingFolders.contains(folder) {
                            existingFolders.append(folder)
                        }
                    }
                }
                
                // Format the results as a debug message
                if !existingTitles.isEmpty {
                    result += "POSSIBLE TITLES: \(existingTitles.joined(separator: ", "))\n\n"
                } else {
                    result += "DOCUMENT TITLES: None found\n\n"
                }
                
                if !existingTags.isEmpty {
                    result += "TAGS: \(existingTags.joined(separator: ", "))\n\n"
                } else {
                    result += "TAGS: None found\n\n"
                }
                
                if !existingFolders.isEmpty {
                    result += "FOLDERS: \(existingFolders.joined(separator: ", "))\n\n"
                } else {
                    result += "FOLDERS: None found\n\n"
                }
                
                result += "Total items found: \(existingTitles.count) titles, \(existingTags.count) tags, \(existingFolders.count) folders"
            } else {
                result = "No OCR text available to enrich"
            }
            
            return result
        }
    }
}

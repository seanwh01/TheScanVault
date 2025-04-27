import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

extension AI_Learning {
    /// Handles text processing and vectorization for document classification
    class LearningVectorization {
        // Create a unique fingerprint for a document text
        func createDocumentFingerprint(_ text: String) -> String {
            // Normalize text - lowercase, remove excess whitespace
            let normalized = text.lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create a simple hash-based fingerprint
            // For production, consider more sophisticated fingerprinting methods
            if let data = normalized.data(using: .utf8) {
                return data.base64EncodedString()
            }
            
            // Fallback if encoding fails
            return UUID().uuidString
        }
        
        // Extract keywords from text for similarity matching
        func extractKeywords(from text: String) -> [String] {
            // Remove common stop words
            let stopWords = ["a", "an", "the", "in", "on", "at", "to", "for", "with", "by", "and", "or", "but", "is", "are", "was", "were"]
            
            // Split into words and normalize
            let words = text.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 2 }
            
            // Count word frequencies
            var wordCounts: [String: Int] = [:]
            for word in words {
                wordCounts[word, default: 0] += 1
            }
            
            // Return most frequent keywords (up to 50)
            return Array(wordCounts.sorted { $0.value > $1.value }.prefix(50).map { $0.key })
        }
        
        // Calculate similarity between document fingerprints
        func calculateSimilarity(document1: String, document2: String) -> Double {
            // Simple Jaccard similarity for demonstration
            // In production, consider more sophisticated similarity measures
            
            // Convert to sets of words
            let words1 = Set(document1.lowercased().components(separatedBy: .whitespacesAndNewlines))
            let words2 = Set(document2.lowercased().components(separatedBy: .whitespacesAndNewlines))
            
            // Calculate Jaccard similarity: |intersection| / |union|
            let intersection = words1.intersection(words2).count
            let union = words1.union(words2).count
            
            return union > 0 ? Double(intersection) / Double(union) : 0.0
        }
        
        // Find examples that are similar to the given fingerprint
        func findRelevantCorrectionExamples(examples: [ClassificationPair], for documentFingerprint: String) -> [ClassificationPair] {
            // First get keywords from the fingerprint
            let normalizedFingerprint = documentFingerprint.lowercased()
            
            // Calculate similarity with each example
            var scoredExamples: [(example: ClassificationPair, similarity: Double)] = []
            
            for example in examples {
                let exampleFingerprint = example.documentFingerprint.lowercased()
                let similarity = calculateSimilarity(document1: normalizedFingerprint, document2: exampleFingerprint)
                
                // Only include if somewhat similar
                if similarity > 0.1 {
                    scoredExamples.append((example: example, similarity: similarity))
                }
            }
            
            // Sort by similarity and take top results
            let sortedExamples = scoredExamples.sorted { $0.similarity > $1.similarity }
            return sortedExamples.prefix(5).map { $0.example }
        }
        
        // Analyze tags by semantic category
        func analyzeTags(examples: [ClassificationPair], by category: String) -> [String] {
            // This would ideally use NLP to categorize tags, but we'll use a simplified approach
            // For now, return common tags the user has added more than once
            
            var tagCounts: [String: Int] = [:]
            
            for example in examples {
                // Get tags added by user that weren't in AI suggestion
                let aiTags = Set(example.aiSuggestion.suggestedTags.map { $0.lowercased() })
                let userTags = Set(example.userSelection.suggestedTags.map { $0.lowercased() })
                
                // Count tags added by user
                for tag in userTags.subtracting(aiTags) {
                    tagCounts[tag, default: 0] += 1
                }
            }
            
            // Filter for selected category - this is simplified
            switch category {
            case "financial":
                return tagCounts.filter { $0.key.contains("invoice") || $0.key.contains("receipt") || 
                                    $0.key.contains("payment") || $0.key.contains("finance") }
                        .filter { $0.value > 1 }
                        .sorted { $0.value > $1.value }
                        .prefix(5)
                        .map { $0.key }
                
            case "personal":
                return tagCounts.filter { $0.key.contains("personal") || $0.key.contains("family") || 
                                    $0.key.contains("home") }
                        .filter { $0.value > 1 }
                        .sorted { $0.value > $1.value }
                        .prefix(5)
                        .map { $0.key }
                
            default:
                // Return most common tags
                return tagCounts.filter { $0.value > 1 }
                        .sorted { $0.value > $1.value }
                        .prefix(5)
                        .map { $0.key }
            }
        }
    }
}

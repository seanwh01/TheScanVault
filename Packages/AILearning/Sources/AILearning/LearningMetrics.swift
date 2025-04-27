import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

extension AI_Learning {
    /// Implements metrics collection and evaluation for the learning system
    class LearningMetrics {
        private let persistenceController: PersistenceController
        
        init(persistenceController: PersistenceController) {
            self.persistenceController = persistenceController
        }
        
        // Calculate accuracy of AI suggestions compared to user selections
        func calculateAccuracy(examples: [ClassificationPair]) -> (folderAccuracy: Double, tagAccuracy: Double, titleAccuracy: Double) {
            guard !examples.isEmpty else {
                return (folderAccuracy: 0, tagAccuracy: 0, titleAccuracy: 0)
            }
            
            var folderMatchCount = 0
            var tagTotalMatches = 0.0
            var tagTotalPossible = 0.0
            var titleMatchCount = 0
            
            for example in examples {
                // Calculate folder accuracy (exact match)
                let aiFolder = example.aiSuggestion.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let userFolder = example.userSelection.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                
                if aiFolder == userFolder {
                    folderMatchCount += 1
                }
                
                // Calculate tag accuracy (F1 score - combination of precision and recall)
                let aiTags = Set(example.aiSuggestion.suggestedTags.map { $0.lowercased() })
                let userTags = Set(example.userSelection.suggestedTags.map { $0.lowercased() })
                
                // Find matches and calculate F1
                let tagMatches = aiTags.intersection(userTags).count
                let aiTagCount = aiTags.count
                let userTagCount = userTags.count
                
                if aiTagCount > 0 || userTagCount > 0 {
                    let precision = aiTagCount > 0 ? Double(tagMatches) / Double(aiTagCount) : 0
                    let recall = userTagCount > 0 ? Double(tagMatches) / Double(userTagCount) : 0
                    
                    // F1 score is the harmonic mean of precision and recall
                    if precision > 0 || recall > 0 {
                        let f1 = 2 * (precision * recall) / (precision + recall)
                        tagTotalMatches += f1
                    }
                    
                    tagTotalPossible += 1
                }
                
                // Calculate title accuracy (lowercased normalized comparison)
                let aiTitle = example.aiSuggestion.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let userTitle = example.userSelection.suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                if aiTitle == userTitle {
                    titleMatchCount += 1
                }
            }
            
            // Calculate overall metrics
            let folderAccuracy = Double(folderMatchCount) / Double(examples.count)
            let tagAccuracy = tagTotalPossible > 0 ? tagTotalMatches / tagTotalPossible : 0
            let titleAccuracy = Double(titleMatchCount) / Double(examples.count)
            
            return (folderAccuracy: folderAccuracy, tagAccuracy: tagAccuracy, titleAccuracy: titleAccuracy)
        }
        
        // Get learning effectiveness over time (evaluating model improvement)
        func getAccuracyTrend(examples: [ClassificationPair]) -> [(date: Date, accuracy: Double)] {
            guard examples.count >= 5 else {
                return [] // Not enough data for a trend
            }
            
            // Sort examples by date
            let sortedExamples = examples.sorted { $0.timestamp < $1.timestamp }
            
            // Calculate moving accuracy in windows
            let windowSize = min(10, examples.count / 3)
            var trend: [(date: Date, accuracy: Double)] = []
            
            for i in stride(from: windowSize, to: sortedExamples.count, by: windowSize) {
                let windowExamples = Array(sortedExamples[i-windowSize..<i])
                let metrics = calculateAccuracy(examples: windowExamples)
                
                // Use average of folder and tag accuracy as the overall measure
                let overallAccuracy = (metrics.folderAccuracy + metrics.tagAccuracy) / 2
                trend.append((date: windowExamples.last!.timestamp, accuracy: overallAccuracy))
            }
            
            return trend
        }
        
        // Get folder tag association metrics
        func getFolderTagAssociationStrength(examples: [ClassificationPair]) -> [String: [String: Double]] {
            var folderTagAssociations: [String: [String: Double]] = [:]
            var folderTagCounts: [String: [String: Int]] = [:]
            var folderCounts: [String: Int] = [:]
            
            // Count folder and tag occurrences
            for example in examples {
                guard let folder = example.userSelection.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                      !folder.isEmpty else {
                    continue
                }
                
                folderCounts[folder, default: 0] += 1
                
                if folderTagCounts[folder] == nil {
                    folderTagCounts[folder] = [:]
                }
                
                for tag in example.userSelection.suggestedTags.map({ $0.lowercased() }) {
                    folderTagCounts[folder]?[tag, default: 0] += 1
                }
            }
            
            // Calculate association strengths
            for (folder, tagCounts) in folderTagCounts {
                if folderAssociations[folder] == nil {
                    folderAssociations[folder] = [:]
                }
                
                let folderTotal = folderCounts[folder] ?? 0
                if folderTotal == 0 { continue }
                
                for (tag, count) in tagCounts {
                    let strength = Double(count) / Double(folderTotal)
                    
                    // Only include meaningful associations (>20%)
                    if strength >= 0.2 {
                        folderTagAssociations[folder]?[tag] = strength
                    }
                }
            }
            
            return folderTagAssociations
        }
    }
}

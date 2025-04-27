import Foundation
import CoreData

// TODO: Replace with 'import ScanVaultCore' when framework is set up

extension AI_Learning {
    /// Implements algorithms for document classification and pattern detection
    class LearningAlgorithms {
        // Build folder correction patterns based on learning data
        func buildFolderCorrectionPatterns(from examples: [ClassificationPair]) -> [String] {
            var patterns = [String]()
            var folderTransitions = [String: [String]]()
            
            // Analyze all folder transitions
            for example in examples {
                let aiFolder = example.aiSuggestion.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let userFolder = example.userSelection.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // Skip if no change
                if aiFolder.lowercased() == userFolder.lowercased() {
                    continue
                }
                
                // Add to transitions dictionary
                if !folderTransitions.keys.contains(aiFolder) {
                    folderTransitions[aiFolder] = [userFolder]
                } else {
                    folderTransitions[aiFolder]?.append(userFolder)
                }
            }
            
            // Find common transitions (where user consistently changes a folder name)
            for (fromFolder, toFolders) in folderTransitions {
                let counts = NSCountedSet(array: toFolders)
                if let mostCommon = counts.max(by: { counts.count(for: $0) < counts.count(for: $1) }) as? String {
                    let count = counts.count(for: mostCommon)
                    if count >= 2 {
                        if fromFolder.isEmpty {
                            patterns.append("When documents aren't assigned a folder, user prefers '\(mostCommon)' (\(count) times)")
                        } else {
                            patterns.append("When AI suggests '\(fromFolder)', user prefers '\(mostCommon)' (\(count) times)")
                        }
                    }
                }
            }
            
            return patterns
        }
        
        // Build tag correction patterns
        func buildTagCorrectionPatterns(from examples: [ClassificationPair]) -> [String] {
            var patterns = [String]()
            
            // Count how often each tag is added or removed
            var tagsAdded = [String: Int]()
            var tagsRemoved = [String: Int]()
            
            for example in examples {
                let aiTags = Set(example.aiSuggestion.suggestedTags.map { $0.lowercased() })
                let userTags = Set(example.userSelection.suggestedTags.map { $0.lowercased() })
                
                // Added tags
                for tag in userTags.subtracting(aiTags) {
                    tagsAdded[tag, default: 0] += 1
                }
                
                // Removed tags
                for tag in aiTags.subtracting(userTags) {
                    tagsRemoved[tag, default: 0] += 1
                }
            }
            
            // Find frequently added tags
            let frequentlyAdded = tagsAdded.filter { $0.value >= 2 }
                .sorted { $0.value > $1.value }
                .prefix(5)
            
            if !frequentlyAdded.isEmpty {
                let tagsList = frequentlyAdded.map { "\($0.key) (\($0.value) times)" }.joined(separator: ", ")
                patterns.append("User frequently adds these tags: \(tagsList)")
            }
            
            // Find frequently removed tags
            let frequentlyRemoved = tagsRemoved.filter { $0.value >= 2 }
                .sorted { $0.value > $1.value }
                .prefix(5)
            
            if !frequentlyRemoved.isEmpty {
                let tagsList = frequentlyRemoved.map { "\($0.key) (\($0.value) times)" }.joined(separator: ", ")
                patterns.append("User frequently removes these tags: \(tagsList)")
            }
            
            return patterns
        }
        
        // Find consistent correction patterns in the learning examples
        func findConsistentCorrectionPatterns(from examples: [ClassificationPair]) -> [ClassificationPair] {
            var patterns: [ClassificationPair] = []
            
            // Example: Find cases where user consistently recategorizes a specific folder
            let folderRenames = Dictionary(grouping: examples) { example in
                return example.aiSuggestion.suggestedFolderName ?? "unknown"
            }
            
            // Find renames that occur multiple times
            for (_, groupedExamples) in folderRenames {
                if groupedExamples.count < 2 { continue }
                
                // Count user folder choices
                var userFolderCount: [String: Int] = [:]
                for example in groupedExamples {
                    let userFolder = example.userSelection.suggestedFolderName ?? "no_folder"
                    userFolderCount[userFolder, default: 0] += 1
                }
                
                // If one folder is chosen consistently, add this example
                if let (mostCommonFolder, count) = userFolderCount.max(by: { $0.value < $1.value }),
                   count >= 2 { // At least two occurrences
                    if let example = groupedExamples.first {
                        patterns.append(example)
                    }
                }
            }
            
            // Similar analysis could be done for tags
            
            return patterns
        }
        
        // Analyze folder-tag associations
        func getFolderTagPatternStatistics(from examples: [ClassificationPair]) -> [String: [(tag: String, frequency: Double)]] {
            // Initialize result
            var folderTagPatterns: [String: [(tag: String, frequency: Double)]] = [:]
            
            // Create folder-to-tag mapping
            var folderTagMap: [String: [String]] = [:]
            
            for example in examples {
                guard let folder = example.userSelection.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                    continue
                }
                
                // Skip empty folder names
                if folder.isEmpty { continue }
                
                let tags = example.userSelection.suggestedTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                
                if folderTagMap[folder] == nil {
                    folderTagMap[folder] = tags
                } else {
                    folderTagMap[folder]?.append(contentsOf: tags)
                }
            }
            
            // Calculate tag frequencies per folder
            for (folder, tags) in folderTagMap {
                // Count frequency of each tag in this folder
                let tagCounts = NSCountedSet(array: tags)
                let totalTags = Double(tags.count)
                
                var frequencies: [(tag: String, frequency: Double)] = []
                
                for tag in Set(tags) {
                    let count = tagCounts.count(for: tag)
                    let frequency = Double(count) / totalTags
                    
                    // Only include significant associations (>10%)
                    if frequency > 0.1 {
                        frequencies.append((tag: tag, frequency: frequency))
                    }
                }
                
                // Sort by frequency, highest first
                let sortedFrequencies = frequencies.sorted { $0.frequency > $1.frequency }
                
                // Only include folders with significant associations
                if !sortedFrequencies.isEmpty {
                    folderTagPatterns[folder] = sortedFrequencies
                }
            }
            
            return folderTagPatterns
        }
        
        // Identify deleted folders and tags
        func getDeletedFoldersAndTags(from examples: [ClassificationPair], existingFolders: [String], existingTags: [String]) -> (folders: [String], tags: [String]) {
            // Initialize empty sets for tracking deleted items
            var potentiallyDeletedFolders = Set<String>()
            var potentiallyDeletedTags = Set<String>()
            
            // Find folders and tags used in learning examples
            for example in examples {
                // Add folder if present
                if let folder = example.userSelection.suggestedFolderName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !folder.isEmpty {
                    potentiallyDeletedFolders.insert(folder.lowercased())
                }
                
                // Add tags
                for tag in example.userSelection.suggestedTags {
                    let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedTag.isEmpty {
                        potentiallyDeletedTags.insert(trimmedTag.lowercased())
                    }
                }
            }
            
            // Convert existing folders and tags to lowercase for comparison
            let existingFoldersLower = existingFolders.map { $0.lowercased() }
            let existingTagsLower = existingTags.map { $0.lowercased() }
            
            // Find items in learning examples that don't exist anymore
            let deletedFolders = potentiallyDeletedFolders.filter { !existingFoldersLower.contains($0) }
            let deletedTags = potentiallyDeletedTags.filter { !existingTagsLower.contains($0) }
            
            return (folders: Array(deletedFolders), tags: Array(deletedTags))
        }
    }
}

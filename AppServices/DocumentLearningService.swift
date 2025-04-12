import Foundation
import CoreData
import Combine

/// A service that enhances document classification by learning from user corrections
public class DocumentLearningService {
    // MARK: - Singleton Instance
    public static let shared = DocumentLearningService()
    
    // MARK: - Properties
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Track recent corrections to detect patterns
    private var recentCorrections: [(document: String, field: String, oldValue: String, newValue: String, timestamp: Date)] = []
    private let maxRecentCorrections = 100
    
    // Track folder usage frequencies for better suggestions
    private var folderFrequency: [String: Int] = [:]
    
    // Use AdaptiveLearningClassifier for storage compatibility
    private let adaptiveClassifier = AdaptiveLearningClassifier.shared
    
    // MARK: - Initialization
    private init() {
        print("🧠 Initializing DocumentLearningService")
        loadLearningData()
        
        // Observe document creation to learn from it
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDocumentSaved),
            name: NSNotification.Name("DocumentCreated"),
            object: nil
        )
        
        // Load existing folders and calculate frequencies
        calculateFolderFrequencies()
    }
    
    // MARK: - Folder Learning Methods
    
    /// Record a correction when a user changes an AI suggestion
    func recordCorrection(
        originalText: String,
        aiSuggestion: DocumentClassifierService.DocumentSuggestions,
        userChoice: DocumentClassifierService.DocumentSuggestions
    ) {
        print("🧠 DocumentLearningService recording correction")
        
        // Use AdaptiveLearningClassifier for Core Data storage
        adaptiveClassifier.recordUserCorrection(
            originalText: originalText,
            aiSuggestion: aiSuggestion,
            finalUserChoice: userChoice
        )
        
        // Track folder correction
        if let aiFolder = aiSuggestion.suggestedFolderName,
           let userFolder = userChoice.suggestedFolderName,
           aiFolder.lowercased() != userFolder.lowercased() {
            
            // Add to recent corrections for pattern detection
            recordSpecificCorrection(
                document: createFingerprint(for: originalText),
                field: "folder",
                oldValue: aiFolder,
                newValue: userFolder
            )
            
            // Increment folder frequency
            folderFrequency[userFolder.lowercased(), default: 0] += 1
            
            // Analyze correction for pattern
            analyzeAndStorePattern(
                documentText: originalText,
                fieldType: "folder",
                aiValue: aiFolder,
                userValue: userFolder
            )
        }
        
        // Track title correction
        if aiSuggestion.suggestedTitle != userChoice.suggestedTitle {
            recordSpecificCorrection(
                document: createFingerprint(for: originalText),
                field: "title",
                oldValue: aiSuggestion.suggestedTitle,
                newValue: userChoice.suggestedTitle
            )
            
            analyzeAndStorePattern(
                documentText: originalText,
                fieldType: "title",
                aiValue: aiSuggestion.suggestedTitle,
                userValue: userChoice.suggestedTitle
            )
        }
        
        // Track tag corrections
        let aiTags = Set(aiSuggestion.suggestedTags.map { $0.lowercased() })
        let userTags = Set(userChoice.suggestedTags.map { $0.lowercased() })
        
        if aiTags != userTags {
            // Tags added by user
            for tag in userTags.subtracting(aiTags) {
                recordSpecificCorrection(
                    document: createFingerprint(for: originalText),
                    field: "tag_added",
                    oldValue: "",
                    newValue: tag
                )
                
                analyzeAndStorePattern(
                    documentText: originalText,
                    fieldType: "tag_added",
                    aiValue: "",
                    userValue: tag
                )
            }
            
            // Tags removed by user
            for tag in aiTags.subtracting(userTags) {
                recordSpecificCorrection(
                    document: createFingerprint(for: originalText),
                    field: "tag_removed",
                    oldValue: tag,
                    newValue: ""
                )
                
                analyzeAndStorePattern(
                    documentText: originalText,
                    fieldType: "tag_removed",
                    aiValue: tag,
                    userValue: ""
                )
            }
        }
        
        // Save the updated data
        saveRecentCorrections()
    }
    
    // MARK: - Pattern Analysis and Storage
    
    /// Track a specific correction for pattern analysis
    private func recordSpecificCorrection(document: String, field: String, oldValue: String, newValue: String) {
        recentCorrections.append((
            document: document,
            field: field,
            oldValue: oldValue,
            newValue: newValue,
            timestamp: Date()
        ))
        
        // Trim if over capacity
        if recentCorrections.count > maxRecentCorrections {
            recentCorrections.removeFirst(recentCorrections.count - maxRecentCorrections)
        }
    }
    
    /// Analyze text for patterns that might explain a user correction
    private func analyzeAndStorePattern(documentText: String, fieldType: String, aiValue: String, userValue: String) {
        // Extract keywords from document text
        let keywords = extractKeywords(from: documentText)
        
        // Find keyword associations with corrections
        for keyword in keywords {
            // Store association of keyword with correction
            storeKeywordAssociation(
                keyword: keyword,
                fieldType: fieldType,
                aiValue: aiValue,
                userValue: userValue
            )
        }
    }
    
    /// Extract keywords from document text
    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction - could be much more sophisticated
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 } // Filter out very short words
        
        // Count word frequencies
        var wordCounts: [String: Int] = [:]
        for word in words {
            wordCounts[word, default: 0] += 1
        }
        
        // Return top keywords
        return Array(wordCounts.keys.sorted { wordCounts[$0]! > wordCounts[$1]! }.prefix(15))
    }
    
    /// Store keyword association with a specific correction pattern
    private func storeKeywordAssociation(keyword: String, fieldType: String, aiValue: String, userValue: String) {
        let context = persistenceController.container.viewContext
        
        // Check if this association already exists
        let fetchRequest: NSFetchRequest<KeywordPattern> = KeywordPattern.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "keyword == %@ AND fieldType == %@ AND aiValue == %@ AND userValue == %@",
                                             keyword, fieldType, aiValue, userValue)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            
            if let existingPattern = results.first {
                // Update existing pattern
                existingPattern.occurrences += 1
                existingPattern.lastSeen = Date()
            } else {
                // Create new pattern
                let newPattern = KeywordPattern(context: context)
                newPattern.id = UUID()
                newPattern.keyword = keyword
                newPattern.fieldType = fieldType
                newPattern.aiValue = aiValue
                newPattern.userValue = userValue
                newPattern.occurrences = 1
                newPattern.firstSeen = Date()
                newPattern.lastSeen = Date()
            }
            
            try context.save()
        } catch {
            print("❌ Error storing keyword pattern: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Suggestion Methods
    
    /// Apply learned patterns to enhance folder suggestions
    func enhanceFolderSuggestion(documentText: String, suggestedFolder: String?) -> String? {
        // If no suggested folder, use most frequent folder
        if suggestedFolder == nil || suggestedFolder?.isEmpty == true {
            if let mostFrequentFolder = folderFrequency.max(by: { $0.value < $1.value })?.key {
                return mostFrequentFolder.capitalized
            }
            return nil
        }
        
        // Create fingerprint
        let fingerprint = createFingerprint(for: documentText)
        
        // Extract keywords from the document
        let keywords = extractKeywords(from: documentText)
        
        // Check if we have learned patterns for these keywords
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<KeywordPattern> = KeywordPattern.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fieldType == %@ AND keyword IN %@ AND aiValue == %@",
                                            "folder", keywords, suggestedFolder ?? "")
        
        do {
            let patterns = try context.fetch(fetchRequest)
            
            if !patterns.isEmpty {
                // Group by userValue and count occurrences
                var userValueCounts: [String: Int] = [:]
                for pattern in patterns {
                    guard let userValue = pattern.userValue else { continue }
                    userValueCounts[userValue, default: 0] += Int(pattern.occurrences)
                }
                
                // Find the most frequent replacement
                if let bestMatch = userValueCounts.max(by: { $0.value < $1.value }) {
                    if bestMatch.value >= 2 { // Require at least 2 occurrences
                        return bestMatch.key
                    }
                }
            }
        } catch {
            print("❌ Error fetching folder patterns: \(error.localizedDescription)")
        }
        
        // Fall back to the original suggestion if no strong pattern found
        return suggestedFolder
    }
    
    /// Apply learned patterns to enhance tag suggestions
    func enhanceTagSuggestions(documentText: String, suggestedTags: [String]) -> [String] {
        // Start with the original suggestions
        var enhancedTags = suggestedTags
        
        // Extract keywords
        let keywords = extractKeywords(from: documentText)
        
        // Fetch patterns for adding tags
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<KeywordPattern> = KeywordPattern.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fieldType == %@ AND keyword IN %@",
                                            "tag_added", keywords)
        
        do {
            let patterns = try context.fetch(fetchRequest)
            
            // Group by userValue (tag name) and count occurrences
            var tagFrequency: [String: Int] = [:]
            for pattern in patterns {
                guard let tagName = pattern.userValue, !tagName.isEmpty else { continue }
                tagFrequency[tagName, default: 0] += Int(pattern.occurrences)
            }
            
            // Add frequently occurring tags that aren't already suggested
            for (tag, count) in tagFrequency where count >= 2 {
                if !enhancedTags.contains(where: { $0.lowercased() == tag.lowercased() }) {
                    enhancedTags.append(tag)
                }
            }
        } catch {
            print("❌ Error fetching tag patterns: \(error.localizedDescription)")
        }
        
        // Fetch patterns for removing tags
        let removeRequest: NSFetchRequest<KeywordPattern> = KeywordPattern.fetchRequest()
        removeRequest.predicate = NSPredicate(format: "fieldType == %@ AND keyword IN %@ AND aiValue IN %@",
                                             "tag_removed", keywords, enhancedTags.map { $0.lowercased() })
        
        do {
            let patterns = try context.fetch(removeRequest)
            
            // Group by aiValue (tag to remove) and count occurrences
            var tagRemovalFrequency: [String: Int] = [:]
            for pattern in patterns {
                guard let tagName = pattern.aiValue else { continue }
                tagRemovalFrequency[tagName, default: 0] += Int(pattern.occurrences)
            }
            
            // Remove tags that are frequently removed
            enhancedTags = enhancedTags.filter { tag in
                let lowerTag = tag.lowercased()
                return tagRemovalFrequency[lowerTag, default: 0] < 2
            }
        } catch {
            print("❌ Error fetching tag removal patterns: \(error.localizedDescription)")
        }
        
        return enhancedTags
    }
    
    /// Apply learned patterns to enhance title suggestions
    func enhanceTitleSuggestion(documentText: String, suggestedTitle: String) -> String {
        // Extract keywords
        let keywords = extractKeywords(from: documentText)
        
        // Fetch patterns for title changes
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<KeywordPattern> = KeywordPattern.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fieldType == %@ AND keyword IN %@",
                                            "title", keywords)
        
        do {
            let patterns = try context.fetch(fetchRequest)
            
            // Analyze title patterns
            var titlePatterns: [(from: String, to: String, count: Int)] = []
            for pattern in patterns {
                guard let aiValue = pattern.aiValue, let userValue = pattern.userValue else { continue }
                titlePatterns.append((from: aiValue, to: userValue, count: Int(pattern.occurrences)))
            }
            
            // Look for consistent patterns
            if let consistentPattern = findConsistentTitlePattern(patterns: titlePatterns, originalTitle: suggestedTitle) {
                return applyTitlePattern(pattern: consistentPattern, to: suggestedTitle)
            }
        } catch {
            print("❌ Error fetching title patterns: \(error.localizedDescription)")
        }
        
        return suggestedTitle
    }
    
    // MARK: - Pattern Analysis Helpers
    
    private func findConsistentTitlePattern(patterns: [(from: String, to: String, count: Int)], originalTitle: String) -> (type: String, transform: String)? {
        // Check for capitalization patterns
        let uppercasePatterns = patterns.filter { $0.to.first?.isUppercase == true }
        let lowercasePatterns = patterns.filter { $0.to.first?.isLowercase == true }
        
        if uppercasePatterns.count > lowercasePatterns.count && uppercasePatterns.count >= 2 {
            return ("capitalization", "uppercase")
        }
        
        // Check for length patterns
        let shorterTitles = patterns.filter { $0.to.count < $0.from.count }
        let longerTitles = patterns.filter { $0.to.count > $0.from.count }
        
        if shorterTitles.count > longerTitles.count && shorterTitles.count >= 2 {
            return ("length", "shorter")
        }
        
        // Check for specific word additions or removals
        var commonAddedWords: [String: Int] = [:]
        var commonRemovedWords: [String: Int] = [:]
        
        for pattern in patterns {
            let fromWords = Set(pattern.from.components(separatedBy: " "))
            let toWords = Set(pattern.to.components(separatedBy: " "))
            
            for word in toWords.subtracting(fromWords) {
                commonAddedWords[word, default: 0] += 1
            }
            
            for word in fromWords.subtracting(toWords) {
                commonRemovedWords[word, default: 0] += 1
            }
        }
        
        // Find common word transformations
        if let commonAddedWord = commonAddedWords.max(by: { $0.value < $1.value }), commonAddedWord.value >= 2 {
            return ("add_word", commonAddedWord.key)
        }
        
        if let commonRemovedWord = commonRemovedWords.max(by: { $0.value < $1.value }), commonRemovedWord.value >= 2 {
            return ("remove_word", commonRemovedWord.key)
        }
        
        return nil
    }
    
    private func applyTitlePattern(pattern: (type: String, transform: String), to title: String) -> String {
        switch pattern.type {
        case "capitalization":
            if pattern.transform == "uppercase" {
                // Ensure first letter is uppercase
                if let firstChar = title.first, firstChar.isLowercase {
                    return title.prefix(1).uppercased() + title.dropFirst()
                }
            }
        case "length":
            if pattern.transform == "shorter" {
                // Try to make title shorter by removing common filler words
                let fillerWords = ["the", "a", "an", "and", "or", "but", "for", "nor", "so", "yet"]
                var words = title.components(separatedBy: " ")
                words = words.filter { !fillerWords.contains($0.lowercased()) }
                return words.joined(separator: " ")
            }
        case "add_word":
            // Add a common word if not already present
            let wordToAdd = pattern.transform
            if !title.lowercased().contains(wordToAdd.lowercased()) {
                return "\(title) \(wordToAdd)"
            }
        case "remove_word":
            // Remove a word that's commonly removed
            let wordToRemove = pattern.transform
            let words = title.components(separatedBy: " ")
            let filteredWords = words.filter { $0.lowercased() != wordToRemove.lowercased() }
            if filteredWords.count < words.count {
                return filteredWords.joined(separator: " ")
            }
        default:
            break
        }
        
        return title
    }
    
    // MARK: - Document Classification Enhancement
    
    /// Enhances the AI suggestions using learned patterns
    func enhanceDocumentClassification(_ suggestions: DocumentClassifierService.DocumentSuggestions, documentText: String) -> DocumentClassifierService.DocumentSuggestions {
        print("🧠 Enhancing document classification using learning patterns")
        
        // Create a new copy of the suggestions to modify
        // (Since DocumentSuggestions appears to have immutable properties)
        var enhancedSuggestions = DocumentClassifierService.DocumentSuggestions(
            suggestedTitle: suggestions.suggestedTitle,
            suggestedFolderName: suggestions.suggestedFolderName,
            suggestedTags: suggestions.suggestedTags,
            confidence: suggestions.confidence
        )
        
        // Apply folder frequency weighting
        if let suggestedFolder = suggestions.suggestedFolderName {
            // Check if we have a frequently used folder that's better
            let frequentFolders = getMostFrequentFolders(3)
            
            // If the suggested folder is in top frequent folders, boost confidence
            if let frequency = folderFrequency[suggestedFolder.lowercased()], frequency > 5 {
                // Create a new instance with updated confidence instead of trying to modify it directly
                enhancedSuggestions = DocumentClassifierService.DocumentSuggestions(
                    suggestedTitle: enhancedSuggestions.suggestedTitle,
                    suggestedFolderName: enhancedSuggestions.suggestedFolderName,
                    suggestedTags: enhancedSuggestions.suggestedTags,
                    confidence: min(1.0, suggestions.confidence + 0.1)
                )
                print("🧠 Boosted confidence for frequently used folder: \(suggestedFolder)")
            }
        }
        
        // Extract keywords from document for pattern matching
        let keywords = extractKeywords(from: documentText)
        
        // Apply keyword-based enhancements
        // This is a minimal implementation - would be expanded in a real app
        
        return enhancedSuggestions
    }
    
    /// Returns the most frequently used folders
    private func getMostFrequentFolders(_ count: Int) -> [String] {
        return Array(folderFrequency.sorted { $0.value > $1.value }.prefix(count).map { $0.key })
    }
    
    // MARK: - Helper Methods
    
    /// Monitor document creation to learn from user corrections
    @objc private func handleDocumentSaved(_ notification: Notification) {
        print("📄 DocumentLearningService detected new document saved")
        
        // Update folder frequencies
        calculateFolderFrequencies()
    }
    
    /// Create a document fingerprint for comparison
    private func createFingerprint(for text: String) -> String {
        // Simple fingerprint - just use the first 100 characters
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return String(normalizedText.prefix(100))
    }
    
    /// Calculate the frequency of folder usage
    private func calculateFolderFrequencies() {
        let context = persistenceController.container.viewContext
        
        // Get all documents
        let fetchRequest: NSFetchRequest<Document> = Document.fetchRequest()
        
        do {
            let documents = try context.fetch(fetchRequest)
            var frequency: [String: Int] = [:]
            
            // Reset folders dictionary
            folderFrequency = [:]
            
            // Count unique folder IDs
            for document in documents {
                guard let folderId = document.folderId else { continue }
                
                // Get folder name
                let folderRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
                folderRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                folderRequest.fetchLimit = 1
                
                if let folders = try? context.fetch(folderRequest), let folder = folders.first, let folderName = folder.name {
                    frequency[folderName.lowercased(), default: 0] += 1
                }
            }
            
            // Update folder frequency
            folderFrequency = frequency
            
            print("📊 Updated folder frequencies: \(folderFrequency.count) folders")
        } catch {
            print("❌ Error calculating folder frequencies: \(error.localizedDescription)")
        }
    }
    
    /// Load learning data from persistent storage
    private func loadLearningData() {
        // Currently handled by AdaptiveLearningClassifier
    }
    
    /// Save recent corrections to persistent storage
    private func saveRecentCorrections() {
        // Currently, patterns are saved directly to Core Data
        // Recent corrections are kept in memory only
    }
    
    // MARK: - Debug Methods
    
    /// Get statistics about learned patterns
    func getStatistics() -> (patterns: Int, folders: Int, tags: Int, titles: Int) {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<KeywordPattern> = KeywordPattern.fetchRequest()
        
        do {
            let patterns = try context.fetch(fetchRequest)
            
            let folderPatterns = patterns.filter { $0.fieldType == "folder" }.count
            let tagAddedPatterns = patterns.filter { $0.fieldType == "tag_added" }.count
            let tagRemovedPatterns = patterns.filter { $0.fieldType == "tag_removed" }.count
            let titlePatterns = patterns.filter { $0.fieldType == "title" }.count
            
            return (
                patterns: patterns.count,
                folders: folderPatterns,
                tags: tagAddedPatterns + tagRemovedPatterns,
                titles: titlePatterns
            )
        } catch {
            print("❌ Error getting pattern statistics: \(error.localizedDescription)")
            return (0, 0, 0, 0)
        }
    }
}

// MARK: - Core Data Model Extension
// Remove this extension to fix the redeclaration error
// KeywordPattern is likely already defined elsewhere in the codebase 
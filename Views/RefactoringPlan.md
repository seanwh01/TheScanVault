# iOS Codebase Refactoring Plan

This document outlines the refactoring strategy for files exceeding 1000 lines in the ScanVault iOS codebase.

## Identified Large Files

1. **SettingsView.swift** (2904 lines) - ✅ Refactored into separate components
2. **VaultView.swift** (2860 lines) - ✅ Refactored into separate components  
3. **AIResearchView.swift** (2123 lines)
4. **VaultViewModel.swift** (2005 lines)
5. **ScanViewModel.swift** (1957 lines)
6. **AdaptiveLearningClassifier.swift** (1755 lines)
7. **OpenAIService.swift** (1699 lines)
8. **SaveDocumentView.swift** (1327 lines)
9. **DocumentClassifierService.swift** (1048 lines)

## Refactoring Priority and Strategy

We'll refactor these files in the following order:

1. ~~SettingsView.swift~~ ✅ COMPLETED
2. ~~VaultView.swift~~ ✅ COMPLETED
3. **AIResearchView.swift** ⬅️ CURRENT FOCUS
4. **VaultViewModel.swift**
5. **ScanViewModel.swift**
6. **AdaptiveLearningClassifier.swift**
7. **OpenAIService.swift**
8. **SaveDocumentView.swift**
9. **DocumentClassifierService.swift**

## Refactoring Guidelines

1. Each file should focus on a single responsibility
2. Extract reusable components into their own files
3. Organize related functionality into separate files
4. Keep files under 1000 lines, ideally under 500 lines
5. Maintain the existing functionality and behavior

## File-Specific Refactoring Plans

### 1. VaultView.swift (2860 lines) - ✅ COMPLETED

Created a dedicated folder: `Views/Vault/`

Extracted into:
- `VaultView.swift` - Main container view
- `DocumentListView.swift` - List of documents
- `DocumentGridView.swift` - Grid layout of documents
- `VaultFilterBar.swift` - Filtering controls
- `VaultSearchBar.swift` - Search functionality
- `VaultSortingOptions.swift` - Sorting controls
- `DocumentPreviewCell.swift` - Individual document cell
- `TagFilterView.swift` - Tag filtering component
- `VaultToolbar.swift` - Toolbar actions
- `EmptyVaultView.swift` - Empty state display

### 2. AIResearchView.swift (2123 lines) - ⬅️ CURRENT FOCUS

Create a dedicated folder: `Views/AIResearch/`

Extract into:
- `AIResearchView.swift` - Main container view
- `AIResearchInput.swift` - Query input component
- `AIResearchResultsView.swift` - Results display
- `AIResearchFilterOptions.swift` - Filtering options
- `AIResearchPromptTemplates.swift` - Prompt templates
- `AIModelSelector.swift` - Model selection
- `AIResearchHistoryView.swift` - History of searches
- `AIResearchExplanationView.swift` - Explanations for results
- `AIResearchSettingsView.swift` - Settings specific to AI research

### 3. VaultViewModel.swift (2005 lines)

Create a dedicated folder: `ViewModels/Vault/`

Extract into:
- `VaultViewModel.swift` - Core functionality
- `DocumentFilter.swift` - Document filtering logic
- `VaultSearchManager.swift` - Search functionality
- `VaultSortManager.swift` - Sorting functionality
- `DocumentImportManager.swift` - Import functionality
- `DocumentExportManager.swift` - Export functionality
- `DocumentSelectionManager.swift` - Selection state management
- `VaultSyncManager.swift` - Syncing functionality

### 4. ScanViewModel.swift (1957 lines)

Create a dedicated folder: `ViewModels/Scan/`

Extract into:
- `ScanViewModel.swift` - Core functionality
- `CameraManager.swift` - Camera handling
- `DocumentDetector.swift` - Document detection
- `ImageProcessor.swift` - Image processing
- `ScanStorage.swift` - Storage handling
- `OCRManager.swift` - OCR functionality
- `ScanMetadataExtractor.swift` - Metadata extraction
- `ScanQualityAnalyzer.swift` - Quality analysis

### 5. AdaptiveLearningClassifier.swift (1755 lines)

Create a dedicated folder: `AppServices/AdaptiveLearning/`

Extract into:
- `AdaptiveLearningClassifier.swift` - Core functionality
- `LearningDataStore.swift` - Data storage
- `FeatureExtractor.swift` - Feature extraction
- `PatternDetector.swift` - Pattern detection
- `ClassificationModel.swift` - Classification model
- `ConfidenceCalculator.swift` - Confidence scoring
- `FeedbackProcessor.swift` - User feedback processing
- `LearningStatistics.swift` - Statistics tracking

### 6. OpenAIService.swift (1699 lines)

Create a dedicated folder: `AppServices/OpenAI/`

Extract into:
- `OpenAIService.swift` - Core service
- `OpenAIModels.swift` - Model definitions
- `OpenAIEndpoints.swift` - API endpoints
- `PromptBuilder.swift` - Prompt construction
- `ResponseParser.swift` - Response parsing
- `TokenCounter.swift` - Token counting
- `APIKeyManager.swift` - API key management
- `OpenAIRateLimiter.swift` - Rate limiting

### 7. SaveDocumentView.swift (1327 lines)

Create a dedicated folder: `Views/DocumentSave/`

Extract into:
- `SaveDocumentView.swift` - Main container view
- `DocumentMetadataForm.swift` - Metadata input form
- `DocumentPreviewSection.swift` - Document preview
- `FolderSelectionSection.swift` - Folder selection
- `TagSelectionSection.swift` - Tag selection
- `DocumentTypeSelector.swift` - Document type selection
- `DocumentSaveToolbar.swift` - Save options
- `CustomMetadataSection.swift` - Custom metadata
- `AISuggestionSection.swift` - AI classification suggestions

### 8. DocumentClassifierService.swift (1048 lines)

Create a dedicated folder: `AppServices/DocumentClassifier/`

Extract into:
- `DocumentClassifierService.swift` - Core service
- `ClassifierModels.swift` - Model definitions
- `ClassificationStrategies.swift` - Different strategies
- `TextExtractor.swift` - Text extraction
- `KeywordMatcher.swift` - Keyword matching
- `ConfidenceCalculator.swift` - Confidence scoring
- `ClassificationCache.swift` - Caching results
- `ClassificationFeedback.swift` - Feedback processing

## Implementation Strategy

1. Create the necessary directory structure
2. Extract one component at a time
3. Test each component after extraction
4. Update all references to use the new component locations
5. Run thorough tests after each file is completely refactored

## Expected Benefits

- Improved code maintainability
- Better code organization
- Faster build times
- Easier navigation of the codebase
- Improved team collaboration
- Better reuse of components
- Easier debugging 
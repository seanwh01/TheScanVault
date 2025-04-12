# Document Learning System

The ScanVault Document Learning System enhances document classification by learning from user corrections and preferences over time. This README explains how the system works and how to use it.

## Overview

The Document Learning System consists of two main components:

1. **DocumentLearningService**: The central service that analyzes user corrections, identifies patterns, and enhances future document classification.
2. **KeywordPattern**: A Core Data entity that stores associations between document keywords and user corrections.

## How It Works

### 1. Learning Process

When a user corrects AI-suggested document metadata (title, folder, tags), the system:

1. Records the correction with the document fingerprint
2. Extracts keywords from the document text
3. Associates the keywords with the specific correction pattern
4. Stores this information in the database

### 2. Pattern Recognition

The system recognizes several types of patterns:

- **Folder preferences**: When users consistently place certain document types in specific folders
- **Tag preferences**: Which tags users frequently add or remove for specific content
- **Title formatting**: Preferred title styles, capitalization, or length

### 3. Enhanced Classification

When classifying new documents, the system:

1. Analyzes the document text to extract keywords
2. Checks for known patterns associated with those keywords
3. Enhances the AI suggestions based on past user corrections
4. Adapts to changing preferences over time

## Implementation Details

### Core Components

- **DocumentLearningService.swift**: Central learning logic and pattern application
- **KeywordPatternModel.swift**: Core Data entity for storing learned patterns
- **AdaptiveLearningClassifier.swift**: Legacy learning system integrated with the new service

### Key Methods

- `recordCorrection()`: Records user corrections for learning
- `enhanceDocumentClassification()`: Applies learned patterns to improve AI suggestions
- `analyzeAndStorePattern()`: Identifies and stores patterns from user corrections

## Usage

The DocumentLearningService is automatically used by the app to enhance document classification. No user configuration is needed.

To monitor system performance:

1. View learning patterns in Settings → AI Learning → View Learning Patterns
2. See statistics about how many patterns the system has learned
3. Reset learning data if needed through Settings

## Debugging

The learning system includes detailed logging to help debug issues:

- Look for log messages starting with 🧠 (brain emoji) for learning-related logs
- Check for 📊 (chart emoji) for statistics updates
- Watch for 📝 (document emoji) for document-related operations

## Core Data Schema

The `KeywordPattern` entity stores the following:

- `keyword`: A significant word from document text
- `fieldType`: Type of correction (folder, tag_added, tag_removed, title)
- `aiValue`: The original AI suggestion
- `userValue`: The user's corrected value
- `occurrences`: Number of times this pattern occurred
- `firstSeen` and `lastSeen`: Timestamps for when the pattern was observed

## Future Improvements

Future enhancements planned for the Document Learning System:

1. More sophisticated keyword extraction using NLP
2. Contextual understanding of document domains
3. Hierarchical pattern recognition
4. Integration with user explicit preferences 
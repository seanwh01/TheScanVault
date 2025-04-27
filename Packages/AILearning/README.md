# AILearning

This Swift Package contains the refactored implementation of the Adaptive Learning system used in ScanVault to improve AI suggestions based on user corrections.

## Overview

The AILearning package provides a modular approach to machine learning in ScanVault. It analyzes how users correct AI-suggested document titles, folders, and tags, learning patterns to improve future suggestions.

## Components

- **AdaptiveLearningClassifier**: Main interface for the learning system
- **LearningClassifierCore**: Core algorithms and coordination
- **LearningDataManager**: Manages storage and retrieval of learning examples
- **LearningVectorization**: Text processing and feature extraction
- **LearningAlgorithms**: Implementation of learning algorithms
- **LearningMetrics**: Evaluation of performance metrics

## Integration

To use this package in the ScanVault app:

1. Add the package to your Xcode project:
   - File > Add Packages...
   - Add Local...
   - Select the `/Users/seanwhite/TheScanVault/Packages/AILearning` directory

2. Import the package in your Swift files:
   ```swift
   import AILearning
   ```

3. Use the AdaptiveLearningClassifier with proper dependency injection:
   ```swift
   let classifier = AI_Learning.AdaptiveLearningClassifier(persistenceController: persistenceController)
   ```

## Architecture

The package follows a clean separation of concerns with each component focused on a specific responsibility. This modular approach improves:

- **Maintainability**: Smaller, focused components are easier to understand and modify
- **Testability**: Components can be tested in isolation
- **Flexibility**: Components can be replaced or enhanced individually

# ScanVault macOS Test Plan

This document provides an overview of the testing strategy for the ScanVault macOS application.

## Test Structure

The tests are organized into several categories:

1. **Unit Tests** - Testing individual components and functions
   - Document operations
   - Folder operations
   - Extension methods
   - Data operations

2. **Integration Tests** - Testing how components work together
   - Document viewer
   - Folder navigation
   - Document management workflow

3. **UI Tests** - Testing the user interface
   - Basic UI elements
   - Navigation
   - User interactions

## Running Tests

To run the tests:

1. Open the project in Xcode
2. Select the "ScanVault macOS" test plan
3. Choose Product > Test (⌘U) to run all tests

You can also run individual test classes or methods by clicking the diamond icons in the test file gutter.

## Test Data

The `TestUtilities.swift` file provides helper methods for generating test data, including:

- Creating test documents
- Creating test folders
- Creating complete test data sets

## Test Organization

- `ScanVaultAI_for_Mac_OSTests.swift` - Main test file
- `DocumentTests.swift` - Document-related tests
- `FolderTests.swift` - Folder-related tests
- `DocumentViewerTests.swift` - Document viewer tests, including document type tests
- `ExtensionsTests.swift` - Extension method tests
- `TestUtilities.swift` - Testing utilities

## Document Type Testing

The test plan now includes specific tests for different document types in the document viewer:

1. **Vector PDFs** - Tests for programmatically created PDFs with actual text content:
   - Correct rendering
   - Text selection
   - Detection as non-scanned document
   - Proper scaling and zooming

2. **Scanned/Image-based PDFs** - Tests for scanned PDFs:
   - Proper detection as a scanned document
   - Auto-scaling
   - Page fitting behavior
   - Creator/producer metadata

3. **Image Documents** - Tests for various image formats (JPEG, PNG, etc.):
   - Proper detection as image documents
   - Aspect ratio preservation
   - Correct size display behavior (small vs. large images)
   - Zoom and pan functionality

4. **Multi-Page Documents** - Tests for multi-page PDF navigation:
   - Page count verification
   - Thumbnail strip display
   - Page navigation
   - Content verification per page

These tests help ensure that each document type is displayed correctly in the viewer and that the application properly identifies and handles the different document types.

## Test Coverage

The test plan is configured to measure code coverage. After running tests, you can view coverage reports in Xcode's Report Navigator.

## Adding New Tests

When adding new features to the application, follow these steps to create corresponding tests:

1. Identify the appropriate test category (unit, integration, UI)
2. Create or update test methods in the relevant test file
3. Use the testing utilities to generate test data
4. Run the tests to verify they pass

## Continuous Integration

These tests are designed to be run in a CI environment. Future improvements could include:

- Automated test runs on pull requests
- Code coverage thresholds
- Performance testing baselines 
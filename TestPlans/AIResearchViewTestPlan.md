# ScanVault - AI Research View Test Plan

This test plan covers the testing of the AI Research View components in ScanVault, focusing on document selection, filtering, and OpenAI API integration.

## 1. Unit Tests

### 1.1 AIResearchViewModel Tests

#### Document Selection Tests
- [ ] `testInitialDocumentLoad` - Verify documents load correctly on initialization
- [ ] `testSelectDocument` - Test selecting a single document
- [ ] `testUnselectDocument` - Test unselecting a document
- [ ] `testToggleDocumentSelection` - Test toggling document selection
- [ ] `testSelectAllDocuments` - Test selecting all documents
- [ ] `testUnselectAllDocuments` - Test unselecting all documents
- [ ] `testSelectedDocumentCount` - Verify correct count of selected documents
- [ ] `testTokenEstimationForSelectedDocuments` - Verify token count estimation is accurate

#### Search Filter Tests
- [ ] `testSearchByTitle` - Test filtering documents by title
- [ ] `testSearchByOCRText` - Test filtering documents by OCR text content
- [ ] `testDateRangeFiltering` - Test filtering documents by date range
- [ ] `testTagFiltering` - Test filtering documents by tag selection
- [ ] `testNoTagsFiltering` - Test filtering for documents with no tags
- [ ] `testFolderFiltering` - Test filtering documents by folder
- [ ] `testNoFolderFiltering` - Test filtering for documents with no folder
- [ ] `testMultipleFilterCombination` - Test combining multiple filters
- [ ] `testClearSearchCriteria` - Test clearing all search filters

#### Folder Selection Tests
- [ ] `testFolderSelectionToggle` - Test toggling a folder selection
- [ ] `testAllFoldersSelection` - Test selecting all folders
- [ ] `testNoFolderSelection` - Test selecting the "No Folder" option
- [ ] `testAreFolderDocumentsSelected` - Test checking if documents in a folder are selected
- [ ] `testAreAllFolderDocumentsSelected` - Test checking if all documents in a folder are selected
- [ ] `testFolderSelectionText` - Test the display text for different folder selection states

#### Tag Selection Tests
- [ ] `testToggleTagSelection` - Test toggling tag selection
- [ ] `testSelectAllTags` - Test selecting all tags
- [ ] `testDeselectAllTags` - Test deselecting all tags
- [ ] `testToggleNoTagsOption` - Test toggling the "No Tags" option

#### OpenAI Integration Tests
- [ ] `testResearchWithAI` - Test the AI research function with a mock OpenAI service
- [ ] `testGetOpenAIAPIKey` - Test retrieving the OpenAI API key
- [ ] `testSaveRequestId` - Test saving and retrieving request IDs
- [ ] `testGetLastTwoRequestIds` - Test getting the last two request IDs
- [ ] `testModelSelection` - Test selecting different AI models

### 1.2 AISearchFieldsView Tests

- [ ] `testSearchFieldsLayout` - Test the layout of search fields
- [ ] `testTitleSearchField` - Test the title search field functionality
- [ ] `testOCRTextSearchField` - Test the OCR text search field functionality
- [ ] `testDateRangeSelection` - Test date range selection controls

### 1.3 AIFolderSelectionView Tests

- [ ] `testFolderSelectionLayout` - Test the layout of folder selection view
- [ ] `testToggleFolderSelection` - Test toggling folder selection
- [ ] `testFolderSelectionIndicator` - Test the indicator for selected folders
- [ ] `testNoFolderOption` - Test the "No Folder" option functionality

### 1.4 AISearchResultsView Tests

- [ ] `testSearchResultsLayout` - Test layout of search results view
- [ ] `testDocumentGrouping` - Test document grouping by folders
- [ ] `testDocumentSelection` - Test selecting documents from results
- [ ] `testNoResultsView` - Test the view when no results are found
- [ ] `testTokenCountDisplay` - Test token count display for selected documents

## 2. UI Tests

### 2.1 AI Research View UI Tests

- [ ] `testAIResearchViewLayout` - Verify basic layout of the AI Research view
- [ ] `testSearchFieldsInteraction` - Test interaction with search fields
- [ ] `testFolderFilterUI` - Test folder filter UI functionality
- [ ] `testTagFilterUI` - Test tag filter UI functionality
- [ ] `testDatePickerUI` - Test date picker UI functionality
- [ ] `testApplyButtonAction` - Test the Apply button action

### 2.2 AI Research Results UI Tests

- [ ] `testResultsViewNavigation` - Test navigation to results view
- [ ] `testDocumentSelectionInResults` - Test document selection in results view
- [ ] `testFolderGroupingUI` - Test folder grouping in results view
- [ ] `testResearchButtonAvailability` - Test research button enabling/disabling based on selection
- [ ] `testTokenLimitWarning` - Test token limit warning display

### 2.3 AI Research Query UI Tests

- [ ] `testPromptEntry` - Test entering a research prompt
- [ ] `testSystemRoleEntry` - Test entering a system role
- [ ] `testModelSelection` - Test model selection UI
- [ ] `testSubmitQueryUI` - Test submitting a research query
- [ ] `testLoadingIndicator` - Test loading indicator during API calls
- [ ] `testResultsDisplay` - Test display of research results

## 3. Integration Tests

### 3.1 Document Selection Workflow Tests

- [ ] `testSearchToSelectionWorkflow` - Test searching, filtering, and selecting documents
- [ ] `testBulkSelectionWorkflow` - Test bulk selection of documents by folder
- [ ] `testSelectionPersistence` - Test selection persistence between view transitions

### 3.2 API Integration Tests

- [ ] `testAPIKeyRetrieval` - Test retrieving the API key from storage
- [ ] `testAPIKeyFallback` - Test fallback mechanisms for API key retrieval
- [ ] `testOpenAIQuerySubmission` - Test submitting a query to OpenAI
- [ ] `testResponseParsing` - Test parsing OpenAI API responses
- [ ] `testErrorHandling` - Test handling of API errors

## 4. Performance Tests

- [ ] `testLargeDocumentListPerformance` - Test performance with 100+ documents
- [ ] `testComplexFilterPerformance` - Test filter performance with complex criteria
- [ ] `testLargeTokenCountPerformance` - Test handling large token counts
- [ ] `testAPIResponseTime` - Test response time for OpenAI API integration

## 5. Edge Cases and Error Handling

- [ ] `testEmptySelectionHandling` - Test handling of empty document selection
- [ ] `testMissingAPIKeyHandling` - Test handling of missing API key
- [ ] `testNetworkErrorHandling` - Test handling of network errors
- [ ] `testAPILimitExceeded` - Test handling of API rate limit errors
- [ ] `testTokenLimitExceeded` - Test handling of token limit exceeded errors
- [ ] `testInvalidDateRange` - Test handling of invalid date ranges

## Test Implementation Guide

### Example Unit Test for Document Selection:

```swift
func testToggleDocumentSelection() throws {
    // Setup
    let viewModel = AIResearchViewModel()
    
    // Refresh data to load documents
    viewModel.refreshData()
    
    // Wait for async loading to complete
    let expectation = XCTestExpectation(description: "Document loading")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        expectation.fulfill()
    }
    wait(for: [expectation], timeout: 2.0)
    
    // Pre-condition: At least one document exists
    XCTAssertFalse(viewModel.documents.isEmpty, "Need at least one document for test")
    
    // Get a document ID to test with
    let documentId = viewModel.documents[0].id
    
    // Verify document is not selected initially
    XCTAssertFalse(viewModel.isDocumentSelected(documentId), "Document should not be selected initially")
    
    // Toggle selection (select the document)
    viewModel.toggleDocumentSelection(documentId)
    
    // Verify document is now selected
    XCTAssertTrue(viewModel.isDocumentSelected(documentId), "Document should be selected after toggle")
    
    // Toggle selection again (unselect the document)
    viewModel.toggleDocumentSelection(documentId)
    
    // Verify document is now unselected
    XCTAssertFalse(viewModel.isDocumentSelected(documentId), "Document should be unselected after second toggle")
}
```

### Example UI Test for Search Fields Interaction:

```swift
func testSearchFieldsInteraction() {
    // Launch app
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to AI Research view
    app.tabBars.buttons["AI Research"].tap()
    
    // Enter title search text
    let titleTextField = app.textFields["Search Title"]
    XCTAssertTrue(titleTextField.exists, "Title search field should exist")
    titleTextField.tap()
    titleTextField.typeText("Invoice")
    
    // Enter OCR text search
    let ocrTextField = app.textFields["Search Content"]
    XCTAssertTrue(ocrTextField.exists, "OCR search field should exist")
    ocrTextField.tap()
    ocrTextField.typeText("payment")
    
    // Tap the Apply button
    let applyButton = app.buttons["Apply"]
    XCTAssertTrue(applyButton.exists, "Apply button should exist")
    applyButton.tap()
    
    // Verify we navigated to results screen
    let resultsView = app.navigationBars["AI Research Results"]
    XCTAssertTrue(resultsView.waitForExistence(timeout: 5), "Should navigate to results view")
}
```

## Testing Schedule

1. Unit tests should be implemented during feature development and run as part of the CI pipeline
2. UI tests should be run before each release
3. Performance tests should be run weekly to monitor for regressions
4. Edge case tests should be run after major feature changes

## Automated Testing vs. Manual Testing

While automated tests cover most functionality, the following areas benefit from manual testing:

1. OpenAI API integration with actual API keys
2. Complex document selection scenarios
3. Aesthetics and visual alignment of UI elements
4. Responsiveness of the interface under varying network conditions

## API Key Testing

When testing OpenAI API integration:
1. Use a test API key with limited quota
2. Test both keychain and UserDefaults retrieval methods
3. Verify error messages when an invalid key is provided
4. Confirm token usage reporting accuracy
5. Test proper cleanup of API keys after testing 
# ScanVault - Vault View Test Plan

This test plan covers the testing of the Vault Views components in ScanVault, focusing on document management, search, and document operations.

## 1. Unit Tests

### 1.1 VaultViewModel Tests

#### Document Listing Tests
- [x] `testInitialDocumentLoad` - Verify documents load correctly on initialization
- [x] `testDocumentListPagination` - Test loading additional documents works correctly
- [x] `testDocumentListSorting` - Verify documents are sorted by creation date (newest first)

#### Folder Operations Tests
- [x] `testFolderFiltering` - Test filtering documents by folder
- [x] `testNoFolderFiltering` - Test the "No Folder Assigned" filter works correctly
- [x] `testSelectAllFolders` - Test selecting all folders works
- [x] `testDeselectAllFolders` - Test deselecting all folders works

#### Tag Operations Tests
- [x] `testTagFiltering` - Test filtering documents by tag selection
- [x] `testNoTagsFiltering` - Test the "No Tags" filter works correctly
- [x] `testMultipleTagFiltering` - Test filtering by multiple tags works correctly

#### Document Operations Tests
- [x] `testDeleteDocument` - Test document deletion works correctly
- [x] `testDocumentDeletionUpdatesUI` - Verify document list updates after deletion
- [x] `testLockDocument` - Test locking a document functions correctly
- [x] `testUnlockDocument` - Test unlocking a document functions correctly
- [x] `testVerifyDocumentLockPassword` - Test password verification for locked documents

#### Search Tests
- [x] `testTitleSearch` - Test searching by document title
- [x] `testOCRTextSearch` - Test searching within document OCR text
- [x] `testDateRangeFiltering` - Test filtering documents by date range
- [x] `testCombinedSearchCriteria` - Test searching with multiple criteria (title, tags, folder)

### 1.2 DocumentRow Tests

- [x] `testDocumentRowLayout` - Test basic layout with all components
- [x] `testLockIndicatorVisibility` - Test lock icon appears when document is locked
- [x] `testTagsDisplay` - Test tags display correctly as bubbles
- [x] `testLongTitleTruncation` - Test long titles are properly truncated

### 1.3 DocumentDetailsSheet Tests

- [x] `testInitialDataLoading` - Test correct data is loaded from the document
- [x] `testSaveChanges` - Test saving changes to a document works correctly
- [x] `testTitleEditing` - Test changing the document title works
- [x] `testCommentsEditing` - Test editing document comments works

### 1.4 DocumentTagsEditView Tests

- [x] `testInitialTagsLoading` - Test existing tags are loaded correctly
- [x] `testAddTag` - Test adding a tag to a document
- [x] `testRemoveTag` - Test removing a tag from a document
- [x] `testCreateNewTag` - Test creating a new tag works

### 1.5 DocumentFolderEditView Tests

- [x] `testInitialFolderSelection` - Test correct folder is initially selected
- [x] `testChangeFolder` - Test changing a document's folder works
- [x] `testCreateNewFolder` - Test creating a new folder works
- [x] `testSelectNoFolder` - Test setting no folder works

## 2. UI Tests

### 2.1 VaultView UI Tests

- [ ] `testVaultViewLayout` - Verify basic layout of the Vault view
- [ ] `testFolderFilteringUI` - Test folder filter UI functionality
- [ ] `testTagFilteringUI` - Test tag filter UI functionality
- [ ] `testSearchFieldFunctionality` - Test search field responses to input

### 2.2 DocumentResultsView UI Tests

- [ ] `testResultsViewLayout` - Test the basic layout of results view
- [ ] `testFolderGrouping` - Test documents are grouped by folders
- [ ] `testFolderExpansionCollapse` - Test expanding/collapsing folder sections
- [ ] `testDocumentCountDisplay` - Verify document count is correctly displayed
- [ ] `testEmptyResultsView` - Test empty results state displays correctly
- [ ] `testLoadMoreButtonFunctionality` - Test "Load More" button appears and works

### 2.3 Document Operations UI Tests

- [ ] `testSwipeToDeleteDocument` - Test swipe gesture to delete a document
- [ ] `testSwipeToLockDocument` - Test swipe gesture to lock a document
- [ ] `testTapOpenDocument` - Test tapping a document opens document view
- [ ] `testPasswordPromptForLocked` - Test password prompt appears for locked documents

### 2.4 DocumentDetailsSheet UI Tests

- [ ] `testDetailsSheetLayout` - Test layout of details sheet
- [ ] `testFolderSelectionNavigation` - Test navigating to folder selection
- [ ] `testTagSelectionNavigation` - Test navigating to tag selection

## 3. Integration Tests

### 3.1 Document Workflow Tests

- [ ] `testFullDocumentLifecycle` - Test create > view > edit > delete workflow
- [ ] `testDocumentSearchToDetailNavigation` - Test searching, finding and opening a document
- [ ] `testEditAndVerifyChanges` - Test editing document details and verifying changes persist

### 3.2 Feature Integration Tests

- [ ] `testLockUnlockFullWorkflow` - Test complete lock/unlock workflow including password verification
- [ ] `testTagManagementAcrossViews` - Test tag changes in details view reflect in document list
- [ ] `testFolderChangesUpdateGrouping` - Test that changing a document's folder updates grouping in results

## 4. Performance Tests

- [ ] `testLargeDocumentListPerformance` - Test performance with 100+ documents
- [ ] `testComplexSearchPerformance` - Test search performance with complex criteria
- [ ] `testFolderGroupingPerformance` - Test folder grouping performance with many folders

## 5. Edge Cases and Error Handling

- [ ] `testDeleteLastDocumentInFolder` - Test deleting the last document in a folder
- [ ] `testIncorrectLockPassword` - Test handling of incorrect password entry
- [ ] `testDuplicateTagHandling` - Test handling attempts to create duplicate tags
- [ ] `testVeryLongTagsWrapping` - Test UI handling of very long tag names
- [ ] `testNetworkInterruptionHandling` - Test behavior when network connection is lost

## Test Implementation Guide

### Example Unit Test for Document Deletion:

```swift
func testDeleteDocument() throws {
    // Setup
    let expectation = XCTestExpectation(description: "Document deleted")
    let viewModel = VaultViewModel()
    
    // Pre-condition: At least one document exists
    XCTAssertFalse(viewModel.documents.isEmpty, "Need at least one document for test")
    let initialCount = viewModel.documents.count
    let documentToDelete = viewModel.documents.first!
    
    // Execute
    viewModel.deleteDocument(documentToDelete.id)
    
    // Wait for async deletion to complete
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        expectation.fulfill()
    }
    wait(for: [expectation], timeout: 2.0)
    
    // Verify
    XCTAssertEqual(viewModel.documents.count, initialCount - 1, "Document count should decrease by 1")
    XCTAssertFalse(viewModel.documents.contains(where: { $0.id == documentToDelete.id }), 
                  "Deleted document should not be in the list")
}
```

### Example UI Test for Document Results View:

```swift
func testDocumentCountDisplay() {
    // Launch app
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to Vault view
    app.tabBars.buttons["Vault"].tap()
    
    // Perform search to show results
    app.buttons["Search"].tap()
    
    // Verify document count label exists and has format "X documents"
    let countLabel = app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d+ documents'")).firstMatch
    XCTAssertTrue(countLabel.exists, "Document count label should be visible")
    
    // Extract count from label and verify it matches the visual document cells
    let labelText = countLabel.label
    let countString = labelText.components(separatedBy: " ").first ?? "0"
    let count = Int(countString) ?? 0
    
    // Count actual document cells
    let documentCells = app.cells.matching(identifier: "documentRow")
    XCTAssertEqual(documentCells.count, count, "Number of document cells should match count label")
}
```

## Testing Schedule

1. Unit tests should be implemented during feature development and run as part of the CI pipeline
2. UI tests should be run before each release
3. Performance tests should be run weekly to monitor for regressions
4. Edge case tests should be run after major feature changes 
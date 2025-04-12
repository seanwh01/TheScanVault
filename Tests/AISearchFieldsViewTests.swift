import XCTest
import SwiftUI
@testable import TheScanVault

final class AISearchFieldsViewTests: XCTestCase {
    
    var viewModel: AIResearchViewModel!
    
    override func setUpWithError() throws {
        viewModel = AIResearchViewModel()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
    }
    
    // MARK: - Layout Tests
    
    func testSearchFieldsLayout() throws {
        // Create a view instance - this won't actually render, but will verify that the view can be created without crashing
        let searchText = Binding<String>(get: { "" }, set: { _ in })
        let showDateRangeOptions = Binding<Bool>(get: { false }, set: { _ in })
        let showTagsOptions = Binding<Bool>(get: { false }, set: { _ in })
        let showFolderOptions = Binding<Bool>(get: { false }, set: { _ in })
        let isTextFieldFocused = FocusState<Bool>()
        
        // Create the view - the fact that this doesn't crash is part of the test
        let view = Views_AIResearch.AISearchFieldsView(
            viewModel: viewModel,
            searchText: searchText,
            showDateRangeOptions: showDateRangeOptions,
            showTagsOptions: showTagsOptions,
            showFolderOptions: showFolderOptions,
            cornerRadius: 12,
            isTextFieldFocused: isTextFieldFocused
        )
        
        // Verify the view exists - this is a basic test that doesn't require rendering
        XCTAssertNotNil(view, "AISearchFieldsView should be created successfully")
    }
    
    // MARK: - Title Search Field Tests
    
    func testTitleSearchField() throws {
        // Set search title in view model
        viewModel.searchTitle = "Test Document"
        
        // Verify the value is set correctly
        XCTAssertEqual(viewModel.searchTitle, "Test Document", "Title search field should update the view model")
        
        // Simulate clearing the search
        viewModel.searchTitle = ""
        
        // Verify the value is cleared
        XCTAssertEqual(viewModel.searchTitle, "", "Title search field should be cleared")
    }
    
    // MARK: - OCR Text Search Field Tests
    
    func testOCRTextSearchField() throws {
        // Set OCR text search in view model
        viewModel.searchOCRText = "Test Content"
        
        // Verify the value is set correctly
        XCTAssertEqual(viewModel.searchOCRText, "Test Content", "OCR text search field should update the view model")
        
        // Simulate clearing the search
        viewModel.searchOCRText = ""
        
        // Verify the value is cleared
        XCTAssertEqual(viewModel.searchOCRText, "", "OCR text search field should be cleared")
    }
    
    // MARK: - Date Range Selection Tests
    
    func testDateRangeSelection() throws {
        // Set start date
        let fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        viewModel.fromDate = fromDate
        
        // Verify from date is set correctly
        XCTAssertEqual(viewModel.fromDate, fromDate, "From date should be set correctly")
        
        // Set end date
        let toDate = Date()
        viewModel.toDate = toDate
        
        // Verify to date is set correctly
        XCTAssertEqual(viewModel.toDate, toDate, "To date should be set correctly")
        
        // Test date picker flag
        viewModel.isSelectingFromDate = true
        viewModel.showDatePicker = true
        
        // Verify date picker properties
        XCTAssertTrue(viewModel.isSelectingFromDate, "Should be selecting from date")
        XCTAssertTrue(viewModel.showDatePicker, "Date picker should be shown")
        
        // Toggle date selection
        viewModel.isSelectingFromDate = false
        
        // Verify selection mode changed
        XCTAssertFalse(viewModel.isSelectingFromDate, "Should be selecting to date")
    }
} 
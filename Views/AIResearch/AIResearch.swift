import SwiftUI

// Define a namespace for all AIResearch components
// This helps avoid naming conflicts with existing components
enum AIResearch {
    /// The main AIResearchView that serves as the container
    typealias AIResearchView = Views_AIResearch.AIResearchView
    
    /// Header view for the AI Research screen
    typealias AIResearchHeaderView = Views_AIResearch.AIResearchHeaderView
    
    /// View for search fields and filters
    typealias AISearchFieldsView = Views_AIResearch.AISearchFieldsView
    
    /// Date range selection view
    typealias AIDateRangeView = Views_AIResearch.AIDateRangeView
    
    /// Date picker sheet
    typealias AIDatePickerSheet = Views_AIResearch.AIDatePickerSheet
    
    /// View for selecting tags
    typealias AITagsSelectionView = Views_AIResearch.AITagsSelectionView
    
    /// Individual tag row
    typealias AITagRow = Views_AIResearch.AITagRow
    
    /// View for selecting folders
    typealias AIFolderSelectionView = Views_AIResearch.AIFolderSelectionView
    
    /// Individual folder row
    typealias AIFolderRow = Views_AIResearch.AIFolderRow
    
    /// Results view for displaying search results
    typealias AISearchResultsView = Views_AIResearch.AISearchResultsView
    
    /// Query view for entering AI research queries
    typealias AIResearchQueryView = Views_AIResearch.AIResearchQueryView
    
    /// View for displaying AI research results
    typealias AIResearchResultView = Views_AIResearch.AIResearchResultView
    
    /// Checkbox view for selection
    typealias CheckboxView = Views_AIResearch.CheckboxView
    
    /// Folder list view
    typealias FolderListView = Views_AIResearch.FolderListView
    
    /// Folder item view
    typealias FolderItemView = Views_AIResearch.FolderItemView
    
    /// Empty folder view
    typealias EmptyFolderView = Views_AIResearch.EmptyFolderView
    
    /// Pagination control view
    typealias PaginationControlView = Views_AIResearch.PaginationControlView
    
    /// Document row with checkbox
    typealias DocumentRowWithCheckbox = Views_AIResearch.DocumentRowWithCheckbox
    
    /// Structure to hold folder groups
    typealias FolderGroup = Views_AIResearch.FolderGroup
    
    /// Share sheet for sharing AI research results
    typealias AIResearchShareSheet = Views_AIResearch.AIResearchShareSheet
    
    /// Animation view for GIFs
    typealias GIFImageView = Views_AIResearch.GIFImageView
}

// All views in this module belong to this namespace
// This helps avoid naming conflicts with existing views
enum Views_AIResearch {} 
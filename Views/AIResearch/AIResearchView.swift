import SwiftUI
import CoreData
import UIKit

// Place the view inside the namespace
extension Views_AIResearch {
    struct AIResearchView: View {
        @StateObject private var viewModel = AIResearchViewModel()
        @State private var showResults = false
        @State private var searchText = ""
        @State private var showDateRangeOptions = false
        @State private var showTagsOptions = false
        @State private var showFolderOptions = false
        @State private var isRefreshing = false
        
        // Add the missing pagination variables here
        @State private var currentFolderPage: Int = 1
        private let foldersPerPage = 10
        
        // Constants for consistent styling
        private let cornerRadius: CGFloat = 12
        private let fieldHeight: CGFloat = 50
        
        // Add this property to track if keyboard is shown
        @FocusState private var isTextFieldFocused: Bool
        
        var body: some View {
            NavigationView {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    // Add a ScrollView to ensure content is accessible when keyboard appears
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            AIResearchHeaderView()
                            
                            // Search criteria
                            AISearchFieldsView(
                                viewModel: viewModel,
                                searchText: $searchText,
                                showDateRangeOptions: $showDateRangeOptions,
                                showTagsOptions: $showTagsOptions,
                                showFolderOptions: $showFolderOptions,
                                cornerRadius: cornerRadius,
                                isTextFieldFocused: _isTextFieldFocused
                            )
                            
                            Spacer()
                            
                            // Apply button
                            Button {
                                dismissKeyboard()
                                viewModel.searchDocuments()
                                showResults = true
                            } label: {
                                Text("Apply")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 140, height: 50)
                                    .background(Color.green)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.bottom, 50) // Add padding to ensure bottom content is visible
                    }
                    // Add tap gesture to dismiss keyboard when tapping anywhere
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
                .navigationBarHidden(true)
                .sheet(isPresented: $viewModel.showDatePicker) {
                    AIDatePickerSheet(
                        date: viewModel.isSelectingFromDate ? $viewModel.fromDate : $viewModel.toDate,
                        isPresented: $viewModel.showDatePicker,
                        title: viewModel.isSelectingFromDate ? "Select From Date" : "Select To Date",
                        onComplete: { /* Empty closure */ }
                    )
                }
                .onAppear {
                    setupOnAppear()
                }
                .fullScreenCover(isPresented: $showResults, onDismiss: {
                    // Reset and refresh when returning from results view
                    setupOnAppear()
                }) {
                    AISearchResultsView(
                        viewModel: viewModel,
                        isPresented: $showResults
                    )
                }
            }
        }
        
        // Add a function to dismiss the keyboard
        private func dismissKeyboard() {
            isTextFieldFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
        private func setupOnAppear() {
            viewModel.isLoading = false
            
            // Clear search criteria and refresh data every time view appears
            viewModel.clearSearchCriteria()
            viewModel.refreshData()
            
            // Reset these view state properties
            showDateRangeOptions = false
            showTagsOptions = false
            showFolderOptions = false
        }
    }
} 
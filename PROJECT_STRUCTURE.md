# ScanVault Project Structure

This document provides an overview of the ScanVault project structure to help developers understand the architecture and file organization.

## Architecture

ScanVault follows the Model-View-ViewModel (MVVM) architecture pattern for clean separation of concerns:

- **Models**: Core Data entities and other data structures
- **Views**: SwiftUI user interface components
- **ViewModels**: Business logic that connects models and views
- **Services**: Utility services for authentication, document management, etc.

## Directory Structure

```
ScanVault/
├── ScanVaultApp.swift           # Main app entry point
├── Info.plist                   # App configuration and permissions
├── Models/                      # Data models
│   ├── PersistenceController.swift  # Core Data stack manager with CloudKit sync
│   ├── ScanVault.xcdatamodeld      # Core Data model
│   └── User.swift               # User model
├── Views/                       # SwiftUI views
│   ├── ContentView.swift        # Main container view
│   ├── LoginView.swift          # Authentication views
│   ├── ScanView.swift           # Document scanning view
│   ├── DocumentDetailView.swift # Document detail view with optimized PDF rendering
│   ├── SaveDocumentView.swift   # Document creation and editing view (proxy to Views_SaveDocument)
│   ├── PDFKitView.swift         # Native PDF rendering component
│   ├── AIResearch/              # AI research components (refactored)
│   │   ├── AIResearchHeaderView.swift    # Header component
│   │   ├── AISearchFieldsView.swift      # Search fields component
│   │   ├── AIFolderSelectionView.swift   # Folder selection component
│   │   ├── AISearchResultsView.swift     # Results component
│   │   ├── AIResearchViewProxy.swift     # Backward compatibility proxy
│   │   └── Other component files         # Additional components
│   ├── SaveDocument/            # Document saving components (refactored)
│   │   ├── SaveDocumentMainView.swift    # Core document form
│   │   ├── SDV_TitleView.swift           # Title editing component
│   │   ├── SDV_FolderView.swift          # Folder selection component
│   │   ├── SDV_TagsView.swift            # Tag management component
│   │   ├── SDV_CommentsView.swift        # Comments component
│   │   ├── SDV_AIAnalysisView.swift      # AI analysis component
│   │   ├── SDV_FolderHelpers.swift       # Folder selection helpers
│   │   ├── SDV_TagsHelpers.swift         # Tag management helpers
│   │   ├── SDV_AIHelpers.swift           # AI analysis helpers
│   │   ├── SDV_FolderEditView.swift      # Folder selection UI
│   │   ├── SDV_TagEntryView.swift        # Tag selection UI
│   │   └── Other component files         # Additional components
│   ├── Settings/                # Settings components (refactored)
│   │   ├── SettingsHeaderView.swift      # Header component
│   │   ├── SettingsOptionsView.swift     # Options component
│   │   ├── SettingsViewProxy.swift       # Backward compatibility proxy
│   │   └── Other component files         # Additional components
│   ├── Vault/                   # Document vault components
│   │   ├── VaultView.swift      # Document management view
│   │   ├── DocumentRow.swift    # List item component for documents
│   │   ├── DocumentResultsView.swift # Document search results 
│   │   ├── DocumentDetailsSheet.swift # Document editing UI
│   │   ├── DocumentFolderEditView.swift # Folder selection UI
│   │   ├── DocumentTagsEditView.swift # Tag management UI
│   │   └── TagsSelectionView.swift  # Tags filtering component
│   ├── Helpers/                 # Reusable view components
│   │   ├── ZoomableScrollView.swift # Zoomable image container
│   │   └── ArrayExtensions.swift    # Array helper extensions
├── ViewModels/                  # Business logic
│   ├── AuthViewModel.swift      # Authentication logic
│   ├── ScanViewModel.swift      # Scanning logic (legacy - redirects to refactored namespace)
│   ├── VaultViewModel.swift     # Document search logic (proxy to ViewModels_Vault)
│   ├── DocumentViewModel.swift  # Document management and PDF rendering logic
│   ├── AIResearchViewModel.swift # AI research logic
│   ├── Scan/                    # Refactored ScanViewModel 
│   │   ├── ViewModels_Scan.swift        # Main scanning namespace
│   │   ├── ScanViewModel.swift          # Main scanner implementation
│   │   ├── ScanDocumentManager.swift    # Document creation service
│   │   └── ScanStateManager.swift       # Scanning state and transitions
│   ├── Vault/                   # Refactored Vault view models
│   │   ├── ViewModels_Vault.swift      # Main namespace and VaultViewModel implementation
│   │   ├── VaultDataModels.swift       # Document list item and data structures
│   │   ├── VaultDocumentManager.swift  # Document operation service
│   │   ├── VaultFilterService.swift    # Tag and folder filtering service
│   │   ├── VaultSearchService.swift    # Document search service
│   │   ├── VaultSortingService.swift   # Document sorting service
│   │   ├── VaultPaginationManager.swift # Page management for document lists
│   │   └── VaultStateManager.swift     # UI state management
│   └── SubscriptionManager.swift # Subscription management
├── AppServices/                 # Utility services
│   ├── DocumentLockManager.swift # Document security service
│   ├── DocumentProcessor.swift  # Document processing service
│   ├── DocumentClassifierService.swift # Document classification service
│   ├── KeychainManager.swift    # Keychain management service
│   ├── OpenAIService.swift      # AI integration service
│   └── AdaptiveLearningClassifier.swift # Adaptive learning proxy (points to Services/AI/Learning)
├── Services/                    # Core Services
│   ├── AI/                      # AI Services
│   │   └── Learning/            # Adaptive Learning components (refactored)
│   │       ├── AI_Learning.swift           # Main namespace 
│   │       ├── AdaptiveLearningClassifier.swift  # Main classifier 
│   │       ├── LearningClassifierCore.swift # Core classification logic
│   │       ├── LearningDataManager.swift    # Data management
│   │       ├── LearningModels.swift         # Data structures
│   │       ├── LearningVectorization.swift  # Text processing
│   │       ├── LearningAlgorithms.swift     # Classification algorithms
│   │       ├── LearningMetrics.swift        # Performance metrics
│   │       └── LearningPersistence.swift    # Storage management
├── Tests/                       # Test files
│   ├── VaultViewTests/          # Tests for Vault functionality
│   │   ├── VaultViewModelTests.swift         # Unit tests for core vault view model
│   │   ├── VaultViewModelPersistenceTests.swift # Tests for document persistence
│   │   ├── VaultViewModelDataManagerTests.swift # Tests for data operations
│   │   ├── DocumentRowUITests.swift          # UI tests for document row component
│   │   └── DocumentResultsViewUITests.swift  # UI tests for results view
│   ├── AIResearchViewTests/     # Tests for AI research functionality
│   │   └── AIResearchViewModelTests.swift    # Unit tests for AI research
│   └── ScanViewTests/           # Tests for document scanning
│       └── ScanViewModelTests.swift          # Unit tests for scanning
├── TestPlans/                   # Test plans
│   ├── VaultViewTestPlan.md     # Test plan for Vault view components
│   └── Other test plans         # Additional test plans
├── ScanVaultCore/               # Core functionality module
│   └── ScanVaultCore.docc/      # Documentation catalog
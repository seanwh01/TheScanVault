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
│   ├── SaveDocumentView.swift   # Document creation and editing view
│   ├── PDFKitView.swift         # Native PDF rendering component
│   ├── AIResearch/              # AI research components (refactored)
│   │   ├── AIResearchHeaderView.swift    # Header component
│   │   ├── AISearchFieldsView.swift      # Search fields component
│   │   ├── AIFolderSelectionView.swift   # Folder selection component
│   │   ├── AISearchResultsView.swift     # Results component
│   │   ├── AIResearchViewProxy.swift     # Backward compatibility proxy
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
│   └── OpenAIService.swift      # AI integration service
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
```

## Namespacing and Refactoring

ScanVault uses namespaces to organize and refactor large components:

1. **Views_AIResearch**: Namespace for AI research components
   - Used to prevent naming conflicts during refactoring
   - Provides a more modular code organization
   - Example: `enum Views_AIResearch {}` with extensions for each component

2. **Views_Settings**: Namespace for settings components
   - Organizes settings-related components
   - Supports dark mode styling consistently
   - Example: `enum Settings {}` with extensions for each component

3. **ViewModels_Vault**: Namespace for vault view model components
   - Organizes the VaultViewModel into smaller services
   - Separates concerns like document management, search, filtering, and sorting
   - Example: `enum ViewModels_Vault {}` with nested classes for each service

4. **ViewModels_Scan**: Namespace for scanning components 
   - Organizes scanning functionality into focused services
   - Separates document creation, processing, and state management
   - Example: `enum ViewModels_Scan {}` with nested classes for each service

5. **Proxy Implementation Pattern**:
   - Original filenames maintained at original locations
   - Redirects to namespaced components for backward compatibility
   - Prevents build errors for string catalogs and resources
   - Example: `VaultViewModel.swift` forwards to `ViewModels_Vault.VaultViewModel`

## Core Data Model

The Core Data model consists of three main entities:

1. **Document**
   - Properties: id, title, createdAt, updatedAt, documentData, comments, folderId, text, ocrText
   - Relationships: tags (many-to-many with Tag)

2. **Tag**
   - Properties: id, name, createdAt
   - Relationships: documents (many-to-many with Document)

3. **Folder**
   - Properties: id, name, createdAt

## Model Types

The app uses several model types for representing documents in different contexts:

1. **DocumentListItem** (VaultViewModel)
   - Used in document lists and search results
   - Properties: id, title, createdAt, folderName, tagNames, text, isLocked

2. **FolderItem** (VaultViewModel)
   - Used for folder representation in UI
   - Properties: id, name, isLocked
   
3. **TagItem** (VaultViewModel)
   - Used for tag representation in UI
   - Properties: id, name

4. **DocumentItem** (ScanViewModel)
   - Used in recent scans and document creation flow
   - Properties: id, title, createdAt, folderId, tagIds, thumbnail, aiModelUsed, isLocked

5. **AIDocumentItem** (AIResearchViewModel)
   - Used in AI research functionality
   - Properties: similar to DocumentItem but with AI-specific fields

## Key Components and Workflows

### Authentication Flow
- LoginView → AuthViewModel → ContentView → Main App Flow

### Document Scanning Flow
- ScanView → VisionKit Scanner → SaveDocumentView → ScanViewModel → Core Data

### Document Management Flow
- VaultView → VaultViewModel → DocumentResultsView → DocumentDetailView → DocumentViewModel → Core Data

### Document Editing Flow
- DocumentDetailView → DocumentDetailsSheet → DocumentTagsEditView/DocumentFolderEditView → Core Data

### AI Research Flow
- AIResearchView → AIResearchViewModel → OpenAIService → Document Classification

## PDF Rendering System

ScanVault implements an optimized PDF rendering system:

1. **PDF Loading and Caching**:
   - DocumentViewModel manages PDF document loading and page caching
   - Memory-efficient rendering with autorelease pools
   - Progressive quality improvement for zooming

2. **UI Consistency**:
   - Identical folder and tag management UI between SaveDocumentView and DocumentDetailView
   - Consistent interaction patterns across document lifecycle

3. **Memory Management**:
   - Optimized PDF page rendering with memory constraints
   - Automatic content cleanup during memory warnings
   - Background processing of large documents

4. **Document View Model Caching**:
   - VaultView and DocumentResultsView implement view model caching
   - Clean separation between document loading and rendering
   - Simplified document preloading system to prevent memory conflicts

## iCloud Integration

For Premium users, documents are synchronized across devices using CloudKit:

- **NSPersistentCloudKitContainer**: Used to manage Core Data with CloudKit syncing
- **SubscriptionManager**: Handles sync process when upgrading or downgrading subscription levels

## User Data Storage

- **Core Data**: Primary storage for documents, tags, and folders
- **Keychain**: Secure storage for authentication credentials and API keys
- **UserDefaults**: Storage for app preferences, subscription status, and fallback for API keys in simulator

## API Key Management

The app implements robust API key management:
- Primary retrieval from Keychain for security
- Fallback to UserDefaults for simulator environments
- Consistent checking across services via dual-source verification

## Testing Architecture

The app uses a comprehensive testing structure:

1. **Test Plans**: Markdown documents that outline testing strategies and track test implementation status

2. **Mock Classes**: Custom mocks for services and controllers:
   - **MockPersistenceController**: In-memory Core Data for tests
   - **TestViewModel**: Extends VaultViewModel with test-specific behavior

3. **Test Categories**:
   - **Unit Tests**: Focus on business logic in ViewModels
   - **UI Tests**: Test UI components and interactions
   - **Integration Tests**: Test data flow between components

4. **Performance Tests**:
   - Document loading and rendering benchmarks
   - Memory usage testing for large documents
   - CloudKit sync performance tests

## Development Guidelines

### Code Organization
- Keep view components focused on presentation
- Move business logic to view models
- Use namespaces for large feature sets
- Maintain backward compatibility through proxies

### Naming Conventions
- Use descriptive names for components
- Prefix private properties with underscore (_)
- Use standard suffixes (ViewModel, View, Service)
- Maintain consistency across related components

### Performance Considerations
- Cache rendered PDF pages to improve scrolling performance
- Use memory-efficient rendering techniques for large documents
- Implement proper memory management for document rendering
- Release resources proactively during memory pressure

### UI Consistency
- Maintain identical folder and tag management UI between SaveDocumentView and DocumentDetailView
- Use consistent styling and interaction patterns
- Follow Apple Human Interface Guidelines
- Support dark and light mode with appropriate contrast

### Testing
- Add unit tests for new functionality
- Update test plans when implementing new features
- Run the full test suite before submitting changes
- Test on different device sizes and memory configurations

### Documentation
- Update PROJECT_STRUCTURE.md when making architectural changes
- Document complex algorithms and performance optimizations
- Add code comments for non-obvious implementation details
- Create Markdown documentation for major components
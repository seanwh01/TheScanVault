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
│   ├── DocumentDetailView.swift # Document detail view
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
│   ├── ScanViewModel.swift      # Scanning logic
│   ├── VaultViewModel.swift     # Document search logic (proxy to ViewModels_Vault)
│   ├── DocumentViewModel.swift  # Document management logic
│   ├── AIResearchViewModel.swift # AI research logic
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

4. **Proxy Implementation Pattern**:
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
   - **MockDocumentViewModel**: Test-specific document operations
   - **MockCloudSyncManager**: Mock for CloudKit syncing operations

3. **Test Structure**:
   - **Unit Tests**: Test individual components and services
   - **UI Tests**: Test user interface components and interactions
   - **Integration Tests**: Test component interactions
   - **Performance Tests**: Test efficiency and speed

4. **Test Injection**: Components designed for testability:
   - Dependency injection for services
   - Override points for test-specific behavior
   - Static swappable implementations for complex dependencies

## Development Guidelines

For consistent development, follow these practices:

1. **Code Organization**
   - Break complex SwiftUI views into smaller components (under 800 lines)
   - Use namespaces to organize related components
   - Create proxy implementations for backward compatibility
   - Extract nested types into separate files
   - Use computed properties for view components

2. **Model Consistency** 
   - Use the appropriate model type for each context (DocumentListItem, DocumentItem)
   - Verify object types match when passing between components
   - Ensure consistent property naming (createdAt vs. createdDate)
   - Include proper null checks for optional properties

3. **ViewModels**
   - Keep @Published properties consistent between related view models
   - Document the purpose of getter and setter methods
   - Check for method existence before calling from views
   - Match parameter names exactly when overriding methods

4. **Testing**
   - Create separate mock classes with test prefixes (e.g., `TestViewModel`)
   - Maintain test plans with clear sections and marked completion status
   - Ensure test method signatures match the methods they're testing
   - Reset mock state in setUp methods to prevent test cross-contamination 
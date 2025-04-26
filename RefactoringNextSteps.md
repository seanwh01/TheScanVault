# TheScanVault Refactoring: Next Steps

## Completed Refactoring

We've successfully completed the following refactoring tasks:

1. **UserDefaults Extension**: Created a separate file `Extensions/UserDefaultsExtensions.swift` with the missing static properties:
   - `isAIDocumentClassificationEnabled`
   - `selectedAIModel`

2. **Model Access in AILearningView**: Fixed the `AdaptiveLearningSection.swift` file to use the correct property names from the `LearningExample` model.

3. **SettingsView Refactoring**: Split the 2904-line file into multiple components in `Views/Settings/` directory.
   - Implemented dark mode styling for all settings components
   - Improved API key handling with UserDefaults fallback for simulators

4. **VaultView Refactoring**: Split the 2860-line file into multiple components in `Views/Vault/` directory.

5. **AIResearchView Refactoring**: Split the 2123-line file into multiple components in `Views/AIResearch/` directory.
   - Created a namespace `Views_AIResearch` to prevent naming conflicts
   - Extracted focused components like header, search fields, folder selection, and results views
   - Created a proxy implementation for backward compatibility
   - Fixed string catalog compilation issues
   - Updated and fixed related test files to work with the new structure

6. **VaultViewModel Refactoring**: Split the 2005-line file into multiple service components in `ViewModels/Vault/` directory.
   - Created a namespace `ViewModels_Vault` to organize related components
   - Extracted specialized services like document management, search, filtering, and sorting
   - Implemented proper data models for documents, folders, and tags
   - Created comprehensive test plans to track test implementation
   - Fixed method signature issues in tests and mock classes
   - Ensured proper CoreData entity to view model conversions

7. **API Key Retrieval Improvements**:
   - Updated `DocumentClassifierService.swift` to check UserDefaults as fallback
   - Modified `SettingsView.swift` to verify API key existence in both Keychain and UserDefaults
   - Added logging to indicate when fallback sources are used

8. **ScanViewModel Refactoring**: Split the 1957-line file into multiple service components in `ViewModels/Scan/` directory.
   - Created a namespace `ViewModels_Scan` to organize related components
   - Extracted specialized services for document creation, state management, and operations
   - Created a proxy implementation for backward compatibility
   - Updated test files to work with the new structure
   - Enhanced memory management for document loading and processing
   - Fixed related crashes during document rendering and viewing

## Lessons Learned

Several important lessons were learned during our refactoring work:

1. **Namespacing is Essential**: Using proper namespacing (`enum Views_AIResearch {}`, `enum ViewModels_Vault {}`) prevents naming conflicts and helps organize related components.

2. **Proxy Implementation**: Creating a proxy at the original file location preserves backward compatibility and prevents string catalog compilation errors.

3. **Test File Management**: When refactoring, tests may break due to missing properties or redeclarations. Creating test-specific mock classes with unique names resolves these issues.

4. **Fallback Mechanisms**: Implementing fallbacks for critical services (like API key retrieval) enhances simulator support and makes development easier.

5. **Component Size**: Breaking large views into components of 200-300 lines makes them significantly more maintainable.

6. **Method Signature Matching**: When overriding methods in subclasses, the parameter names and types must match exactly to avoid compiler errors.

7. **Mock Initialization**: Mock classes must properly override parent class initializers following Swift's initialization rules.

8. **Data Type Conversion**: When working with CoreData entities, proper conversion to view models is essential for clean separation of concerns.

9. **Test Plan Maintenance**: Keeping test plans updated with checkmarks for completed tests helps track implementation progress.

10. **Property Naming Consistency**: Using consistent property names across the entire codebase (e.g., `createdAt` vs. `createdDate`) prevents confusion and bugs.

11. **Memory Management**: Careful handling of PDF rendering and large data processing is essential for app stability and performance.

## Next Target: SaveDocumentView Refactoring

Our next target is the SaveDocumentView.swift file (1327 lines), which handles document metadata editing, folder assignment, tag assignment, and AI-assisted document classification.

### Refactoring Plan for SaveDocumentView

1. Create a dedicated folder: `Views/SaveDocument/`

2. Extract SaveDocumentView into the following components:
   - `SaveDocumentView.swift` - Main container view (proxy)
   - `SaveDocumentMainView.swift` - Core document saving form
   - `TitleSection.swift` - Document title input section
   - `FolderSection.swift` - Folder selection section
   - `TagsSection.swift` - Tag management section
   - `CommentsSection.swift` - Document comments section
   - `SettingsSection.swift` - Document settings section
   - `AISuggestionsSection.swift` - AI classification suggestions
   - `ProgressOverlays.swift` - OCR and saving progress overlays
   - `FolderPickerView.swift` - Folder selection UI
   - `TagEntryView.swift` - Tag selection and creation UI

3. Implement a `Views_SaveDocument` namespace similar to our AIResearchView approach

4. Create a proxy implementation in the original location to maintain backward compatibility

## Implementation Steps

1. **Analysis**:
   - Identify distinct UI sections in SaveDocumentView
   - Map out dependencies between different parts of the view
   - Identify state properties that need to be shared across components

2. **File Creation**:
   - Create the `Views/SaveDocument/` directory
   - Create files for each component identified above

3. **State Management**:
   - Use a consistent approach for passing state between components
   - Prefer environment objects or bindings for shared state
   - Ensure all components have access to necessary state

4. **Extract Components**:
   - Move related functionality to appropriate files
   - Maintain proper access control
   - Ensure clean interfaces between components

5. **Proxy Implementation**:
   - Create a proxy version in the original location that forwards to the new implementation

6. **Testing**:
   - Update any tests that rely on SaveDocumentView
   - Verify all functionality works as expected

## Remaining Refactoring Queue

After completing SaveDocumentView refactoring, we will continue with:

1. **AdaptiveLearningClassifier.swift** (1755 lines)
2. **OpenAIService.swift** (1699 lines)
3. **DocumentClassifierService.swift** (1048 lines)
4. **ScanVaultCore Framework Setup** - Convert the current ScanVaultCore directory into a proper framework target instead of directly included files

## Important Import Rules During Refactoring

Until ScanVaultCore is properly set up as a framework, follow these import guidelines:

1. Files using components from ScanVaultCore (like PersistenceController) should use: `import Foundation` or `import CoreData` as needed
2. Document these imports with a comment: `// TODO: Replace with 'import ScanVaultCore' when framework is set up`
3. When refactoring components, ensure all necessary imports are included at the top of each file
4. Test thoroughly after adding imports to ensure all dependencies are properly resolved

## Approach for View Refactoring

Based on our experience with previous view refactoring, we'll follow these guidelines:

1. **Identify Responsibilities**: Clearly define what each component should be responsible for
2. **Extract UI Components**: Break down large views into smaller, focused components
3. **State Management**: Be careful with shared state and use appropriate patterns (bindings, environment objects)
4. **Test Coverage**: Ensure test coverage is maintained or improved
5. **Backward Compatibility**: Implement proxy pattern for seamless transition
6. **Method Signatures**: Ensure consistent method signatures when overriding methods
7. **Consistent Styling**: Maintain consistent UI styling across components
8. **Proper Imports**: Ensure each component has the necessary imports

## Estimated Timeline

- **Analysis and Planning**: 0.5 day
- **Implementation**: 1-2 days
- **Testing and Refinement**: 0.5 day

Total for SaveDocumentView: 2-3 days

## Conclusion

The successful refactoring of SettingsView, VaultView, AIResearchView, VaultViewModel, and ScanViewModel has established a proven approach for breaking down complex components. By applying the lessons learned and following a systematic approach, we expect to achieve similar improvements in code organization, maintainability, and readability for SaveDocumentView and the remaining components. Our comprehensive test planning and implementation approach will ensure high-quality refactoring with minimal regressions.

import SwiftUI

// This file exists for backward compatibility
// The actual implementation is in Views/Vault/VaultView.swift
struct VaultView: View {
    // Forward to the implementation in the Vault directory
    var body: some View {
        Views_Vault.VaultView()
    }
}
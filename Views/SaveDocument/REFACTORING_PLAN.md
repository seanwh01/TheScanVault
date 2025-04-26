# SaveDocumentView Refactoring Plan

## Current Issues

Upon initial refactoring attempts, we encountered the following issues:

1. **Type Redeclaration Errors**: Multiple declarations of `SaveDocumentView`, `SaveTagsEditView`, and `SaveFolderEditView`
2. **Stringsdata Compilation Conflicts**: Multiple commands producing the same `.stringsdata` files
3. **Maintaining Tag/Folder State Flow**: Need to preserve critical fixes for tag/folder management

## Incremental Refactoring Approach

To address these issues while maintaining the integrity of the application, we'll take an incremental approach:

### Phase 1: Organize Within Original File

1. First, we'll organize the existing `SaveDocumentView.swift` file by:
   - Clearly marking sections with MARK comments
   - Ensuring tag & folder handling use correct state flow patterns
   - Maintaining consistency with `DocumentDetailView`

2. Create the namespace file `Views_SaveDocument.swift` to prepare for future refactoring

### Phase 2: Extract Helper Extensions

1. Create extension files for components that don't introduce new View types:
   - `SDV_TagsHelpers.swift`: Methods for tag management
   - `SDV_FolderHelpers.swift`: Methods for folder management
   - `SDV_AIHelpers.swift`: Methods for AI suggestion handling

2. These helpers will be used by the original `SaveDocumentView.swift` file to reduce its complexity

### Phase 3: Extract Views With Unique Names

1. Create uniquely named views that won't conflict with existing types:
   - `SDV_TagsView.swift` instead of `TagsSection.swift`
   - `SDV_FolderView.swift` instead of `FolderSection.swift`
   - `SDV_MainView.swift` instead of `SaveDocumentMainView.swift`

2. Update the original `SaveDocumentView` to use these components

### Phase 4: Create Proxy Implementation

1. Once everything is working with the renamed components, replace the original implementation with a proxy that forwards to the new components

## Critical Code Patterns to Preserve

Based on the memories provided, these critical patterns must be maintained throughout the refactoring:

1. **Tag Deletion Flow**:
   ```swift
   // Correct pattern for removing tags:
   viewModel.metadataManager.toggleTagSelection(tagId)
   
   // Then update ViewModel from metadata manager (source of truth)
   viewModel.selectedTagIds = viewModel.metadataManager.selectedTagIds
   ```

2. **AI Suggested Tag Handling**:
   ```swift
   // Correct pattern for adding AI-suggested tags:
   viewModel.createAndSelectTag(name: tagName)
   // NOT: viewModel.selectedTagIds.insert(tagId)
   ```

3. **View Synchronization**:
   ```swift
   // Explicit update to force UI refresh
   DispatchQueue.main.async {
       viewModel.objectWillChange.send()
   }
   ```

4. **Consistent UI Between Views**:
   - Ensure folder and tag editing UI is identical between SaveDocumentView and DocumentDetailView
   - Use the same TagListView implementation in both views

## Implementation Timeline

- **Phase 1**: 0.5 day
- **Phase 2**: 0.5 day
- **Phase 3**: 1 day
- **Phase 4**: 0.5 day

## Conclusion

This incremental approach will:
1. Avoid compilation errors by eliminating type conflicts
2. Preserve critical tag/folder handling fixes
3. Maintain UI consistency between views
4. Gradually reduce the complexity of the original file
5. Allow for safer, incremental testing

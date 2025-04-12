# Test Target Membership Guide

## Files that should belong to TheScanVaultTests target:

1. **Test Files**:
   - `Tests/DocumentLockServiceTests.swift`
   - `Tests/Mocks.swift`
   - `Tests/KeychainServiceMockTests.swift`
   - Any other XCTest files in the Tests directory

2. **Test Support Files**:
   - `Tests/Info.plist`
   - Any test resources or assets

## Files that should NOT belong to TheScanVaultTests target:

1. **Main App Files**:
   - `AppServices/DocumentLockService.swift`
   - `AppServices/KeychainManager.swift`
   - `AppServices/KeychainManagerExtensions.swift`
   - Any other production code files

## How to Fix Target Membership:

1. In Xcode, select the file in the project navigator
2. Open the File Inspector (⌘⌥1 or View > Inspectors > File Inspector)
3. Under "Target Membership", check or uncheck "TheScanVaultTests" as appropriate:
   - For test files: Check "TheScanVaultTests"
   - For main app files: Check the main app target, uncheck "TheScanVaultTests"

## Special Cases:

- `KeychainManagerExtensions.swift` should be in both the main app target and the test target since it's needed to make the protocol work in both contexts.

## Verification:

After fixing target membership:
1. Clean the build folder (Shift+⌘+K)
2. Build the test target (⌘B with the test scheme selected)
3. Run tests (⌘U) 
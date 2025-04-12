//
//  ScanVaultAI_for_Mac_OSTests.swift
//  ScanVaultAI for Mac OSTests
//
//  Created by SEAN WHITE on 3/28/25.
//

import XCTest
@testable import ScanVaultAI_for_Mac_OS

// This main test class acts as a container for all our test categories
final class ScanVaultAI_for_Mac_OSTests: XCTestCase {
    
    // MARK: - Core Functionality Tests
    
    func testAppLaunches() {
        // Simple test to verify the app can be initialized
        let app = ScanVaultAI_for_Mac_OSApp()
        XCTAssertNotNil(app, "App should not be nil")
    }
    
    func testPersistenceControllerInitialization() {
        // Test in-memory persistence controller
        let inMemoryController = PersistenceController(inMemory: true)
        XCTAssertNotNil(inMemoryController, "In-memory controller should not be nil")
        XCTAssertNotNil(inMemoryController.container, "Container should not be nil")
        
        // Test shared persistence controller
        let sharedController = PersistenceController.shared
        XCTAssertNotNil(sharedController, "Shared controller should not be nil")
    }
    
    // MARK: - Integration Tests
    
    func testContentViewInitialization() {
        // Test that ContentView can be created with a managed object context
        let contentView = ContentView()
            .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
        XCTAssertNotNil(contentView, "ContentView should initialize correctly")
    }
}

// A test case for testing UI components
final class UIComponentTests: XCTestCase {
    func testFolderViewInitialization() {
        // Create test data
        let context = PersistenceController(inMemory: true).container.viewContext
        
        // Try creating FoldersView
        let foldersView = FoldersView()
            .environment(\.managedObjectContext, context)
        
        XCTAssertNotNil(foldersView, "FoldersView should initialize correctly")
    }
}

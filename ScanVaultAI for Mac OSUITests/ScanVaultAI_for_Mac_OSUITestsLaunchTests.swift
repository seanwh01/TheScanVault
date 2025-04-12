//
//  ScanVaultAI_for_Mac_OSUITestsLaunchTests.swift
//  ScanVaultAI for Mac OSUITests
//
//  Created by SEAN WHITE on 3/28/25.
//

import XCTest

final class ScanVaultAI_for_Mac_OSUITestsLaunchTests: XCTestCase {
    // Only run the launch tests once per test plan run
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for the app to be fully launched and UI to appear
        let timeout = 5.0
        let startTime = Date().timeIntervalSince1970
        
        // Wait for window to appear with a timeout
        while !app.windows.firstMatch.exists && Date().timeIntervalSince1970 - startTime < timeout {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        // Assert that the app window exists
        XCTAssertTrue(app.windows.firstMatch.exists, "App window should appear after launch")
        
        // Take a screenshot of the launch state
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // Ensure the app can be terminated
        app.terminate()
    }
}

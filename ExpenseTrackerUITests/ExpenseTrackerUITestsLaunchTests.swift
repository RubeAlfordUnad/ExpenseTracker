//
//  ExpenseTrackerUITestsLaunchTests.swift
//  ExpenseTrackerUITests
//
//  Created by Ruben Alford on 26/02/26.
//

import XCTest

final class ExpenseTrackerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-app-state"]
        app.launch()

        if app.buttons["onboarding.skip"].waitForExistence(timeout: 2) {
            app.buttons["onboarding.skip"].tap()
        }

        XCTAssertTrue(app.buttons["auth.submit"].waitForExistence(timeout: 3))
    }
}

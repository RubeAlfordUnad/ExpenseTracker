//
//  ExpenseTrackerUITests.swift
//  ExpenseTrackerUITests
//
//  Created by Ruben Alford on 26/02/26.
//

import XCTest

final class ExpenseTrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false

        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            let possibleButtons = [
                "Not Now",
                "Ahora no",
                "No ahora",
                "Don’t Save",
                "Don't Save",
                "No guardar",
                "Never",
                "Nunca",
                "Cancel",
                "Cancelar"
            ]

            for title in possibleButtons {
                if alert.buttons[title].exists {
                    alert.buttons[title].tap()
                    return true
                }
            }

            if alert.buttons.firstMatch.exists {
                alert.buttons.firstMatch.tap()
                return true
            }

            return false
        }
    }

    func testFirstLaunchCanReachAuth() throws {
        let app = makeApp()
        app.launch()

        dismissOnboardingIfNeeded(app)

        XCTAssertTrue(app.buttons["auth.mode.login"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["auth.mode.register"].exists)
        XCTAssertTrue(app.buttons["auth.submit"].exists)
    }

    func testRegisterLoginCanReachHome() throws {
        let app = makeApp()
        let username = "ui_\(UUID().uuidString.prefix(8))"
        let password = "Pass12345"

        app.launch()
        dismissOnboardingIfNeeded(app)

        registerUser(app: app, username: username, password: password)

        relaunchForCleanLogin(app)
        dismissOnboardingIfNeeded(app)

        loginUser(app: app, username: username, password: password)

        let addButton = app.buttons["expenses.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilHittable(addButton, timeout: 5))
    }

    func testOpenAddExpenseSheet() throws {
        let app = makeApp()
        let username = "ui_\(UUID().uuidString.prefix(8))"
        let password = "Pass12345"

        app.launch()
        dismissOnboardingIfNeeded(app)

        registerUser(app: app, username: username, password: password)

        relaunchForCleanLogin(app)
        dismissOnboardingIfNeeded(app)

        loginUser(app: app, username: username, password: password)

        let addButton = app.buttons["expenses.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilHittable(addButton, timeout: 5))
        addButton.tap()

        let saveButton = app.buttons["expense.save.button"]
        let cancelButton = app.buttons["expense.cancel.button"]
        let titleField = app.textFields["expense.title.field"]
        let amountField = app.textFields["expense.amount.field"]

        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(cancelButton.exists)
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        XCTAssertTrue(amountField.exists)
    }

    func testCreateExpenseAppearsInList() throws {
        let app = makeApp()
        let username = "ui_\(UUID().uuidString.prefix(8))"
        let password = "Pass12345"

        app.launch()
        dismissOnboardingIfNeeded(app)

        registerUser(app: app, username: username, password: password)

        relaunchForCleanLogin(app)
        dismissOnboardingIfNeeded(app)

        loginUser(app: app, username: username, password: password)

        let addButton = app.buttons["expenses.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilHittable(addButton, timeout: 5))
        addButton.tap()

        let titleField = app.textFields["expense.title.field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Smoke Expense")

        let amountField = app.textFields["expense.amount.field"]
        XCTAssertTrue(amountField.exists)
        amountField.tap()
        amountField.typeText("12345")

        let saveButton = app.buttons["expense.save.button"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Smoke Expense"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-app-state"]
        return app
    }

    private func relaunchForCleanLogin(_ app: XCUIApplication) {
        app.terminate()
        app.launch()
    }

    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        if app.buttons["onboarding.skip"].waitForExistence(timeout: 2) {
            app.buttons["onboarding.skip"].tap()
            return
        }

        if app.buttons["onboarding.next"].waitForExistence(timeout: 2) {
            while app.buttons["onboarding.next"].exists {
                app.buttons["onboarding.next"].tap()
            }

            if app.buttons["onboarding.getStarted"].waitForExistence(timeout: 2) {
                app.buttons["onboarding.getStarted"].tap()
            }
        }
    }

    private func registerUser(app: XCUIApplication, username: String, password: String) {
        let registerButton = app.buttons["auth.mode.register"]
        XCTAssertTrue(registerButton.waitForExistence(timeout: 3))
        registerButton.tap()

        let usernameField = app.textFields["auth.username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 3))
        usernameField.tap()
        clearTextIfNeeded(in: usernameField)
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        clearSecureTextIfNeeded(in: passwordField)
        passwordField.typeText(password)

        app.buttons["auth.submit"].tap()
        dismissSystemPasswordPromptIfNeeded(app)
    }

    private func loginUser(app: XCUIApplication, username: String, password: String) {
        let loginButton = app.buttons["auth.mode.login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3))
        loginButton.tap()

        let usernameField = app.textFields["auth.username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 3))
        usernameField.tap()
        clearTextIfNeeded(in: usernameField)
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        clearSecureTextIfNeeded(in: passwordField)
        passwordField.typeText(password)

        app.buttons["auth.submit"].tap()
        dismissSystemPasswordPromptIfNeeded(app)
    }

    private func dismissSystemPasswordPromptIfNeeded(_ app: XCUIApplication) {
        // Dispara el interruption monitor
        app.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let possibleButtons = [
            "Not Now",
            "Ahora no",
            "No ahora",
            "Don’t Save",
            "Don't Save",
            "No guardar",
            "Never",
            "Nunca",
            "Cancel",
            "Cancelar"
        ]

        for title in possibleButtons {
            let appButton = app.buttons[title]
            if appButton.waitForExistence(timeout: 1) {
                appButton.tap()
                return
            }

            let springboardButton = springboard.buttons[title]
            if springboardButton.waitForExistence(timeout: 1) {
                springboardButton.tap()
                return
            }
        }
    }

    private func clearTextIfNeeded(in element: XCUIElement) {
        guard let currentValue = element.value as? String else { return }
        if currentValue.isEmpty { return }
        if currentValue == element.placeholderValue { return }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        element.typeText(deleteString)
    }

    private func clearSecureTextIfNeeded(in element: XCUIElement) {
        guard let currentValue = element.value as? String else { return }
        if currentValue.isEmpty { return }

        let deleteCount: Int
        if currentValue == "Secure Text Field" {
            deleteCount = 20
        } else {
            deleteCount = currentValue.count
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount)
        element.typeText(deleteString)
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

private extension XCUIElement {
    var placeholderValue: String? {
        value as? String
    }
}

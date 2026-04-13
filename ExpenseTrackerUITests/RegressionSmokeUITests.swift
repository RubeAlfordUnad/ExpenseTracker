import XCTest

final class RegressionSmokeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEditIncomeFromHistoryOpensSheet() throws {
        let app = makeApp()
        let username = "ui_\(UUID().uuidString.prefix(8))"
        let password = "Pass12345"

        app.launch()
        dismissOnboardingIfNeeded(app)
        registerUser(app: app, username: username, password: password)

        relaunchForCleanLogin(app)
        dismissOnboardingIfNeeded(app)
        loginUser(app: app, username: username, password: password)

        openAddIncomeSheet(app)

        let titleField = app.textFields["income.title.field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Ingreso UITest")

        let amountField = app.textFields["income.amount.field"]
        XCTAssertTrue(amountField.exists)
        amountField.tap()
        amountField.typeText("250000")

        let saveButton = app.buttons["income.save.button"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()

        let historyTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        let menuButton = app.buttons["history.entry.menu"].firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        let editIncomeButton = app.buttons["history.edit.income"]
        XCTAssertTrue(editIncomeButton.waitForExistence(timeout: 5))
        editIncomeButton.tap()

        XCTAssertTrue(app.otherElements["income.sheet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["income.save.button"].exists)
        XCTAssertTrue(app.buttons["income.cancel.button"].exists)
    }

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
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["auth.submit"].tap()
    }

    private func loginUser(app: XCUIApplication, username: String, password: String) {
        let loginButton = app.buttons["auth.mode.login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3))
        loginButton.tap()

        let usernameField = app.textFields["auth.username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 3))
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["auth.submit"].tap()
    }

    private func openAddIncomeSheet(_ app: XCUIApplication) {
        let addMenuButton = app.buttons["main.add.menu"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: 5))
        addMenuButton.tap()

        let addIncomeButton = app.buttons["main.add.income"]
        XCTAssertTrue(addIncomeButton.waitForExistence(timeout: 3))
        addIncomeButton.tap()
    }
}

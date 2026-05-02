import XCTest

final class RegressionSmokeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCreateAccountIncomeAndEditIncomeFromHistory() throws {
        let app = makeFreshApp()
        let uniqueSuffix = String(UUID().uuidString.prefix(8))
        let accountName = "Efectivo UI \(uniqueSuffix)"
        let incomeTitle = "Ingreso UI \(uniqueSuffix)"

        app.launch()

        dismissOnboardingIfNeeded(app)
        continueInLocalMode(app)

        createMoneyAccount(app: app, name: accountName, openingBalance: "500000")
        createIncome(app: app, title: incomeTitle, amount: "250000")
        openHistoryTab(app)
        openFirstIncomeForEditing(app)

        XCTAssertTrue(app.otherElements["income.sheet"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["income.save.button"].exists)
        XCTAssertTrue(app.buttons["income.cancel.button"].exists)
    }

    private func makeFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-app-state"]
        return app
    }

    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skipButton = app.buttons["onboarding.skip"]
        if skipButton.waitForExistence(timeout: 6) {
            skipButton.tap()
            return
        }

        let nextButton = app.buttons["onboarding.next"]
        if nextButton.waitForExistence(timeout: 2) {
            var safetyCounter = 0
            while nextButton.exists && safetyCounter < 6 {
                nextButton.tap()
                safetyCounter += 1
            }

            let getStartedButton = app.buttons["onboarding.getStarted"]
            if getStartedButton.waitForExistence(timeout: 3) {
                getStartedButton.tap()
            }
        }
    }

    private func continueInLocalMode(_ app: XCUIApplication) {
        let localModeButton = app.buttons["auth.continue.local"]
        XCTAssertTrue(localModeButton.waitForExistence(timeout: 8))
        localModeButton.tap()

        XCTAssertTrue(app.buttons["main.add.menu"].waitForExistence(timeout: 12))
    }

    private func createMoneyAccount(app: XCUIApplication, name: String, openingBalance: String) {
        openHomeAddMenu(app)
        tap(app.buttons["main.add.moneyAccount"], timeout: 5)

        let nameField = app.textFields["moneyAccounts.name"]
        if !nameField.waitForExistence(timeout: 6) {
            tap(app.buttons["moneyAccounts.add"], timeout: 5)
        }

        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        nameField.tap()
        nameField.typeText(name)

        let balanceField = app.textFields["moneyAccounts.balance"]
        XCTAssertTrue(balanceField.waitForExistence(timeout: 5))
        balanceField.tap()
        balanceField.typeText(openingBalance)

        tapSaveButton(app, timeout: 5)

        XCTAssertTrue(app.buttons["moneyAccounts.add"].waitForExistence(timeout: 8))
        tapSaveButton(app, timeout: 5)

        XCTAssertTrue(app.buttons["main.add.menu"].waitForExistence(timeout: 10))
    }

    private func createIncome(app: XCUIApplication, title: String, amount: String) {
        openHomeAddMenu(app)
        tap(app.buttons["main.add.income"], timeout: 5)

        let titleField = app.textFields["income.title.field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 8))
        titleField.tap()
        titleField.typeText(title)

        let amountField = app.textFields["income.amount.field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText(amount)

        let saveButton = app.buttons["income.save.button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.buttons["main.add.menu"].waitForExistence(timeout: 10))
    }

    private func openHistoryTab(_ app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))

        let historyByPosition = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(historyByPosition.waitForExistence(timeout: 5))
        historyByPosition.tap()

        XCTAssertTrue(app.buttons["history.entry.menu"].firstMatch.waitForExistence(timeout: 10))
    }

    private func openFirstIncomeForEditing(_ app: XCUIApplication) {
        let entryMenu = app.buttons["history.entry.menu"].firstMatch
        XCTAssertTrue(entryMenu.waitForExistence(timeout: 8))
        entryMenu.tap()

        let editIncomeButton = app.buttons["history.edit.income"]
        XCTAssertTrue(editIncomeButton.waitForExistence(timeout: 8))
        editIncomeButton.tap()
    }

    private func openHomeAddMenu(_ app: XCUIApplication) {
        let addMenuButton = app.buttons["main.add.menu"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: 10))
        addMenuButton.tap()
    }

    private func tapSaveButton(
        _ app: XCUIApplication,
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let saveLabels = ["Guardar", "Save"]

        for label in saveLabels {
            let navigationButton = app.navigationBars.buttons[label].firstMatch
            if navigationButton.waitForExistence(timeout: timeout) {
                navigationButton.tap()
                return
            }
        }

        for label in saveLabels {
            let button = app.buttons[label].firstMatch
            if button.waitForExistence(timeout: timeout) {
                button.tap()
                return
            }
        }

        XCTFail("No visible save button was found.", file: file, line: line)
    }

    private func tap(
        _ element: XCUIElement,
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
        element.tap()
    }
}

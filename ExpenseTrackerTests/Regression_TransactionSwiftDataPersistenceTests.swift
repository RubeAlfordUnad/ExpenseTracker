import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - transaction SwiftData persistence")
struct RegressionTransactionSwiftDataPersistenceTests {

    @Test("Expense SwiftData persistence keeps card reference custom category and comment")
    func expenseSwiftDataPersistence_keeps_card_reference_custom_category_and_comment() {
        let user = makeUser("expensePersistence")
        let cardId = UUID()

        DataManager.shared.deleteAllLocalData(for: user)
        defer {
            DataManager.shared.deleteAllLocalData(for: user)
        }

        let expense = Expense(
            title: "Compra tarjeta",
            amount: 123_000.50,
            date: makeDate(year: 2026, month: 4, day: 29),
            category: .shopping,
            customCategoryName: "Tecnología",
            moneyAccountId: nil,
            creditCardId: cardId,
            comment: "Compra con Visa"
        )

        DataManager.shared.saveExpenses([expense], user: user)
        let loaded = DataManager.shared.loadExpenses(user: user)

        #expect(loaded.count == 1)
        #expect(loaded.first?.title == "Compra tarjeta")
        #expect(loaded.first?.amount == 123_000.50)
        #expect(loaded.first?.category == .shopping)
        #expect(loaded.first?.customCategoryName == "Tecnología")
        #expect(loaded.first?.moneyAccountId == nil)
        #expect(loaded.first?.creditCardId == cardId)
        #expect(loaded.first?.comment == "Compra con Visa")
    }

    @Test("Income SwiftData persistence keeps custom category money account and comment")
    func incomeSwiftDataPersistence_keeps_custom_category_money_account_and_comment() {
        let user = makeUser("incomePersistence")
        let accountId = UUID()

        DataManager.shared.deleteAllLocalData(for: user)
        defer {
            DataManager.shared.deleteAllLocalData(for: user)
        }

        let income = Income(
            title: "Pago cliente",
            amount: 250_000.75,
            date: makeDate(year: 2026, month: 4, day: 29),
            category: .business,
            customCategoryName: "Cliente software",
            moneyAccountId: accountId,
            comment: "Anticipo proyecto"
        )

        DataManager.shared.saveIncomes([income], user: user)
        let loaded = DataManager.shared.loadIncomes(user: user)

        #expect(loaded.count == 1)
        #expect(loaded.first?.title == "Pago cliente")
        #expect(loaded.first?.amount == 250_000.75)
        #expect(loaded.first?.category == .business)
        #expect(loaded.first?.customCategoryName == "Cliente software")
        #expect(loaded.first?.moneyAccountId == accountId)
        #expect(loaded.first?.comment == "Anticipo proyecto")
    }

    @Test("Card cycle estimator still sees persisted card expense after reload")
    func cardCycleEstimator_sees_persisted_card_expense_after_reload() {
        let user = makeUser("cardCyclePersistence")
        let cardId = UUID()

        DataManager.shared.deleteAllLocalData(for: user)
        defer {
            DataManager.shared.deleteAllLocalData(for: user)
        }

        let card = Debt(
            id: cardId,
            cardName: "Visa persistencia",
            brand: .visa,
            totalLimit: 2_000_000,
            remainingDebt: 500_000,
            kind: .creditCard,
            status: .active,
            managementFee: 15_000,
            minimumPaymentRate: 0.05,
            minimumPaymentFixedAmount: 50_000,
            statementClosingDay: 10,
            minimumPaymentDueDay: 25
        )

        let expense = Expense(
            title: "Compra dentro ciclo",
            amount: 100_000,
            date: makeDate(year: 2026, month: 4, day: 5),
            category: .shopping,
            creditCardId: cardId,
            comment: "Debe seguir asociada a la tarjeta"
        )

        DataManager.shared.saveDebts([card], user: user)
        DataManager.shared.saveExpenses([expense], user: user)

        let loadedDebts = DataManager.shared.loadDebts(user: user)
        let loadedExpenses = DataManager.shared.loadExpenses(user: user)

        guard let loadedCard = loadedDebts.first else {
            Issue.record("Expected persisted card")
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let estimate = CreditCardCyclePaymentEstimator(calendar: calendar).estimate(
            for: loadedCard,
            expenses: loadedExpenses,
            referenceDate: makeDate(year: 2026, month: 4, day: 9)
        )

        #expect(loadedExpenses.first?.creditCardId == cardId)
        #expect(estimate?.cycleExpensesTotal == 100_000)
        #expect(estimate?.estimatedTotalDue == 65_000)
    }

    private func makeUser(_ prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString)"
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        components.second = 0

        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}

import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - financial state integrity repair")
struct RegressionFinancialStateIntegrityRepairTests {

    @Test("Repair restores missing loan recurring payment backlink")
    func repair_restores_missing_loan_recurring_payment_backlink() {
        let loanId = UUID()
        let paymentId = UUID()

        let loan = Debt(
            id: loanId,
            cardName: "Ortodoncia",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 500_000,
            kind: .loan,
            status: .active,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 4,
            firstPaymentDate: makeDate(year: 2026, month: 4, day: 5),
            linkedRecurringPaymentId: nil
        )

        let payment = RecurringPayment(
            id: paymentId,
            title: "Ortodoncia",
            amount: 100_000,
            dueDay: 5,
            category: .loans,
            customCategoryName: "Préstamo",
            isActive: true,
            linkedDebtId: loanId
        )

        let snapshot = FinancialStateSnapshot(
            debts: [loan],
            recurringPayments: [payment]
        )

        let result = FinancialStateIntegrityRepairService().repair(snapshot)

        #expect(result.report.hasChanges)

        let repairedLoan = result.snapshot.debts.first
        let repairedPayment = result.snapshot.recurringPayments.first

        #expect(repairedLoan?.linkedRecurringPaymentId == paymentId)
        #expect(repairedPayment?.linkedDebtId == loanId)
    }

    @Test("Repair removes invalid recurring payment debt link")
    func repair_removes_invalid_recurring_payment_debt_link() {
        let missingDebtId = UUID()

        let payment = RecurringPayment(
            title: "Pago huérfano",
            amount: 100_000,
            dueDay: 5,
            category: .loans,
            customCategoryName: "Préstamo",
            isActive: true,
            linkedDebtId: missingDebtId
        )

        let snapshot = FinancialStateSnapshot(
            debts: [],
            recurringPayments: [payment]
        )

        let result = FinancialStateIntegrityRepairService().repair(snapshot)

        #expect(result.report.hasChanges)
        #expect(result.snapshot.recurringPayments.first?.linkedDebtId == nil)
    }

    @Test("Repair clears card recurring link and clamps card days")
    func repair_clears_card_recurring_link_and_clamps_days() {
        let paymentId = UUID()

        let card = Debt(
            cardName: "Visa",
            brand: .visa,
            totalLimit: 2_000_000,
            remainingDebt: 500_000,
            kind: .creditCard,
            status: .active,
            linkedRecurringPaymentId: paymentId,
            managementFee: 15_000,
            minimumPaymentRate: 0.05,
            minimumPaymentFixedAmount: 50_000,
            statementClosingDay: 40,
            minimumPaymentDueDay: 0
        )

        let snapshot = FinancialStateSnapshot(
            debts: [card],
            recurringPayments: []
        )

        let result = FinancialStateIntegrityRepairService().repair(snapshot)

        let repairedCard = result.snapshot.debts.first

        #expect(result.report.hasChanges)
        #expect(repairedCard?.linkedRecurringPaymentId == nil)
        #expect(repairedCard?.statementClosingDay == 31)
        #expect(repairedCard?.minimumPaymentDueDay == 1)
    }

    @Test("Repair keeps credit card expense funded only by credit card")
    func repair_keeps_credit_card_expense_funded_only_by_credit_card() {
        let accountId = UUID()
        let cardId = UUID()

        let account = MoneyAccount(
            id: accountId,
            name: "Banco",
            balance: 1_000_000,
            kind: .checking,
            includeInAvailableTotal: true
        )

        let card = Debt(
            id: cardId,
            cardName: "Visa",
            brand: .visa,
            totalLimit: 2_000_000,
            remainingDebt: 300_000,
            kind: .creditCard,
            status: .active
        )

        let expense = Expense(
            title: "Compra tarjeta",
            amount: 100_000,
            date: makeDate(year: 2026, month: 4, day: 10),
            category: .shopping,
            moneyAccountId: accountId,
            creditCardId: cardId
        )

        let snapshot = FinancialStateSnapshot(
            expenses: [expense],
            debts: [card],
            moneyAccounts: [account]
        )

        let result = FinancialStateIntegrityRepairService().repair(snapshot)

        let repairedExpense = result.snapshot.expenses.first

        #expect(result.report.hasChanges)
        #expect(repairedExpense?.creditCardId == cardId)
        #expect(repairedExpense?.moneyAccountId == nil)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}

import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - financial guards")
struct RegressionFinancialGuardsTests {

    @Test("MoneyAccountDeletionGuard detects linked records")
    func moneyAccountDeletionGuard_detects_linked_records() {
        let accountId = UUID()
        let otherAccountId = UUID()

        let expenses = [
            Expense(title: "Mercado", amount: 120_000, date: makeDate(year: 2026, month: 4, day: 10), category: .food, moneyAccountId: accountId),
            Expense(title: "Taxi", amount: 20_000, date: makeDate(year: 2026, month: 4, day: 11), category: .transport, moneyAccountId: otherAccountId)
        ]

        let incomes = [
            Income(title: "Salario", amount: 3_000_000, date: makeDate(year: 2026, month: 4, day: 1), category: .salary, moneyAccountId: accountId)
        ]

        let transfers = [
            AccountTransfer(fromAccountId: accountId, toAccountId: otherAccountId, amount: 50_000, date: makeDate(year: 2026, month: 4, day: 12)),
            AccountTransfer(fromAccountId: otherAccountId, toAccountId: accountId, amount: 30_000, date: makeDate(year: 2026, month: 4, day: 13))
        ]

        let impact = MoneyAccountDeletionGuard().impact(for: accountId, expenses: expenses, incomes: incomes, transfers: transfers)

        #expect(impact.expenseCount == 1)
        #expect(impact.incomeCount == 1)
        #expect(impact.transferCount == 2)
        #expect(impact.hasLinkedRecords == true)
    }

    @Test("DebtDeletionGuard detects linked expenses")
    func debtDeletionGuard_detects_linked_expenses() {
        let debtId = UUID()
        let otherDebtId = UUID()

        let expenses = [
            Expense(title: "Mercado", amount: 180_000, date: makeDate(year: 2026, month: 4, day: 10), category: .food, creditCardId: debtId),
            Expense(title: "Ropa", amount: 220_000, date: makeDate(year: 2026, month: 4, day: 11), category: .shopping, creditCardId: debtId),
            Expense(title: "Taxi", amount: 20_000, date: makeDate(year: 2026, month: 4, day: 12), category: .transport, creditCardId: otherDebtId)
        ]

        let impact = DebtDeletionGuard().impact(for: debtId, expenses: expenses)

        #expect(impact.expenseCount == 2)
        #expect(impact.hasLinkedRecords == true)
    }

    @Test("DebtSpendingGuard blocks new expense above available credit")
    func debtSpendingGuard_blocks_new_expense_above_available_credit() {
        let debtId = UUID()
        let debts = [Debt(id: debtId, cardName: "Visa", brand: .visa, totalLimit: 1_000_000, remainingDebt: 900_000)]

        let impact = DebtSpendingGuard().impact(requestedAmount: 150_000, selectedDebtId: debtId, existingExpense: nil, debts: debts)

        #expect(impact != nil)
        #expect(impact?.availableCredit == 100_000)
        #expect(impact?.allowedAmount == 100_000)
        #expect(impact?.exceedsLimit == true)
    }

    @Test("DebtSpendingGuard allows editing same card using previous amount")
    func debtSpendingGuard_allows_editing_same_card_using_previous_amount() {
        let debtId = UUID()
        let debts = [Debt(id: debtId, cardName: "Mastercard", brand: .mastercard, totalLimit: 1_000_000, remainingDebt: 900_000)]
        let existingExpense = Expense(title: "Compra anterior", amount: 200_000, date: makeDate(year: 2026, month: 4, day: 12), category: .shopping, creditCardId: debtId)

        let impact = DebtSpendingGuard().impact(requestedAmount: 300_000, selectedDebtId: debtId, existingExpense: existingExpense, debts: debts)

        #expect(impact != nil)
        #expect(impact?.allowedAmount == 300_000)
        #expect(impact?.exceedsLimit == false)
    }

    @Test("MoneyAccountFundsGuard blocks new expense above balance")
    func moneyAccountFundsGuard_blocks_new_expense_above_balance() {
        let accountId = UUID()
        let accounts = [MoneyAccount(id: accountId, name: "Bancolombia", balance: 100_000, kind: .checking)]

        let impact = MoneyAccountFundsGuard().expenseImpact(requestedAmount: 150_000, selectedAccountId: accountId, existingExpense: nil, accounts: accounts)

        #expect(impact != nil)
        #expect(impact?.availableBalance == 100_000)
        #expect(impact?.allowedAmount == 100_000)
        #expect(impact?.wouldGoNegative == true)
    }

    @Test("MoneyAccountFundsGuard allows editing expense on same account")
    func moneyAccountFundsGuard_allows_editing_expense_on_same_account() {
        let accountId = UUID()
        let accounts = [MoneyAccount(id: accountId, name: "Nequi", balance: 50_000, kind: .digitalWallet)]
        let existingExpense = Expense(title: "Mercado", amount: 120_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food, moneyAccountId: accountId)

        let impact = MoneyAccountFundsGuard().expenseImpact(requestedAmount: 150_000, selectedAccountId: accountId, existingExpense: existingExpense, accounts: accounts)

        #expect(impact != nil)
        #expect(impact?.availableBalance == 50_000)
        #expect(impact?.allowedAmount == 170_000)
        #expect(impact?.wouldGoNegative == false)
    }

    @Test("MoneyAccountFundsGuard validates transfers against source account balance")
    func moneyAccountFundsGuard_validates_transfers_against_source_account_balance() {
        let fromId = UUID()
        let toId = UUID()

        let accounts = [
            MoneyAccount(id: fromId, name: "Ahorros", balance: 20_000, kind: .savings),
            MoneyAccount(id: toId, name: "Caja", balance: 300_000, kind: .cash)
        ]

        let existingTransfer = AccountTransfer(fromAccountId: fromId, toAccountId: toId, amount: 30_000, date: makeDate(year: 2026, month: 4, day: 12))

        let impact = MoneyAccountFundsGuard().transferImpact(requestedAmount: 45_000, fromAccountId: fromId, existingTransfer: existingTransfer, accounts: accounts)

        #expect(impact != nil)
        #expect(impact?.allowedAmount == 50_000)
        #expect(impact?.wouldGoNegative == false)
    }

    @Test("MoneyAccountFundsGuard blocks debt payment without enough balance")
    func moneyAccountFundsGuard_blocks_debt_payment_without_enough_balance() {
        let accountId = UUID()
        let accounts = [MoneyAccount(id: accountId, name: "Davivienda", balance: 80_000, kind: .checking)]

        let impact = MoneyAccountFundsGuard().debtPaymentImpact(requestedAmount: 120_000, selectedAccountId: accountId, accounts: accounts)

        #expect(impact != nil)
        #expect(impact?.allowedAmount == 80_000)
        #expect(impact?.wouldGoNegative == true)
    }

    @Test("MoneyAccountFundsGuard blocks recurring payment without enough balance")
    func moneyAccountFundsGuard_blocks_recurring_payment_without_enough_balance() {
        let accountId = UUID()
        let accounts = [MoneyAccount(id: accountId, name: "Billetera", balance: 40_000, kind: .digitalWallet)]

        let impact = MoneyAccountFundsGuard().recurringPaymentImpact(paymentAmount: 60_000, selectedAccountId: accountId, accounts: accounts)

        #expect(impact != nil)
        #expect(impact?.allowedAmount == 40_000)
        #expect(impact?.wouldGoNegative == true)
    }

    @Test("Debt percentage can exceed one hundred while visual utilization stays capped")
    func debt_percentage_can_exceed_one_hundred_while_visual_utilization_stays_capped() {
        let debt = Debt(cardName: "Visa", brand: .visa, totalLimit: 1_000_000, remainingDebt: 1_250_000)

        #expect(debt.availableCredit == 0)
        #expect(debt.utilization == 1)
        #expect(debt.utilizationPercentage == 125)
    }
}

import Foundation

struct ImportedExpenseFinancialGuard {

    private let moneyAccountFundsGuard = MoneyAccountFundsGuard()
    private let debtSpendingGuard = DebtSpendingGuard()

    func wouldCreateInvalidState(
        expense: Expense,
        accounts: [MoneyAccount],
        debts: [Debt]
    ) -> Bool {
        if let creditCardId = expense.creditCardId {
            let impact = debtSpendingGuard.impact(
                requestedAmount: expense.amount,
                selectedDebtId: creditCardId,
                existingExpense: nil,
                debts: debts
            )

            return impact?.exceedsLimit == true
        }

        if let moneyAccountId = expense.moneyAccountId {
            let impact = moneyAccountFundsGuard.expenseImpact(
                requestedAmount: expense.amount,
                selectedAccountId: moneyAccountId,
                existingExpense: nil,
                accounts: accounts
            )

            return impact?.wouldGoNegative == true
        }

        return false
    }
}

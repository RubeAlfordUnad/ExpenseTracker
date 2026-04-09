import Foundation

struct MoneyAccountBalanceSync {

    func applyNewExpense(_ expense: Expense, to accounts: inout [MoneyAccount]) {
        adjust(accountId: expense.moneyAccountId, delta: -expense.amount, accounts: &accounts)
    }

    func applyNewIncome(_ income: Income, to accounts: inout [MoneyAccount]) {
        adjust(accountId: income.moneyAccountId, delta: income.amount, accounts: &accounts)
    }

    func applyExpenseUpdate(from oldExpense: Expense, to newExpense: Expense, accounts: inout [MoneyAccount]) {
        adjust(accountId: oldExpense.moneyAccountId, delta: oldExpense.amount, accounts: &accounts)
        adjust(accountId: newExpense.moneyAccountId, delta: -newExpense.amount, accounts: &accounts)
    }

    func applyIncomeUpdate(from oldIncome: Income, to newIncome: Income, accounts: inout [MoneyAccount]) {
        adjust(accountId: oldIncome.moneyAccountId, delta: -oldIncome.amount, accounts: &accounts)
        adjust(accountId: newIncome.moneyAccountId, delta: newIncome.amount, accounts: &accounts)
    }

    func applyExpenseDeletion(_ expense: Expense, to accounts: inout [MoneyAccount]) {
        adjust(accountId: expense.moneyAccountId, delta: expense.amount, accounts: &accounts)
    }

    func applyIncomeDeletion(_ income: Income, to accounts: inout [MoneyAccount]) {
        adjust(accountId: income.moneyAccountId, delta: -income.amount, accounts: &accounts)
    }

    private func adjust(accountId: UUID?, delta: Double, accounts: inout [MoneyAccount]) {
        guard let accountId, delta.isFinite else { return }
        guard let index = accounts.firstIndex(where: { $0.id == accountId }) else { return }

        accounts[index].balance += delta
    }
}

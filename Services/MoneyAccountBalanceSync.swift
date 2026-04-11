import Foundation

struct MoneyAccountBalanceSync {

    func applyNewExpense(_ expense: Expense, to accounts: inout [MoneyAccount]) {
        adjust(accountId: expense.moneyAccountId, delta: -expense.amount, accounts: &accounts)
    }
    
    func applyDebtPayment(amount: Double, from accountId: UUID, to accounts: inout [MoneyAccount]) {
        adjust(accountId: accountId, delta: -amount, accounts: &accounts)
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

struct ExpenseFundingSync {

    private let moneyAccountSync = MoneyAccountBalanceSync()

    func applyNewExpense(_ expense: Expense, accounts: inout [MoneyAccount], debts: inout [Debt]) {
        if let creditCardId = expense.creditCardId {
            adjustDebt(cardId: creditCardId, delta: expense.amount, debts: &debts)
            return
        }

        moneyAccountSync.applyNewExpense(expense, to: &accounts)
    }

    func applyExpenseUpdate(from oldExpense: Expense, to newExpense: Expense, accounts: inout [MoneyAccount], debts: inout [Debt]) {
        revertExpense(oldExpense, accounts: &accounts, debts: &debts)
        applyNewExpense(newExpense, accounts: &accounts, debts: &debts)
    }

    func applyExpenseDeletion(_ expense: Expense, accounts: inout [MoneyAccount], debts: inout [Debt]) {
        revertExpense(expense, accounts: &accounts, debts: &debts)
    }

    private func revertExpense(_ expense: Expense, accounts: inout [MoneyAccount], debts: inout [Debt]) {
        if let creditCardId = expense.creditCardId {
            adjustDebt(cardId: creditCardId, delta: -expense.amount, debts: &debts)
            return
        }

        moneyAccountSync.applyExpenseDeletion(expense, to: &accounts)
    }

    private func adjustDebt(cardId: UUID, delta: Double, debts: inout [Debt]) {
        guard delta.isFinite else { return }
        guard let index = debts.firstIndex(where: { $0.id == cardId }) else { return }

        let updatedBalance = debts[index].remainingDebt + delta
        debts[index].remainingDebt = max(updatedBalance, 0)
    }
}

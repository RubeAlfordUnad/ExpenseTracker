import Foundation

struct FinancialStateSnapshot {
    var expenses: [Expense]
    var incomes: [Income]
    var debts: [Debt]
    var recurringPayments: [RecurringPayment]
    var moneyAccounts: [MoneyAccount]
    var accountTransfers: [AccountTransfer]
    var accountBalanceAdjustments: [AccountBalanceAdjustment]
    var monthlyBudget: MonthlyBudget?

    init(
        expenses: [Expense] = [],
        incomes: [Income] = [],
        debts: [Debt] = [],
        recurringPayments: [RecurringPayment] = [],
        moneyAccounts: [MoneyAccount] = [],
        accountTransfers: [AccountTransfer] = [],
        accountBalanceAdjustments: [AccountBalanceAdjustment] = [],
        monthlyBudget: MonthlyBudget? = nil
    ) {
        self.expenses = expenses
        self.incomes = incomes
        self.debts = debts
        self.recurringPayments = recurringPayments
        self.moneyAccounts = moneyAccounts
        self.accountTransfers = accountTransfers
        self.accountBalanceAdjustments = accountBalanceAdjustments
        self.monthlyBudget = monthlyBudget
    }
}

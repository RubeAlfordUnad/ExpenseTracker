import Foundation

struct MoneyAccountDeletionImpact: Equatable {
    let expenseCount: Int
    let incomeCount: Int
    let transferCount: Int

    var hasLinkedRecords: Bool {
        expenseCount > 0 || incomeCount > 0 || transferCount > 0
    }
}

struct MoneyAccountDeletionGuard {

    func impact(
        for accountId: UUID,
        expenses: [Expense],
        incomes: [Income],
        transfers: [AccountTransfer]
    ) -> MoneyAccountDeletionImpact {
        let expenseCount = expenses.filter { $0.moneyAccountId == accountId }.count
        let incomeCount = incomes.filter { $0.moneyAccountId == accountId }.count
        let transferCount = transfers.filter {
            $0.fromAccountId == accountId || $0.toAccountId == accountId
        }.count

        return MoneyAccountDeletionImpact(
            expenseCount: expenseCount,
            incomeCount: incomeCount,
            transferCount: transferCount
        )
    }
}

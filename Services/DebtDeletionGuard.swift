import Foundation

struct DebtDeletionImpact: Equatable {
    let expenseCount: Int

    var hasLinkedRecords: Bool {
        expenseCount > 0
    }
}

struct DebtDeletionGuard {

    func impact(
        for debtId: UUID,
        expenses: [Expense]
    ) -> DebtDeletionImpact {
        let expenseCount = expenses.filter { $0.creditCardId == debtId }.count
        return DebtDeletionImpact(expenseCount: expenseCount)
    }
}

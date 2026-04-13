import Foundation

struct DebtSpendingImpact: Equatable {
    let debtId: UUID
    let cardName: String
    let requestedAmount: Double
    let availableCredit: Double
    let allowedAmount: Double

    var exceedsLimit: Bool {
        requestedAmount > allowedAmount + 0.0001
    }
}

struct DebtSpendingGuard {

    func impact(
        requestedAmount: Double,
        selectedDebtId: UUID?,
        existingExpense: Expense?,
        debts: [Debt]
    ) -> DebtSpendingImpact? {
        guard let selectedDebtId,
              requestedAmount.isFinite,
              requestedAmount > 0,
              let debt = debts.first(where: { $0.id == selectedDebtId }) else {
            return nil
        }

        let reusableAmount: Double
        if existingExpense?.creditCardId == selectedDebtId {
            reusableAmount = existingExpense?.amount ?? 0
        } else {
            reusableAmount = 0
        }

        let allowedAmount = max(debt.availableCredit + reusableAmount, 0)

        return DebtSpendingImpact(
            debtId: selectedDebtId,
            cardName: debt.cardName,
            requestedAmount: requestedAmount,
            availableCredit: debt.availableCredit,
            allowedAmount: allowedAmount
        )
    }
}

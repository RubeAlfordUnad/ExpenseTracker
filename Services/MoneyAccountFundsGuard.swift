import Foundation

struct MoneyAccountFundsImpact: Equatable {
    let accountId: UUID
    let accountName: String
    let requestedAmount: Double
    let availableBalance: Double
    let allowedAmount: Double

    var wouldGoNegative: Bool {
        requestedAmount > allowedAmount + 0.0001
    }
}

struct MoneyAccountFundsGuard {

    func expenseImpact(
        requestedAmount: Double,
        selectedAccountId: UUID?,
        existingExpense: Expense?,
        accounts: [MoneyAccount]
    ) -> MoneyAccountFundsImpact? {
        let reusableAmount: Double
        if existingExpense?.moneyAccountId == selectedAccountId,
           existingExpense?.creditCardId == nil {
            reusableAmount = existingExpense?.amount ?? 0
        } else {
            reusableAmount = 0
        }

        return impact(
            requestedAmount: requestedAmount,
            selectedAccountId: selectedAccountId,
            reusableAmount: reusableAmount,
            accounts: accounts
        )
    }

    func transferImpact(
        requestedAmount: Double,
        fromAccountId: UUID?,
        existingTransfer: AccountTransfer?,
        accounts: [MoneyAccount]
    ) -> MoneyAccountFundsImpact? {
        let reusableAmount: Double
        if existingTransfer?.fromAccountId == fromAccountId {
            reusableAmount = existingTransfer?.amount ?? 0
        } else {
            reusableAmount = 0
        }

        return impact(
            requestedAmount: requestedAmount,
            selectedAccountId: fromAccountId,
            reusableAmount: reusableAmount,
            accounts: accounts
        )
    }

    func debtPaymentImpact(
        requestedAmount: Double,
        selectedAccountId: UUID?,
        accounts: [MoneyAccount]
    ) -> MoneyAccountFundsImpact? {
        impact(
            requestedAmount: requestedAmount,
            selectedAccountId: selectedAccountId,
            reusableAmount: 0,
            accounts: accounts
        )
    }

    func recurringPaymentImpact(
        paymentAmount: Double,
        selectedAccountId: UUID?,
        accounts: [MoneyAccount]
    ) -> MoneyAccountFundsImpact? {
        impact(
            requestedAmount: paymentAmount,
            selectedAccountId: selectedAccountId,
            reusableAmount: 0,
            accounts: accounts
        )
    }

    private func impact(
        requestedAmount: Double,
        selectedAccountId: UUID?,
        reusableAmount: Double,
        accounts: [MoneyAccount]
    ) -> MoneyAccountFundsImpact? {
        guard let selectedAccountId,
              requestedAmount.isFinite,
              requestedAmount > 0,
              let account = accounts.first(where: { $0.id == selectedAccountId }) else {
            return nil
        }

        let allowedAmount = max(account.balance + reusableAmount, 0)

        return MoneyAccountFundsImpact(
            accountId: selectedAccountId,
            accountName: account.name,
            requestedAmount: requestedAmount,
            availableBalance: account.balance,
            allowedAmount: allowedAmount
        )
    }
}

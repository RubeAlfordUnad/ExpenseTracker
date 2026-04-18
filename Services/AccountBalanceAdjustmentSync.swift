import Foundation

struct AccountBalanceAdjustmentSync {

    private let tolerance = 0.0001

    func applyNewAdjustment(_ adjustment: AccountBalanceAdjustment, to accounts: inout [MoneyAccount]) {
        adjust(accountId: adjustment.moneyAccountId, delta: adjustment.amount, accounts: &accounts)
    }

    func applyAdjustmentUpdate(
        from oldAdjustment: AccountBalanceAdjustment,
        to newAdjustment: AccountBalanceAdjustment,
        accounts: inout [MoneyAccount]
    ) {
        adjust(accountId: oldAdjustment.moneyAccountId, delta: -oldAdjustment.amount, accounts: &accounts)
        adjust(accountId: newAdjustment.moneyAccountId, delta: newAdjustment.amount, accounts: &accounts)
    }

    func applyAdjustmentDeletion(_ adjustment: AccountBalanceAdjustment, to accounts: inout [MoneyAccount]) {
        adjust(accountId: adjustment.moneyAccountId, delta: -adjustment.amount, accounts: &accounts)
    }

    func deltaNeeded(currentBalance: Double, targetBalance: Double) -> Double? {
        guard currentBalance.isFinite, targetBalance.isFinite else { return nil }

        let delta = targetBalance - currentBalance
        return abs(delta) < tolerance ? nil : delta
    }

    private func adjust(accountId: UUID, delta: Double, accounts: inout [MoneyAccount]) {
        guard delta.isFinite else { return }
        guard let index = accounts.firstIndex(where: { $0.id == accountId }) else { return }

        accounts[index].balance += delta

        if abs(accounts[index].balance) < tolerance {
            accounts[index].balance = 0
        }
    }
}

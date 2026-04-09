import Foundation

struct MoneyAccountTransferSync {

    func applyNewTransfer(_ transfer: AccountTransfer, accounts: inout [MoneyAccount]) {
        apply(transfer, direction: .forward, accounts: &accounts)
    }

    func applyTransferUpdate(
        from oldTransfer: AccountTransfer,
        to newTransfer: AccountTransfer,
        accounts: inout [MoneyAccount]
    ) {
        apply(oldTransfer, direction: .reverse, accounts: &accounts)
        apply(newTransfer, direction: .forward, accounts: &accounts)
    }

    func applyTransferDeletion(_ transfer: AccountTransfer, accounts: inout [MoneyAccount]) {
        apply(transfer, direction: .reverse, accounts: &accounts)
    }

    private func apply(
        _ transfer: AccountTransfer,
        direction: Direction,
        accounts: inout [MoneyAccount]
    ) {
        guard transfer.amount.isFinite, transfer.amount > 0 else { return }
        guard transfer.fromAccountId != transfer.toAccountId else { return }

        let multiplier = direction == .forward ? 1.0 : -1.0

        adjust(
            accountId: transfer.fromAccountId,
            delta: -(transfer.amount * multiplier),
            accounts: &accounts
        )

        adjust(
            accountId: transfer.toAccountId,
            delta: transfer.amount * multiplier,
            accounts: &accounts
        )
    }

    private func adjust(accountId: UUID, delta: Double, accounts: inout [MoneyAccount]) {
        guard let index = accounts.firstIndex(where: { $0.id == accountId }) else { return }
        accounts[index].balance += delta
    }

    private enum Direction {
        case forward
        case reverse
    }
}

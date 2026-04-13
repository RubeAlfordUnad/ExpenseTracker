import Foundation

struct AppBackupFinancialStateSanitizer {

    private let tolerance = 0.0001

    func sanitize(_ snapshot: AppBackupSnapshot) throws -> AppBackupSnapshot {
        let sanitizedMoneyAccounts = try sanitizeMoneyAccounts(snapshot.moneyAccounts)
        let sanitizedDebts = try sanitizeDebts(snapshot.debts)

        return AppBackupSnapshot(
            version: snapshot.version,
            exportedAt: snapshot.exportedAt,
            sourceUser: snapshot.sourceUser,
            expenses: snapshot.expenses,
            incomes: snapshot.incomes,
            debts: sanitizedDebts,
            recurringPayments: snapshot.recurringPayments,
            moneyAccounts: sanitizedMoneyAccounts,
            accountTransfers: snapshot.accountTransfers,
            monthlyBudget: snapshot.monthlyBudget,
            notificationPreferences: snapshot.notificationPreferences,
            expenseCustomCategories: snapshot.expenseCustomCategories,
            incomeCustomCategories: snapshot.incomeCustomCategories,
            moneyAccountCustomCategories: snapshot.moneyAccountCustomCategories,
            profileImageData: snapshot.profileImageData,
            profileDisplayName: snapshot.profileDisplayName
        )
    }

    private func sanitizeMoneyAccounts(_ accounts: [MoneyAccount]) throws -> [MoneyAccount] {
        try accounts.map { account in
            guard account.balance.isFinite else {
                throw AppBackupError.invalidSnapshot
            }

            let normalizedBalance = abs(account.balance) <= tolerance ? 0 : account.balance

            guard normalizedBalance >= 0 else {
                throw AppBackupError.invalidSnapshot
            }

            return MoneyAccount(
                id: account.id,
                name: account.name,
                balance: normalizedBalance,
                kind: account.kind,
                customCategoryName: account.customCategoryName,
                includeInAvailableTotal: account.includeInAvailableTotal
            )
        }
    }

    private func sanitizeDebts(_ debts: [Debt]) throws -> [Debt] {
        try debts.map { debt in
            guard debt.totalLimit.isFinite, debt.remainingDebt.isFinite else {
                throw AppBackupError.invalidSnapshot
            }

            let normalizedLimit = abs(debt.totalLimit) <= tolerance ? 0 : debt.totalLimit
            var normalizedRemainingDebt = abs(debt.remainingDebt) <= tolerance ? 0 : debt.remainingDebt

            guard normalizedLimit >= 0, normalizedRemainingDebt >= 0 else {
                throw AppBackupError.invalidSnapshot
            }

            let overflow = normalizedRemainingDebt - normalizedLimit
            if overflow > 0 {
                guard overflow <= tolerance else {
                    throw AppBackupError.invalidSnapshot
                }

                normalizedRemainingDebt = normalizedLimit
            }

            return Debt(
                id: debt.id,
                cardName: debt.cardName,
                brand: debt.brand,
                totalLimit: normalizedLimit,
                remainingDebt: normalizedRemainingDebt
            )
        }
    }
}

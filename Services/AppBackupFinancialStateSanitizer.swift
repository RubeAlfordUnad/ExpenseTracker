import Foundation

struct AppBackupFinancialStateSanitizer {

    private let tolerance = 0.0001

    func sanitize(_ snapshot: AppBackupSnapshot) throws -> AppBackupSnapshot {
        let sanitizedMoneyAccounts = try sanitizeMoneyAccounts(snapshot.moneyAccounts)
        let sanitizedDebts = try sanitizeDebts(snapshot.debts)
        let sanitizedRecurringPayments = try sanitizeRecurringPayments(snapshot.recurringPayments)
        let sanitizedAdjustments = try sanitizeAccountBalanceAdjustments(snapshot.accountBalanceAdjustments)

        return AppBackupSnapshot(
            version: snapshot.version,
            exportedAt: snapshot.exportedAt,
            sourceUser: snapshot.sourceUser,
            expenses: snapshot.expenses,
            incomes: snapshot.incomes,
            debts: sanitizedDebts,
            recurringPayments: sanitizedRecurringPayments,
            moneyAccounts: sanitizedMoneyAccounts,
            accountTransfers: snapshot.accountTransfers,
            accountBalanceAdjustments: sanitizedAdjustments,
            monthlyBudget: snapshot.monthlyBudget,
            notificationPreferences: snapshot.notificationPreferences,
            expenseCustomCategories: snapshot.expenseCustomCategories,
            incomeCustomCategories: snapshot.incomeCustomCategories,
            moneyAccountCustomCategories: snapshot.moneyAccountCustomCategories,
            recurringPaymentCustomCategories: snapshot.recurringPaymentCustomCategories,
            auditLogEntries: snapshot.auditLogEntries,
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

            let normalizedOpeningBalance: Double?
            if let openingBalance = account.openingBalance {
                guard openingBalance.isFinite else {
                    throw AppBackupError.invalidSnapshot
                }

                let cleanedOpeningBalance = abs(openingBalance) <= tolerance ? 0 : openingBalance

                guard cleanedOpeningBalance >= 0 else {
                    throw AppBackupError.invalidSnapshot
                }

                normalizedOpeningBalance = cleanedOpeningBalance
            } else {
                normalizedOpeningBalance = nil
            }

            return MoneyAccount(
                id: account.id,
                name: account.name,
                balance: normalizedBalance,
                kind: account.kind,
                customCategoryName: account.customCategoryName,
                includeInAvailableTotal: account.includeInAvailableTotal,
                openingBalance: normalizedOpeningBalance,
                openingBalanceDate: account.openingBalanceDate
            )
        }
    }

    private func sanitizeDebts(_ debts: [Debt]) throws -> [Debt] {
        try debts.map { debt in
            guard debt.totalLimit.isFinite,
                  debt.remainingDebt.isFinite else {
                throw AppBackupError.invalidSnapshot
            }

            let normalizedLimit = abs(debt.totalLimit) <= tolerance ? 0 : debt.totalLimit
            var normalizedRemainingDebt = abs(debt.remainingDebt) <= tolerance ? 0 : debt.remainingDebt

            guard normalizedLimit >= 0,
                  normalizedRemainingDebt >= 0 else {
                throw AppBackupError.invalidSnapshot
            }

            let overflow = normalizedRemainingDebt - normalizedLimit
            if overflow > 0 {
                guard overflow <= tolerance else {
                    throw AppBackupError.invalidSnapshot
                }

                normalizedRemainingDebt = normalizedLimit
            }

            let normalizedMonthlyPayment: Double?
            if let monthlyPayment = debt.monthlyPayment {
                guard monthlyPayment.isFinite else {
                    throw AppBackupError.invalidSnapshot
                }

                let cleanedMonthlyPayment = abs(monthlyPayment) <= tolerance ? 0 : monthlyPayment
                guard cleanedMonthlyPayment >= 0 else {
                    throw AppBackupError.invalidSnapshot
                }

                normalizedMonthlyPayment = cleanedMonthlyPayment
            } else {
                normalizedMonthlyPayment = nil
            }

            let normalizedInstallmentCount: Int?
            if let installmentCount = debt.installmentCount {
                guard installmentCount >= 0 else {
                    throw AppBackupError.invalidSnapshot
                }

                normalizedInstallmentCount = installmentCount
            } else {
                normalizedInstallmentCount = nil
            }

            let normalizedPaymentsMade = max(debt.paymentsMade, 0)
            let cappedPaymentsMade: Int

            if let normalizedInstallmentCount {
                cappedPaymentsMade = min(normalizedPaymentsMade, normalizedInstallmentCount)
            } else {
                cappedPaymentsMade = normalizedPaymentsMade
            }

            guard debt.managementFee.isFinite,
                  debt.minimumPaymentRate.isFinite else {
                throw AppBackupError.invalidSnapshot
            }

            let normalizedManagementFee = max(abs(debt.managementFee) <= tolerance ? 0 : debt.managementFee, 0)
            let normalizedMinimumPaymentRate = min(max(debt.minimumPaymentRate, 0), 1)

            let normalizedMinimumPaymentFixedAmount: Double?
            if let fixedAmount = debt.minimumPaymentFixedAmount {
                guard fixedAmount.isFinite else {
                    throw AppBackupError.invalidSnapshot
                }

                let cleanedFixedAmount = abs(fixedAmount) <= tolerance ? 0 : fixedAmount
                guard cleanedFixedAmount >= 0 else {
                    throw AppBackupError.invalidSnapshot
                }

                normalizedMinimumPaymentFixedAmount = cleanedFixedAmount
            } else {
                normalizedMinimumPaymentFixedAmount = nil
            }

            let normalizedStatementClosingDay = normalizedDay(debt.statementClosingDay)
            let normalizedMinimumPaymentDueDay = normalizedDay(debt.minimumPaymentDueDay)

            let normalizedStatus: DebtStatus = normalizedRemainingDebt <= tolerance ? .paid : debt.status

            return Debt(
                id: debt.id,
                cardName: debt.cardName,
                brand: debt.kind == .loan ? .other : debt.brand,
                totalLimit: normalizedLimit,
                remainingDebt: normalizedRemainingDebt,
                kind: debt.kind,
                status: normalizedStatus,
                monthlyPayment: debt.kind == .loan ? normalizedMonthlyPayment : nil,
                installmentCount: debt.kind == .loan ? normalizedInstallmentCount : nil,
                paymentsMade: debt.kind == .loan ? cappedPaymentsMade : 0,
                firstPaymentDate: debt.kind == .loan ? debt.firstPaymentDate : nil,
                linkedRecurringPaymentId: debt.linkedRecurringPaymentId,
                managementFee: debt.kind == .creditCard ? normalizedManagementFee : 0,
                minimumPaymentRate: debt.kind == .creditCard ? normalizedMinimumPaymentRate : 0.05,
                minimumPaymentFixedAmount: debt.kind == .creditCard ? normalizedMinimumPaymentFixedAmount : nil,
                statementClosingDay: debt.kind == .creditCard ? normalizedStatementClosingDay : nil,
                minimumPaymentDueDay: debt.kind == .creditCard ? normalizedMinimumPaymentDueDay : nil
            )
        }
    }

    private func sanitizeRecurringPayments(_ payments: [RecurringPayment]) throws -> [RecurringPayment] {
        try payments.map { payment in
            guard payment.amount.isFinite else {
                throw AppBackupError.invalidSnapshot
            }

            let normalizedAmount = abs(payment.amount) <= tolerance ? 0 : payment.amount

            guard normalizedAmount >= 0 else {
                throw AppBackupError.invalidSnapshot
            }

            return RecurringPayment(
                id: payment.id,
                title: payment.title,
                amount: normalizedAmount,
                dueDay: min(max(payment.dueDay, 1), 31),
                category: payment.category,
                customCategoryName: payment.customCategoryName,
                isActive: payment.isActive,
                lastPaidMonth: payment.lastPaidMonth,
                lastPaidYear: payment.lastPaidYear,
                lastPaidExpenseId: payment.lastPaidExpenseId,
                linkedDebtId: payment.linkedDebtId
            )
        }
    }

    private func sanitizeAccountBalanceAdjustments(
        _ adjustments: [AccountBalanceAdjustment]
    ) throws -> [AccountBalanceAdjustment] {
        try adjustments.map { adjustment in
            guard adjustment.amount.isFinite else {
                throw AppBackupError.invalidSnapshot
            }

            let normalizedAmount = abs(adjustment.amount) <= tolerance ? 0 : adjustment.amount

            guard abs(normalizedAmount) > tolerance else {
                throw AppBackupError.invalidSnapshot
            }

            return AccountBalanceAdjustment(
                id: adjustment.id,
                moneyAccountId: adjustment.moneyAccountId,
                amount: normalizedAmount,
                date: adjustment.date,
                reason: adjustment.reason,
                createdAt: adjustment.createdAt
            )
        }
    }

    private func normalizedDay(_ day: Int?) -> Int? {
        guard let day else { return nil }
        return min(max(day, 1), 31)
    }
}

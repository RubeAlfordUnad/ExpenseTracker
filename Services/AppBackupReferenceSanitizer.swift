import Foundation

struct AppBackupReferenceSanitizer {

    func sanitize(_ snapshot: AppBackupSnapshot) -> AppBackupSnapshot {
        let validAccountIds = Set(snapshot.moneyAccounts.map(\.id))
        let validDebtIds = Set(snapshot.debts.map(\.id))
        let validExpenseIds = Set(snapshot.expenses.map(\.id))
        let validRecurringPaymentIds = Set(snapshot.recurringPayments.map(\.id))

        let sanitizedExpenses = snapshot.expenses.map { expense in
            let validCreditCardId = expense.creditCardId.flatMap { validDebtIds.contains($0) ? $0 : nil }
            let validMoneyAccountId = expense.moneyAccountId.flatMap { validAccountIds.contains($0) ? $0 : nil }

            let resolvedCreditCardId = validCreditCardId
            let resolvedMoneyAccountId = resolvedCreditCardId == nil ? validMoneyAccountId : nil

            return Expense(
                id: expense.id,
                title: expense.title,
                amount: expense.amount,
                date: expense.date,
                category: expense.category,
                customCategoryName: expense.customCategoryName,
                moneyAccountId: resolvedMoneyAccountId,
                creditCardId: resolvedCreditCardId,
                comment: expense.comment
            )
        }

        let sanitizedIncomes = snapshot.incomes.map { income in
            let validMoneyAccountId = income.moneyAccountId.flatMap { validAccountIds.contains($0) ? $0 : nil }

            return Income(
                id: income.id,
                title: income.title,
                amount: income.amount,
                date: income.date,
                category: income.category,
                customCategoryName: income.customCategoryName,
                moneyAccountId: validMoneyAccountId,
                comment: income.comment
            )
        }

        let sanitizedDebts = snapshot.debts.map { debt in
            let validLinkedRecurringPaymentId = debt.linkedRecurringPaymentId.flatMap {
                validRecurringPaymentIds.contains($0) ? $0 : nil
            }

            return Debt(
                id: debt.id,
                cardName: debt.cardName,
                brand: debt.brand,
                totalLimit: debt.totalLimit,
                remainingDebt: debt.remainingDebt,
                kind: debt.kind,
                status: debt.status,
                monthlyPayment: debt.monthlyPayment,
                installmentCount: debt.installmentCount,
                paymentsMade: debt.paymentsMade,
                firstPaymentDate: debt.firstPaymentDate,
                linkedRecurringPaymentId: validLinkedRecurringPaymentId,
                managementFee: debt.managementFee,
                minimumPaymentRate: debt.minimumPaymentRate,
                minimumPaymentFixedAmount: debt.minimumPaymentFixedAmount,
                statementClosingDay: debt.statementClosingDay,
                minimumPaymentDueDay: debt.minimumPaymentDueDay
            )
        }

        let sanitizedRecurringPayments = snapshot.recurringPayments.map { payment in
            let validExpenseId = payment.lastPaidExpenseId.flatMap { validExpenseIds.contains($0) ? $0 : nil }
            let validLinkedDebtId = payment.linkedDebtId.flatMap { validDebtIds.contains($0) ? $0 : nil }

            let shouldKeepPaidState = validExpenseId != nil
                && payment.lastPaidMonth != nil
                && payment.lastPaidYear != nil

            return RecurringPayment(
                id: payment.id,
                title: payment.title,
                amount: payment.amount,
                dueDay: payment.dueDay,
                category: payment.category,
                customCategoryName: payment.customCategoryName,
                isActive: payment.isActive,
                lastPaidMonth: shouldKeepPaidState ? payment.lastPaidMonth : nil,
                lastPaidYear: shouldKeepPaidState ? payment.lastPaidYear : nil,
                lastPaidExpenseId: shouldKeepPaidState ? validExpenseId : nil,
                linkedDebtId: validLinkedDebtId
            )
        }

        let sanitizedAccountTransfers = snapshot.accountTransfers.filter {
            validAccountIds.contains($0.fromAccountId)
            && validAccountIds.contains($0.toAccountId)
            && $0.fromAccountId != $0.toAccountId
        }

        let sanitizedAccountBalanceAdjustments = snapshot.accountBalanceAdjustments.filter {
            validAccountIds.contains($0.moneyAccountId)
        }

        let sanitizedAuditLogEntries = snapshot.auditLogEntries.map { entry in
            AuditLogEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                entity: entry.entity,
                entityId: sanitizedAuditEntityId(
                    entry.entityId,
                    entity: entry.entity,
                    validAccountIds: validAccountIds,
                    validDebtIds: validDebtIds,
                    validExpenseIds: validExpenseIds,
                    validIncomeIds: Set(snapshot.incomes.map(\.id)),
                    validRecurringPaymentIds: validRecurringPaymentIds,
                    validTransferIds: Set(snapshot.accountTransfers.map(\.id))
                ),
                action: entry.action,
                title: entry.title,
                detail: entry.detail,
                originalValue: entry.originalValue,
                originalTimestamp: entry.originalTimestamp,
                previousValue: entry.previousValue,
                previousTimestamp: entry.previousTimestamp,
                newValue: entry.newValue,
                newTimestamp: entry.newTimestamp,
                note: entry.note
            )
        }

        return AppBackupSnapshot(
            version: snapshot.version,
            exportedAt: snapshot.exportedAt,
            sourceUser: snapshot.sourceUser,
            expenses: sanitizedExpenses,
            incomes: sanitizedIncomes,
            debts: sanitizedDebts,
            recurringPayments: sanitizedRecurringPayments,
            moneyAccounts: snapshot.moneyAccounts,
            accountTransfers: sanitizedAccountTransfers,
            accountBalanceAdjustments: sanitizedAccountBalanceAdjustments,
            monthlyBudget: snapshot.monthlyBudget,
            notificationPreferences: snapshot.notificationPreferences,
            expenseCustomCategories: snapshot.expenseCustomCategories,
            incomeCustomCategories: snapshot.incomeCustomCategories,
            moneyAccountCustomCategories: snapshot.moneyAccountCustomCategories,
            recurringPaymentCustomCategories: snapshot.recurringPaymentCustomCategories,
            auditLogEntries: sanitizedAuditLogEntries,
            profileImageData: snapshot.profileImageData,
            profileDisplayName: snapshot.profileDisplayName
        )
    }

    private func sanitizedAuditEntityId(
        _ id: UUID?,
        entity: AuditLogEntity,
        validAccountIds: Set<UUID>,
        validDebtIds: Set<UUID>,
        validExpenseIds: Set<UUID>,
        validIncomeIds: Set<UUID>,
        validRecurringPaymentIds: Set<UUID>,
        validTransferIds: Set<UUID>
    ) -> UUID? {
        guard let id else { return nil }

        switch entity {
        case .expense:
            return validExpenseIds.contains(id) ? id : nil
        case .income:
            return validIncomeIds.contains(id) ? id : nil
        case .transfer:
            return validTransferIds.contains(id) ? id : nil
        case .moneyAccount:
            return validAccountIds.contains(id) ? id : nil
        case .debt:
            return validDebtIds.contains(id) ? id : nil
        case .recurringPayment:
            return validRecurringPaymentIds.contains(id) ? id : nil
        case .budget:
            return id
        }
    }
}

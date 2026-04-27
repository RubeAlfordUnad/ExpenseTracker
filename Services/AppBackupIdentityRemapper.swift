import Foundation

struct AppBackupIdentityRemapper {

    func remap(_ snapshot: AppBackupSnapshot) -> AppBackupSnapshot {
        let moneyAccountIDMap = makeMap(for: snapshot.moneyAccounts.map(\.id))
        let debtIDMap = makeMap(for: snapshot.debts.map(\.id))
        let expenseIDMap = makeMap(for: snapshot.expenses.map(\.id))
        let incomeIDMap = makeMap(for: snapshot.incomes.map(\.id))
        let recurringPaymentIDMap = makeMap(for: snapshot.recurringPayments.map(\.id))
        let transferIDMap = makeMap(for: snapshot.accountTransfers.map(\.id))
        let adjustmentIDMap = makeMap(for: snapshot.accountBalanceAdjustments.map(\.id))

        let remappedMoneyAccounts = snapshot.moneyAccounts.map { account in
            MoneyAccount(
                id: moneyAccountIDMap[account.id] ?? account.id,
                name: account.name,
                balance: account.balance,
                kind: account.kind,
                customCategoryName: account.customCategoryName,
                includeInAvailableTotal: account.includeInAvailableTotal,
                openingBalance: account.openingBalance,
                openingBalanceDate: account.openingBalanceDate
            )
        }

        let remappedDebts = snapshot.debts.map { debt in
            Debt(
                id: debtIDMap[debt.id] ?? debt.id,
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
                linkedRecurringPaymentId: debt.linkedRecurringPaymentId.flatMap { recurringPaymentIDMap[$0] },
                managementFee: debt.managementFee,
                minimumPaymentRate: debt.minimumPaymentRate,
                minimumPaymentFixedAmount: debt.minimumPaymentFixedAmount,
                statementClosingDay: debt.statementClosingDay,
                minimumPaymentDueDay: debt.minimumPaymentDueDay
            )
        }

        let remappedExpenses = snapshot.expenses.map { expense in
            Expense(
                id: expenseIDMap[expense.id] ?? expense.id,
                title: expense.title,
                amount: expense.amount,
                date: expense.date,
                category: expense.category,
                customCategoryName: expense.customCategoryName,
                moneyAccountId: expense.moneyAccountId.flatMap { moneyAccountIDMap[$0] },
                creditCardId: expense.creditCardId.flatMap { debtIDMap[$0] },
                comment: expense.comment
            )
        }

        let remappedIncomes = snapshot.incomes.map { income in
            Income(
                id: incomeIDMap[income.id] ?? income.id,
                title: income.title,
                amount: income.amount,
                date: income.date,
                category: income.category,
                customCategoryName: income.customCategoryName,
                moneyAccountId: income.moneyAccountId.flatMap { moneyAccountIDMap[$0] },
                comment: income.comment
            )
        }

        let remappedRecurringPayments = snapshot.recurringPayments.map { payment in
            RecurringPayment(
                id: recurringPaymentIDMap[payment.id] ?? payment.id,
                title: payment.title,
                amount: payment.amount,
                dueDay: payment.dueDay,
                category: payment.category,
                customCategoryName: payment.customCategoryName,
                isActive: payment.isActive,
                lastPaidMonth: payment.lastPaidMonth,
                lastPaidYear: payment.lastPaidYear,
                lastPaidExpenseId: payment.lastPaidExpenseId.flatMap { expenseIDMap[$0] },
                linkedDebtId: payment.linkedDebtId.flatMap { debtIDMap[$0] }
            )
        }

        let remappedTransfers: [AccountTransfer] = snapshot.accountTransfers.compactMap { transfer -> AccountTransfer? in
            guard let fromAccountId = moneyAccountIDMap[transfer.fromAccountId],
                  let toAccountId = moneyAccountIDMap[transfer.toAccountId],
                  fromAccountId != toAccountId else {
                return nil
            }

            return AccountTransfer(
                id: transferIDMap[transfer.id] ?? transfer.id,
                fromAccountId: fromAccountId,
                toAccountId: toAccountId,
                amount: transfer.amount,
                date: transfer.date,
                note: transfer.note
            )
        }

        let remappedAccountBalanceAdjustments: [AccountBalanceAdjustment] = snapshot.accountBalanceAdjustments.compactMap { adjustment in
            guard let remappedAccountId = moneyAccountIDMap[adjustment.moneyAccountId] else {
                return nil
            }

            return AccountBalanceAdjustment(
                id: adjustmentIDMap[adjustment.id] ?? adjustment.id,
                moneyAccountId: remappedAccountId,
                amount: adjustment.amount,
                date: adjustment.date,
                reason: adjustment.reason,
                createdAt: adjustment.createdAt
            )
        }

        let remappedAuditLogEntries = snapshot.auditLogEntries.map { entry in
            AuditLogEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                entity: entry.entity,
                entityId: remappedAuditEntityId(
                    entry.entityId,
                    entity: entry.entity,
                    moneyAccountIDMap: moneyAccountIDMap,
                    debtIDMap: debtIDMap,
                    expenseIDMap: expenseIDMap,
                    incomeIDMap: incomeIDMap,
                    recurringPaymentIDMap: recurringPaymentIDMap,
                    transferIDMap: transferIDMap
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
            expenses: remappedExpenses,
            incomes: remappedIncomes,
            debts: remappedDebts,
            recurringPayments: remappedRecurringPayments,
            moneyAccounts: remappedMoneyAccounts,
            accountTransfers: remappedTransfers,
            accountBalanceAdjustments: remappedAccountBalanceAdjustments,
            monthlyBudget: snapshot.monthlyBudget,
            notificationPreferences: snapshot.notificationPreferences,
            expenseCustomCategories: snapshot.expenseCustomCategories,
            incomeCustomCategories: snapshot.incomeCustomCategories,
            moneyAccountCustomCategories: snapshot.moneyAccountCustomCategories,
            recurringPaymentCustomCategories: snapshot.recurringPaymentCustomCategories,
            auditLogEntries: remappedAuditLogEntries,
            profileImageData: snapshot.profileImageData,
            profileDisplayName: snapshot.profileDisplayName
        )
    }

    private func remappedAuditEntityId(
        _ id: UUID?,
        entity: AuditLogEntity,
        moneyAccountIDMap: [UUID: UUID],
        debtIDMap: [UUID: UUID],
        expenseIDMap: [UUID: UUID],
        incomeIDMap: [UUID: UUID],
        recurringPaymentIDMap: [UUID: UUID],
        transferIDMap: [UUID: UUID]
    ) -> UUID? {
        guard let id else { return nil }

        switch entity {
        case .expense:
            return expenseIDMap[id] ?? id
        case .income:
            return incomeIDMap[id] ?? id
        case .transfer:
            return transferIDMap[id] ?? id
        case .moneyAccount:
            return moneyAccountIDMap[id] ?? id
        case .debt:
            return debtIDMap[id] ?? id
        case .recurringPayment:
            return recurringPaymentIDMap[id] ?? id
        case .budget:
            return id
        }
    }

    private func makeMap(for ids: [UUID]) -> [UUID: UUID] {
        var map: [UUID: UUID] = [:]

        for id in ids where map[id] == nil {
            map[id] = UUID()
        }

        return map
    }
}

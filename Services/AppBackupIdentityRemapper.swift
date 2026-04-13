import Foundation

struct AppBackupIdentityRemapper {

    func remap(_ snapshot: AppBackupSnapshot) -> AppBackupSnapshot {
        let moneyAccountIDMap = makeMap(for: snapshot.moneyAccounts.map(\.id))
        let debtIDMap = makeMap(for: snapshot.debts.map(\.id))
        let expenseIDMap = makeMap(for: snapshot.expenses.map(\.id))
        let incomeIDMap = makeMap(for: snapshot.incomes.map(\.id))
        let recurringPaymentIDMap = makeMap(for: snapshot.recurringPayments.map(\.id))
        let transferIDMap = makeMap(for: snapshot.accountTransfers.map(\.id))

        let remappedMoneyAccounts = snapshot.moneyAccounts.map { account in
            MoneyAccount(
                id: moneyAccountIDMap[account.id] ?? account.id,
                name: account.name,
                balance: account.balance,
                kind: account.kind,
                customCategoryName: account.customCategoryName,
                includeInAvailableTotal: account.includeInAvailableTotal
            )
        }

        let remappedDebts = snapshot.debts.map { debt in
            Debt(
                id: debtIDMap[debt.id] ?? debt.id,
                cardName: debt.cardName,
                brand: debt.brand,
                totalLimit: debt.totalLimit,
                remainingDebt: debt.remainingDebt
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
                isActive: payment.isActive,
                lastPaidMonth: payment.lastPaidMonth,
                lastPaidYear: payment.lastPaidYear,
                lastPaidExpenseId: payment.lastPaidExpenseId.flatMap { expenseIDMap[$0] }
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
            monthlyBudget: snapshot.monthlyBudget,
            notificationPreferences: snapshot.notificationPreferences,
            expenseCustomCategories: snapshot.expenseCustomCategories,
            incomeCustomCategories: snapshot.incomeCustomCategories,
            moneyAccountCustomCategories: snapshot.moneyAccountCustomCategories,
            profileImageData: snapshot.profileImageData,
            profileDisplayName: snapshot.profileDisplayName
        )
    }

    private func makeMap(for ids: [UUID]) -> [UUID: UUID] {
        var map: [UUID: UUID] = [:]

        for id in ids where map[id] == nil {
            map[id] = UUID()
        }

        return map
    }
}

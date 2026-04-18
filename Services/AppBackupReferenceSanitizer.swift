import Foundation

struct AppBackupReferenceSanitizer {

    func sanitize(_ snapshot: AppBackupSnapshot) -> AppBackupSnapshot {
        let validAccountIds = Set(snapshot.moneyAccounts.map(\.id))
        let validDebtIds = Set(snapshot.debts.map(\.id))
        let validExpenseIds = Set(snapshot.expenses.map(\.id))

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

        let sanitizedRecurringPayments = snapshot.recurringPayments.map { payment in
            let validExpenseId = payment.lastPaidExpenseId.flatMap { validExpenseIds.contains($0) ? $0 : nil }
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
                lastPaidExpenseId: shouldKeepPaidState ? validExpenseId : nil
            )
        }

        let sanitizedAccountBalanceAdjustments = snapshot.accountBalanceAdjustments.filter {
            validAccountIds.contains($0.moneyAccountId)
        }

        return AppBackupSnapshot(
            version: snapshot.version,
            exportedAt: snapshot.exportedAt,
            sourceUser: snapshot.sourceUser,
            expenses: sanitizedExpenses,
            incomes: sanitizedIncomes,
            debts: snapshot.debts,
            recurringPayments: sanitizedRecurringPayments,
            moneyAccounts: snapshot.moneyAccounts,
            accountTransfers: snapshot.accountTransfers,
            accountBalanceAdjustments: sanitizedAccountBalanceAdjustments,
            monthlyBudget: snapshot.monthlyBudget,
            notificationPreferences: snapshot.notificationPreferences,
            expenseCustomCategories: snapshot.expenseCustomCategories,
            incomeCustomCategories: snapshot.incomeCustomCategories,
            moneyAccountCustomCategories: snapshot.moneyAccountCustomCategories,
            recurringPaymentCustomCategories: snapshot.recurringPaymentCustomCategories,
            profileImageData: snapshot.profileImageData,
            profileDisplayName: snapshot.profileDisplayName
        )
    }
}

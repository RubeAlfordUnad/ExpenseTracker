import Foundation

struct RecurringGeneratedExpenseDeletionSyncEvent {
    let deletedExpenseId: UUID
    let previousPayment: RecurringPayment
    let updatedPayment: RecurringPayment
    let previousDebt: Debt?
    let updatedDebt: Debt?
}

struct RecurringGeneratedExpenseDeletionSyncResult {
    let recurringPayments: [RecurringPayment]
    let debts: [Debt]
    let events: [RecurringGeneratedExpenseDeletionSyncEvent]

    var hasChanges: Bool {
        !events.isEmpty
    }
}

struct RecurringGeneratedExpenseDeletionSync {

    func repairAfterDeletingGeneratedExpense(
        expenseId: UUID,
        recurringPayments: [RecurringPayment],
        debts: [Debt]
    ) -> RecurringGeneratedExpenseDeletionSyncResult {
        var updatedPayments = recurringPayments
        var updatedDebts = debts
        var events: [RecurringGeneratedExpenseDeletionSyncEvent] = []

        for paymentIndex in updatedPayments.indices {
            guard updatedPayments[paymentIndex].lastPaidExpenseId == expenseId else {
                continue
            }

            let previousPayment = updatedPayments[paymentIndex]
            var previousDebt: Debt?
            var updatedDebt: Debt?

            if let linkedDebtId = previousPayment.linkedDebtId,
               let debtIndex = updatedDebts.firstIndex(where: { $0.id == linkedDebtId }),
               updatedDebts[debtIndex].isLoan {
                previousDebt = updatedDebts[debtIndex]

                updatedDebts[debtIndex].revertPayment(previousPayment.amount)
                updatedDebt = updatedDebts[debtIndex]
            }

            updatedPayments[paymentIndex].lastPaidMonth = nil
            updatedPayments[paymentIndex].lastPaidYear = nil
            updatedPayments[paymentIndex].lastPaidExpenseId = nil

            events.append(
                RecurringGeneratedExpenseDeletionSyncEvent(
                    deletedExpenseId: expenseId,
                    previousPayment: previousPayment,
                    updatedPayment: updatedPayments[paymentIndex],
                    previousDebt: previousDebt,
                    updatedDebt: updatedDebt
                )
            )
        }

        return RecurringGeneratedExpenseDeletionSyncResult(
            recurringPayments: updatedPayments,
            debts: updatedDebts,
            events: events
        )
    }
}

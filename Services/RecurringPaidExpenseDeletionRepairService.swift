import Foundation

struct RecurringPaidExpenseDeletionRepairEvent {
    let missingExpenseId: UUID
    let previousPayment: RecurringPayment
    let updatedPayment: RecurringPayment
    let previousDebt: Debt?
    let updatedDebt: Debt?
}

struct RecurringPaidExpenseDeletionRepairResult {
    let recurringPayments: [RecurringPayment]
    let debts: [Debt]
    let events: [RecurringPaidExpenseDeletionRepairEvent]

    var hasChanges: Bool {
        !events.isEmpty
    }
}

struct RecurringPaidExpenseDeletionRepairService {

    func repairDeletedGeneratedExpenses(
        currentExpenses: [Expense],
        recurringPayments: [RecurringPayment],
        debts: [Debt]
    ) -> RecurringPaidExpenseDeletionRepairResult {
        let currentExpenseIds = Set(currentExpenses.map(\.id))

        var repairedPayments = recurringPayments
        var repairedDebts = debts
        var events: [RecurringPaidExpenseDeletionRepairEvent] = []

        for index in repairedPayments.indices {
            guard let lastPaidExpenseId = repairedPayments[index].lastPaidExpenseId else {
                continue
            }

            guard !currentExpenseIds.contains(lastPaidExpenseId) else {
                continue
            }

            let previousPayment = repairedPayments[index]
            var previousDebt: Debt?
            var updatedDebt: Debt?

            if let linkedDebtId = previousPayment.linkedDebtId,
               let debtIndex = repairedDebts.firstIndex(where: { $0.id == linkedDebtId }),
               repairedDebts[debtIndex].isLoan {
                previousDebt = repairedDebts[debtIndex]

                if repairedDebts[debtIndex].isPaid {
                    repairedDebts[debtIndex].status = .active
                }

                repairedDebts[debtIndex].revertPayment(previousPayment.amount)
                updatedDebt = repairedDebts[debtIndex]
            }

            repairedPayments[index].lastPaidMonth = nil
            repairedPayments[index].lastPaidYear = nil
            repairedPayments[index].lastPaidExpenseId = nil

            events.append(
                RecurringPaidExpenseDeletionRepairEvent(
                    missingExpenseId: lastPaidExpenseId,
                    previousPayment: previousPayment,
                    updatedPayment: repairedPayments[index],
                    previousDebt: previousDebt,
                    updatedDebt: updatedDebt
                )
            )
        }

        return RecurringPaidExpenseDeletionRepairResult(
            recurringPayments: repairedPayments,
            debts: repairedDebts,
            events: events
        )
    }
}

import Foundation

struct RecurringLoanPaymentSyncResult {
    let previousDebt: Debt?
    let updatedDebt: Debt?

    static let noLinkedLoan = RecurringLoanPaymentSyncResult(
        previousDebt: nil,
        updatedDebt: nil
    )

    var didUpdateLoan: Bool {
        previousDebt != nil && updatedDebt != nil
    }

    var shouldAskToArchivePaidLoan: Bool {
        guard let previousDebt,
              let updatedDebt else {
            return false
        }

        return previousDebt.isActive
            && updatedDebt.isLoan
            && updatedDebt.isFullyPaid
            && updatedDebt.status == .active
    }
}

struct RecurringLoanPaymentSync {

    func applyRecurringPayment(
        _ payment: RecurringPayment,
        debts: inout [Debt]
    ) -> RecurringLoanPaymentSyncResult {
        guard payment.amount.isFinite,
              payment.amount > 0,
              let linkedDebtId = payment.linkedDebtId,
              let index = debts.firstIndex(where: { $0.id == linkedDebtId }),
              debts[index].isLoan,
              debts[index].isActive else {
            return .noLinkedLoan
        }

        let previousDebt = debts[index]
        debts[index].applyPayment(payment.amount)

        return RecurringLoanPaymentSyncResult(
            previousDebt: previousDebt,
            updatedDebt: debts[index]
        )
    }

    func revertRecurringPayment(
        _ payment: RecurringPayment,
        debts: inout [Debt]
    ) -> RecurringLoanPaymentSyncResult {
        guard payment.amount.isFinite,
              payment.amount > 0,
              let linkedDebtId = payment.linkedDebtId,
              let index = debts.firstIndex(where: { $0.id == linkedDebtId }),
              debts[index].isLoan else {
            return .noLinkedLoan
        }

        let previousDebt = debts[index]
        debts[index].revertPayment(payment.amount)

        return RecurringLoanPaymentSyncResult(
            previousDebt: previousDebt,
            updatedDebt: debts[index]
        )
    }
}

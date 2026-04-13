import Foundation

struct RecurringPaymentExpenseSync {

    @discardableResult
    func clearPaidStatusLinked(
        to expenseId: UUID,
        payments: inout [RecurringPayment]
    ) -> Int {
        var clearedCount = 0

        for index in payments.indices where payments[index].lastPaidExpenseId == expenseId {
            payments[index].lastPaidMonth = nil
            payments[index].lastPaidYear = nil
            payments[index].lastPaidExpenseId = nil
            clearedCount += 1
        }

        return clearedCount
    }
}

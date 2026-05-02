import Foundation

struct FinancialStateIntegrityRepairReport {
    var repairedDebts = 0
    var repairedRecurringPayments = 0
    var repairedExpenses = 0
    var removedInvalidTransfers = 0
    var removedInvalidAdjustments = 0

    var hasChanges: Bool {
        repairedDebts > 0
        || repairedRecurringPayments > 0
        || repairedExpenses > 0
        || removedInvalidTransfers > 0
        || removedInvalidAdjustments > 0
    }

    var summary: String {
        """
        Financial integrity repair:
        debts=\(repairedDebts)
        recurringPayments=\(repairedRecurringPayments)
        expenses=\(repairedExpenses)
        removedTransfers=\(removedInvalidTransfers)
        removedAdjustments=\(removedInvalidAdjustments)
        """
    }
}

struct FinancialStateIntegrityRepairResult {
    let snapshot: FinancialStateSnapshot
    let report: FinancialStateIntegrityRepairReport
}

struct FinancialStateIntegrityRepairService {

    private let tolerance = 0.0001

    func repair(_ snapshot: FinancialStateSnapshot) -> FinancialStateIntegrityRepairResult {
        var report = FinancialStateIntegrityRepairReport()

        var debts = repairDebts(snapshot.debts, report: &report)
        var recurringPayments = repairRecurringPayments(
            snapshot.recurringPayments,
            report: &report
        )

        repairDebtRecurringLinks(
            debts: &debts,
            recurringPayments: &recurringPayments,
            report: &report
        )

        let validAccountIds = Set(snapshot.moneyAccounts.map(\.id))
        let validDebtIds = Set(debts.map(\.id))
        let validExpenseIds = Set(snapshot.expenses.map(\.id))

        let expenses = repairExpenses(
            snapshot.expenses,
            validAccountIds: validAccountIds,
            validDebtIds: validDebtIds,
            report: &report
        )

        recurringPayments = repairRecurringPaymentPaidState(
            recurringPayments,
            validExpenseIds: Set(expenses.map(\.id)),
            report: &report
        )

        let validTransfers = snapshot.accountTransfers.filter { transfer in
            validAccountIds.contains(transfer.fromAccountId)
            && validAccountIds.contains(transfer.toAccountId)
            && transfer.fromAccountId != transfer.toAccountId
            && transfer.amount.isFinite
            && transfer.amount > 0
        }

        if validTransfers.count != snapshot.accountTransfers.count {
            report.removedInvalidTransfers += snapshot.accountTransfers.count - validTransfers.count
        }

        let validAdjustments = snapshot.accountBalanceAdjustments.filter { adjustment in
            validAccountIds.contains(adjustment.moneyAccountId)
            && adjustment.amount.isFinite
            && abs(adjustment.amount) > tolerance
        }

        if validAdjustments.count != snapshot.accountBalanceAdjustments.count {
            report.removedInvalidAdjustments += snapshot.accountBalanceAdjustments.count - validAdjustments.count
        }

        let repairedSnapshot = FinancialStateSnapshot(
            expenses: expenses,
            incomes: snapshot.incomes,
            debts: debts,
            recurringPayments: recurringPayments,
            moneyAccounts: snapshot.moneyAccounts,
            accountTransfers: validTransfers,
            accountBalanceAdjustments: validAdjustments,
            monthlyBudget: snapshot.monthlyBudget
        )

        return FinancialStateIntegrityRepairResult(
            snapshot: repairedSnapshot,
            report: report
        )
    }

    private func repairDebts(
        _ debts: [Debt],
        report: inout FinancialStateIntegrityRepairReport
    ) -> [Debt] {
        var seenIds = Set<UUID>()

        return debts.compactMap { debt in
            guard !seenIds.contains(debt.id) else {
                report.repairedDebts += 1
                return nil
            }

            seenIds.insert(debt.id)

            let cleanedName = debt.cardName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = cleanedName.isEmpty ? "Deuda sin nombre" : cleanedName

            let cleanedRemainingDebt = normalizedNonNegativeAmount(debt.remainingDebt)
            let cleanedTotalLimit = max(
                normalizedNonNegativeAmount(debt.totalLimit),
                cleanedRemainingDebt
            )

            var status = debt.status

            if cleanedRemainingDebt > tolerance, status == .paid {
                status = .active
            }

            let cleanedDebt: Debt

            if debt.isLoan {
                let installmentCount = normalizedInstallmentCount(debt.installmentCount)
                let paymentsMade = normalizedPaymentsMade(
                    debt.paymentsMade,
                    installmentCount: installmentCount
                )

                cleanedDebt = Debt(
                    id: debt.id,
                    cardName: name,
                    brand: .other,
                    totalLimit: cleanedTotalLimit,
                    remainingDebt: cleanedRemainingDebt,
                    kind: .loan,
                    status: status,
                    monthlyPayment: normalizedOptionalPositiveAmount(debt.monthlyPayment),
                    installmentCount: installmentCount,
                    paymentsMade: paymentsMade,
                    firstPaymentDate: debt.firstPaymentDate,
                    linkedRecurringPaymentId: debt.linkedRecurringPaymentId,
                    managementFee: 0,
                    minimumPaymentRate: 0.05,
                    minimumPaymentFixedAmount: nil,
                    statementClosingDay: nil,
                    minimumPaymentDueDay: nil
                )
            } else {
                cleanedDebt = Debt(
                    id: debt.id,
                    cardName: name,
                    brand: debt.brand,
                    totalLimit: cleanedTotalLimit,
                    remainingDebt: cleanedRemainingDebt,
                    kind: .creditCard,
                    status: status,
                    monthlyPayment: nil,
                    installmentCount: nil,
                    paymentsMade: 0,
                    firstPaymentDate: nil,
                    linkedRecurringPaymentId: nil,
                    managementFee: normalizedNonNegativeAmount(debt.managementFee),
                    minimumPaymentRate: min(max(debt.minimumPaymentRate.isFinite ? debt.minimumPaymentRate : 0.05, 0), 1),
                    minimumPaymentFixedAmount: normalizedOptionalNonNegativeAmount(debt.minimumPaymentFixedAmount),
                    statementClosingDay: normalizedDay(debt.statementClosingDay),
                    minimumPaymentDueDay: normalizedDay(debt.minimumPaymentDueDay)
                )
            }

            if didDebtChange(from: debt, to: cleanedDebt) {
                report.repairedDebts += 1
            }

            return cleanedDebt
        }
    }

    private func repairRecurringPayments(
        _ payments: [RecurringPayment],
        report: inout FinancialStateIntegrityRepairReport
    ) -> [RecurringPayment] {
        var seenIds = Set<UUID>()

        return payments.compactMap { payment in
            guard !seenIds.contains(payment.id) else {
                report.repairedRecurringPayments += 1
                return nil
            }

            seenIds.insert(payment.id)

            let cleanedTitle = payment.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = cleanedTitle.isEmpty ? "Pago fijo sin nombre" : cleanedTitle
            let amount = max(normalizedNonNegativeAmount(payment.amount), 0.01)
            let dueDay = min(max(payment.dueDay, 1), 31)

            let repairedPayment = RecurringPayment(
                id: payment.id,
                title: title,
                amount: amount,
                dueDay: dueDay,
                category: payment.category,
                customCategoryName: payment.customCategoryName,
                isActive: payment.isActive,
                lastPaidMonth: normalizedMonth(payment.lastPaidMonth),
                lastPaidYear: normalizedYear(payment.lastPaidYear),
                lastPaidExpenseId: payment.lastPaidExpenseId,
                linkedDebtId: payment.linkedDebtId
            )

            if didRecurringPaymentChange(from: payment, to: repairedPayment) {
                report.repairedRecurringPayments += 1
            }

            return repairedPayment
        }
    }

    private func repairDebtRecurringLinks(
        debts: inout [Debt],
        recurringPayments: inout [RecurringPayment],
        report: inout FinancialStateIntegrityRepairReport
    ) {
        let debtsById = makeDebtMap(debts)

        for index in recurringPayments.indices {
            guard let linkedDebtId = recurringPayments[index].linkedDebtId else {
                continue
            }

            guard let linkedDebt = debtsById[linkedDebtId],
                  linkedDebt.isLoan else {
                recurringPayments[index].linkedDebtId = nil
                report.repairedRecurringPayments += 1
                continue
            }

            if linkedDebt.isPaid, recurringPayments[index].isActive {
                recurringPayments[index].isActive = false
                report.repairedRecurringPayments += 1
            }
        }

        let paymentsById = makeRecurringPaymentMap(recurringPayments)

        for index in debts.indices {
            if debts[index].isCreditCard {
                if debts[index].linkedRecurringPaymentId != nil {
                    debts[index].linkedRecurringPaymentId = nil
                    report.repairedDebts += 1
                }

                continue
            }

            guard debts[index].isLoan else { continue }

            if let linkedPaymentId = debts[index].linkedRecurringPaymentId {
                let existingPayment = paymentsById[linkedPaymentId]

                if existingPayment?.linkedDebtId == debts[index].id {
                    continue
                }
            }

            if let reverseLinkedPayment = recurringPayments.first(where: { $0.linkedDebtId == debts[index].id }) {
                debts[index].linkedRecurringPaymentId = reverseLinkedPayment.id
                report.repairedDebts += 1
            } else if debts[index].linkedRecurringPaymentId != nil {
                debts[index].linkedRecurringPaymentId = nil
                report.repairedDebts += 1
            }
        }
    }

    private func repairExpenses(
        _ expenses: [Expense],
        validAccountIds: Set<UUID>,
        validDebtIds: Set<UUID>,
        report: inout FinancialStateIntegrityRepairReport
    ) -> [Expense] {
        var seenIds = Set<UUID>()

        return expenses.compactMap { expense in
            guard !seenIds.contains(expense.id) else {
                report.repairedExpenses += 1
                return nil
            }

            seenIds.insert(expense.id)

            let cleanedTitle = expense.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = cleanedTitle.isEmpty ? "Gasto sin nombre" : cleanedTitle
            let amount = normalizedNonNegativeAmount(expense.amount)

            guard amount > 0 else {
                report.repairedExpenses += 1
                return nil
            }

            let validCreditCardId = expense.creditCardId.flatMap {
                validDebtIds.contains($0) ? $0 : nil
            }

            let validMoneyAccountId = expense.moneyAccountId.flatMap {
                validAccountIds.contains($0) ? $0 : nil
            }

            let resolvedMoneyAccountId = validCreditCardId == nil ? validMoneyAccountId : nil

            let repairedExpense = Expense(
                id: expense.id,
                title: title,
                amount: amount,
                date: expense.date,
                category: expense.category,
                customCategoryName: expense.customCategoryName,
                moneyAccountId: resolvedMoneyAccountId,
                creditCardId: validCreditCardId,
                comment: expense.comment
            )

            if didExpenseChange(from: expense, to: repairedExpense) {
                report.repairedExpenses += 1
            }

            return repairedExpense
        }
    }

    private func repairRecurringPaymentPaidState(
        _ payments: [RecurringPayment],
        validExpenseIds: Set<UUID>,
        report: inout FinancialStateIntegrityRepairReport
    ) -> [RecurringPayment] {
        payments.map { payment in
            let hasValidPaidExpense = payment.lastPaidExpenseId.map {
                validExpenseIds.contains($0)
            } ?? false

            let hasPaidMonth = payment.lastPaidMonth != nil
            let hasPaidYear = payment.lastPaidYear != nil

            guard hasPaidMonth || hasPaidYear || payment.lastPaidExpenseId != nil else {
                return payment
            }

            guard hasValidPaidExpense, hasPaidMonth, hasPaidYear else {
                report.repairedRecurringPayments += 1

                return RecurringPayment(
                    id: payment.id,
                    title: payment.title,
                    amount: payment.amount,
                    dueDay: payment.dueDay,
                    category: payment.category,
                    customCategoryName: payment.customCategoryName,
                    isActive: payment.isActive,
                    lastPaidMonth: nil,
                    lastPaidYear: nil,
                    lastPaidExpenseId: nil,
                    linkedDebtId: payment.linkedDebtId
                )
            }

            return payment
        }
    }

    private func normalizedNonNegativeAmount(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }

        if abs(value) <= tolerance {
            return 0
        }

        return max(value, 0)
    }

    private func normalizedOptionalNonNegativeAmount(_ value: Double?) -> Double? {
        guard let value else {
            return nil
        }

        return normalizedNonNegativeAmount(value)
    }

    private func normalizedOptionalPositiveAmount(_ value: Double?) -> Double? {
        guard let value else {
            return nil
        }

        let cleaned = normalizedNonNegativeAmount(value)
        return cleaned > tolerance ? cleaned : nil
    }

    private func normalizedInstallmentCount(_ value: Int?) -> Int? {
        guard let value else {
            return nil
        }

        return max(value, 0)
    }

    private func normalizedPaymentsMade(_ value: Int, installmentCount: Int?) -> Int {
        let cleaned = max(value, 0)

        guard let installmentCount else {
            return cleaned
        }

        return min(cleaned, installmentCount)
    }

    private func normalizedDay(_ value: Int?) -> Int? {
        guard let value else {
            return nil
        }

        return min(max(value, 1), 31)
    }

    private func normalizedMonth(_ value: Int?) -> Int? {
        guard let value else {
            return nil
        }

        return (1...12).contains(value) ? value : nil
    }

    private func normalizedYear(_ value: Int?) -> Int? {
        guard let value else {
            return nil
        }

        return (1900...3000).contains(value) ? value : nil
    }

    private func makeDebtMap(_ debts: [Debt]) -> [UUID: Debt] {
        var map: [UUID: Debt] = [:]

        for debt in debts where map[debt.id] == nil {
            map[debt.id] = debt
        }

        return map
    }

    private func makeRecurringPaymentMap(_ payments: [RecurringPayment]) -> [UUID: RecurringPayment] {
        var map: [UUID: RecurringPayment] = [:]

        for payment in payments where map[payment.id] == nil {
            map[payment.id] = payment
        }

        return map
    }

    private func didDebtChange(from oldDebt: Debt, to newDebt: Debt) -> Bool {
        oldDebt.cardName != newDebt.cardName
        || oldDebt.brand != newDebt.brand
        || oldDebt.totalLimit != newDebt.totalLimit
        || oldDebt.remainingDebt != newDebt.remainingDebt
        || oldDebt.kind != newDebt.kind
        || oldDebt.status != newDebt.status
        || oldDebt.monthlyPayment != newDebt.monthlyPayment
        || oldDebt.installmentCount != newDebt.installmentCount
        || oldDebt.paymentsMade != newDebt.paymentsMade
        || oldDebt.firstPaymentDate != newDebt.firstPaymentDate
        || oldDebt.linkedRecurringPaymentId != newDebt.linkedRecurringPaymentId
        || oldDebt.managementFee != newDebt.managementFee
        || oldDebt.minimumPaymentRate != newDebt.minimumPaymentRate
        || oldDebt.minimumPaymentFixedAmount != newDebt.minimumPaymentFixedAmount
        || oldDebt.statementClosingDay != newDebt.statementClosingDay
        || oldDebt.minimumPaymentDueDay != newDebt.minimumPaymentDueDay
    }

    private func didRecurringPaymentChange(
        from oldPayment: RecurringPayment,
        to newPayment: RecurringPayment
    ) -> Bool {
        oldPayment.title != newPayment.title
        || oldPayment.amount != newPayment.amount
        || oldPayment.dueDay != newPayment.dueDay
        || oldPayment.category != newPayment.category
        || oldPayment.customCategoryName != newPayment.customCategoryName
        || oldPayment.isActive != newPayment.isActive
        || oldPayment.lastPaidMonth != newPayment.lastPaidMonth
        || oldPayment.lastPaidYear != newPayment.lastPaidYear
        || oldPayment.lastPaidExpenseId != newPayment.lastPaidExpenseId
        || oldPayment.linkedDebtId != newPayment.linkedDebtId
    }

    private func didExpenseChange(from oldExpense: Expense, to newExpense: Expense) -> Bool {
        oldExpense.title != newExpense.title
        || oldExpense.amount != newExpense.amount
        || oldExpense.date != newExpense.date
        || oldExpense.category != newExpense.category
        || oldExpense.customCategoryName != newExpense.customCategoryName
        || oldExpense.moneyAccountId != newExpense.moneyAccountId
        || oldExpense.creditCardId != newExpense.creditCardId
        || oldExpense.comment != newExpense.comment
    }
}

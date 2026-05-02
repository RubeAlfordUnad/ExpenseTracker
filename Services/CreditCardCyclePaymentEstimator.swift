import Foundation

struct CreditCardCyclePaymentEstimate {
    let cardId: UUID
    let cardName: String
    let cycleStart: Date
    let cycleEnd: Date
    let dueDate: Date?
    let cycleExpenses: [Expense]
    let cycleExpensesTotal: Double
    let balanceBasis: Double
    let principalMinimumPayment: Double
    let managementFee: Double
    let estimatedTotalDue: Double
    let daysUntilDue: Int?
    let isDueToday: Bool
    let isOverdue: Bool
}

struct CreditCardCyclePaymentEstimator {

    private var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func estimate(
        for debt: Debt,
        expenses: [Expense],
        referenceDate: Date = Date()
    ) -> CreditCardCyclePaymentEstimate? {
        guard debt.isCreditCard else {
            return nil
        }

        let closingDay = normalizedDay(debt.statementClosingDay)
        let cycle = cycleDates(
            closingDay: closingDay,
            dueDay: debt.minimumPaymentDueDay,
            referenceDate: referenceDate
        )

        let cycleStart = cycle.start
        let cycleEnd = cycle.end
        let cycleEndExclusive = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: cycleEnd)
        ) ?? cycleEnd

        let cycleExpenses = expenses.filter { expense in
            guard expense.creditCardId == debt.id else {
                return false
            }

            return expense.date >= cycleStart && expense.date < cycleEndExclusive
        }

        let cycleExpensesTotal = cycleExpenses.reduce(0) { partial, expense in
            partial + max(expense.amount, 0)
        }

        let balanceBasis = max(debt.remainingDebt, cycleExpensesTotal)
        let fixedMinimum = max(debt.minimumPaymentFixedAmount ?? 0, 0)
        let percentageMinimum = max(balanceBasis * debt.minimumPaymentRate, 0)

        let principalMinimumPayment: Double
        if debt.remainingDebt > 0 {
            principalMinimumPayment = min(
                max(percentageMinimum, fixedMinimum),
                debt.remainingDebt
            )
        } else {
            principalMinimumPayment = 0
        }

        let managementFee = max(debt.managementFee, 0)
        let estimatedTotalDue = max(principalMinimumPayment + managementFee, 0)

        let daysUntilDue: Int?
        if let dueDate = cycle.dueDate {
            daysUntilDue = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: referenceDate),
                to: calendar.startOfDay(for: dueDate)
            ).day
        } else {
            daysUntilDue = nil
        }

        return CreditCardCyclePaymentEstimate(
            cardId: debt.id,
            cardName: debt.cardName,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            dueDate: cycle.dueDate,
            cycleExpenses: cycleExpenses,
            cycleExpensesTotal: cycleExpensesTotal,
            balanceBasis: balanceBasis,
            principalMinimumPayment: principalMinimumPayment,
            managementFee: managementFee,
            estimatedTotalDue: estimatedTotalDue,
            daysUntilDue: daysUntilDue,
            isDueToday: daysUntilDue == 0,
            isOverdue: (daysUntilDue ?? 0) < 0
        )
    }

    private func cycleDates(
        closingDay: Int,
        dueDay: Int?,
        referenceDate: Date
    ) -> (start: Date, end: Date, dueDate: Date?) {
        let closingThisMonth = date(
            day: closingDay,
            inMonthOf: referenceDate
        )

        let dueForClosingThisMonth = dueDay.flatMap {
            dueDate(
                forClosingDate: closingThisMonth,
                closingDay: closingDay,
                dueDay: normalizedDay($0)
            )
        }

        let shouldUseCurrentClosing: Bool
        if let dueForClosingThisMonth {
            shouldUseCurrentClosing = calendar.startOfDay(for: referenceDate) <= calendar.startOfDay(for: dueForClosingThisMonth)
        } else {
            shouldUseCurrentClosing = calendar.startOfDay(for: referenceDate) <= calendar.startOfDay(for: closingThisMonth)
        }

        let selectedClosingDate: Date

        if shouldUseCurrentClosing {
            selectedClosingDate = closingThisMonth
        } else {
            let nextMonth = calendar.date(
                byAdding: .month,
                value: 1,
                to: referenceDate
            ) ?? referenceDate

            selectedClosingDate = date(
                day: closingDay,
                inMonthOf: nextMonth
            )
        }

        let previousClosingMonth = calendar.date(
            byAdding: .month,
            value: -1,
            to: selectedClosingDate
        ) ?? selectedClosingDate

        let previousClosingDate = date(
            day: closingDay,
            inMonthOf: previousClosingMonth
        )

        let cycleStart = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: previousClosingDate)
        ) ?? calendar.startOfDay(for: previousClosingDate)

        let cycleEnd = calendar.startOfDay(for: selectedClosingDate)

        let selectedDueDate = dueDay.flatMap {
            dueDate(
                forClosingDate: selectedClosingDate,
                closingDay: closingDay,
                dueDay: normalizedDay($0)
            )
        }

        return (
            start: cycleStart,
            end: cycleEnd,
            dueDate: selectedDueDate
        )
    }

    private func dueDate(
        forClosingDate closingDate: Date,
        closingDay: Int,
        dueDay: Int
    ) -> Date {
        if dueDay <= closingDay {
            let nextMonth = calendar.date(
                byAdding: .month,
                value: 1,
                to: closingDate
            ) ?? closingDate

            return date(
                day: dueDay,
                inMonthOf: nextMonth
            )
        }

        return date(
            day: dueDay,
            inMonthOf: closingDate
        )
    }

    private func date(day: Int, inMonthOf referenceDate: Date) -> Date {
        var components = calendar.dateComponents([.year, .month], from: referenceDate)
        components.day = safeDay(day, inMonthOf: referenceDate)
        components.hour = 0
        components.minute = 0
        components.second = 0

        return calendar.date(from: components) ?? calendar.startOfDay(for: referenceDate)
    }

    private func normalizedDay(_ day: Int?) -> Int {
        safeDay(day ?? 1, inMonthOf: Date())
    }

    private func safeDay(_ day: Int, inMonthOf date: Date) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return min(max(day, 1), 28)
        }

        return min(max(day, 1), range.count)
    }
}

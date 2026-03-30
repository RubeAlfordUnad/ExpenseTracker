import Foundation

struct RecurringPayment: Identifiable, Codable {

    var id = UUID()
    var title: String
    var amount: Double
    var dueDay: Int
    var category: RecurringPaymentCategory
    var isActive: Bool

    var lastPaidMonth: Int?
    var lastPaidYear: Int?

    var isPaidForCurrentMonth: Bool {
        guard let month = lastPaidMonth,
              let year = lastPaidYear else { return false }

        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        return month == currentMonth && year == currentYear
    }

    func effectiveDueDay(inMonthOf date: Date, calendar: Calendar = .current) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return dueDay
        }

        return min(dueDay, range.count)
    }

    func dueDate(
        inMonthOf date: Date,
        hour: Int = 9,
        minute: Int = 0,
        calendar: Calendar = .current
    ) -> Date? {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let safeDay = effectiveDueDay(inMonthOf: date, calendar: calendar)

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = safeDay
        components.hour = hour
        components.minute = minute

        return calendar.date(from: components)
    }

    func displayDueText(language: AppLanguage, referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        let effectiveDay = effectiveDueDay(inMonthOf: referenceDate, calendar: calendar)

        if effectiveDay == dueDay {
            switch language {
            case .spanish:
                return "Día \(dueDay)"
            case .english:
                return "Day \(dueDay)"
            }
        } else {
            switch language {
            case .spanish:
                return "Día \(dueDay) · este mes \(effectiveDay)"
            case .english:
                return "Day \(dueDay) · this month \(effectiveDay)"
            }
        }
    }
}

import SwiftUI

private enum DebtCalendarEventKind: String, CaseIterable {
    case statementClosing
    case minimumPayment
    case loanPayment

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.statementClosing, .spanish): return "Corte de tarjeta"
        case (.statementClosing, .english): return "Card closing"
        case (.minimumPayment, .spanish): return "Pago mínimo"
        case (.minimumPayment, .english): return "Minimum payment"
        case (.loanPayment, .spanish): return "Pago de préstamo"
        case (.loanPayment, .english): return "Loan payment"
        }
    }

    var color: Color {
        switch self {
        case .statementClosing:
            return .blue
        case .minimumPayment:
            return .red
        case .loanPayment:
            return .orange
        }
    }

    var icon: String {
        switch self {
        case .statementClosing:
            return "calendar.badge.clock"
        case .minimumPayment:
            return "creditcard.fill"
        case .loanPayment:
            return "doc.text.fill"
        }
    }

    var sortPriority: Int {
        switch self {
        case .statementClosing:
            return 0
        case .minimumPayment:
            return 1
        case .loanPayment:
            return 2
        }
    }
}

private struct DebtCalendarEvent: Identifiable {
    let id = UUID()
    let date: Date
    let kind: DebtCalendarEventKind
    let debt: Debt
    let amount: Double?
    let detail: String
}

struct DebtCalendarView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    let debts: [Debt]

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()

    private var calendar: Calendar {
        Calendar.current
    }

    private var activeDebts: [Debt] {
        debts.filter { $0.isActive }
    }

    private var monthStart: Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        ) ?? displayedMonth
    }

    private var monthTitle: String {
        monthStart.formatted(
            .dateTime
                .month(.wide)
                .year()
                .locale(settings.appLocale)
        )
        .capitalized
    }

    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        return Array(range)
    }

    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var monthEvents: [DebtCalendarEvent] {
        activeDebts.flatMap { events(for: $0, inMonthOf: monthStart) }
            .sorted {
                if calendar.compare($0.date, to: $1.date, toGranularity: .day) == .orderedSame {
                    return $0.kind.sortPriority < $1.kind.sortPriority
                }

                return $0.date < $1.date
            }
    }

    private var selectedDayEvents: [DebtCalendarEvent] {
        monthEvents.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    monthControls
                    legend
                    calendarGrid
                    selectedDayDetails
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(settings.language == .spanish ? "Calendario de deudas" : "Debt calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.language == .spanish ? "Hoy" : "Today") {
                        displayedMonth = Date()
                        selectedDate = Date()
                    }
                }
            }
            .onAppear {
                selectedDate = safeSelectedDate(for: Date(), inMonthOf: displayedMonth)
            }
            .onChange(of: displayedMonth) { _, newValue in
                selectedDate = safeSelectedDate(for: selectedDate, inMonthOf: newValue)
            }
        }
    }

    private var monthControls: some View {
        HStack(spacing: 12) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(BrandPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(monthTitle)
                    .font(.title3.bold())

                Text(monthSummaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(BrandPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.language == .spanish ? "Leyenda" : "Legend")
                .font(.headline)

            VStack(spacing: 8) {
                legendRow(kind: .statementClosing)
                legendRow(kind: .minimumPayment)
                legendRow(kind: .loanPayment)
            }
        }
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func legendRow(kind: DebtCalendarEventKind) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(kind.color)
                .frame(width: 10, height: 10)

            Image(systemName: kind.icon)
                .font(.caption)
                .foregroundColor(kind.color)
                .frame(width: 18)

            Text(kind.title(language: settings.language))
                .font(.subheadline)

            Spacer()
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 12) {
            weekdayHeader

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 52)
                }

                ForEach(daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(14)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let orderedSymbols = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])

        return HStack(spacing: 8) {
            ForEach(orderedSymbols, id: \.self) { symbol in
                Text(symbol.prefix(2).uppercased())
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let date = makeDate(day: day)
        let events = eventsForDay(day)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 6) {
                Text("\(day)")
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 3) {
                    ForEach(events.prefix(3)) { event in
                        Circle()
                            .fill(event.kind.color)
                            .frame(width: 6, height: 6)
                    }

                    if events.count > 3 {
                        Text("+")
                            .font(.caption2.bold())
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                }
                .frame(height: 8)
            }
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? BrandPalette.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isToday ? BrandPalette.primary : Color.clear, lineWidth: 1.4)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedDayDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDateTitle)
                .font(.headline)

            if selectedDayEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text(settings.language == .spanish ? "No hay eventos para este día." : "No events for this day.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(BrandPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedDayEvents) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: DebtCalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.icon)
                .font(.headline)
                .foregroundColor(event.kind.color)
                .frame(width: 38, height: 38)
                .background(event.kind.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(event.kind.title(language: settings.language))
                    .font(.subheadline.bold())

                Text(event.debt.cardName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(event.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let amount = event.amount {
                    Text(settings.secureCurrency(amount, decimals: 2))
                        .font(.caption.bold())
                        .foregroundColor(event.kind.color)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(event.kind.color.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var monthSummaryText: String {
        let closingCount = monthEvents.filter { $0.kind == .statementClosing }.count
        let minimumCount = monthEvents.filter { $0.kind == .minimumPayment }.count
        let loanCount = monthEvents.filter { $0.kind == .loanPayment }.count

        if settings.language == .spanish {
            return "\(closingCount) cortes · \(minimumCount) pagos mínimos · \(loanCount) préstamos"
        }

        return "\(closingCount) closings · \(minimumCount) minimum payments · \(loanCount) loans"
    }

    private var selectedDateTitle: String {
        selectedDate.formatted(
            .dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(settings.appLocale)
        )
        .capitalized
    }

    private func eventsForDay(_ day: Int) -> [DebtCalendarEvent] {
        monthEvents.filter {
            calendar.component(.day, from: $0.date) == day
        }
    }

    private func events(for debt: Debt, inMonthOf date: Date) -> [DebtCalendarEvent] {
        var result: [DebtCalendarEvent] = []

        if debt.isCreditCard {
            if let closingDay = debt.statementClosingDay {
                result.append(
                    DebtCalendarEvent(
                        date: makeDate(day: safeDay(closingDay, inMonthOf: date)),
                        kind: .statementClosing,
                        debt: debt,
                        amount: nil,
                        detail: settings.language == .spanish
                        ? "Día de corte del ciclo de la tarjeta."
                        : "Card statement cycle closing day."
                    )
                )
            }

            if let dueDay = debt.minimumPaymentDueDay {
                result.append(
                    DebtCalendarEvent(
                        date: makeDate(day: safeDay(dueDay, inMonthOf: date)),
                        kind: .minimumPayment,
                        debt: debt,
                        amount: debt.estimatedMonthlyCardPayment,
                        detail: settings.language == .spanish
                        ? "Pago estimado con cuota de manejo incluida."
                        : "Estimated payment including management fee."
                    )
                )
            }
        }

        if debt.isLoan,
           let firstPaymentDate = debt.firstPaymentDate,
           let monthlyPayment = debt.monthlyPayment {
            let day = calendar.component(.day, from: firstPaymentDate)

            result.append(
                DebtCalendarEvent(
                    date: makeDate(day: safeDay(day, inMonthOf: date)),
                    kind: .loanPayment,
                    debt: debt,
                    amount: monthlyPayment,
                    detail: loanEventDetail(for: debt)
                )
            )
        }

        return result
    }

    private func loanEventDetail(for debt: Debt) -> String {
        guard let installmentCount = debt.installmentCount else {
            return settings.language == .spanish
            ? "Pago mensual del préstamo."
            : "Monthly loan payment."
        }

        let remaining = debt.remainingInstallments ?? 0

        if settings.language == .spanish {
            return "\(debt.paymentsMade)/\(installmentCount) cuotas pagadas · faltan \(remaining)."
        }

        return "\(debt.paymentsMade)/\(installmentCount) installments paid · \(remaining) left."
    }

    private func makeDate(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = day
        return calendar.date(from: components) ?? monthStart
    }

    private func safeDay(_ day: Int, inMonthOf date: Date) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return min(max(day, 1), 28)
        }

        return min(max(day, 1), range.count)
    }

    private func safeSelectedDate(for date: Date, inMonthOf month: Date) -> Date {
        let selectedDay = calendar.component(.day, from: date)
        return makeDate(day: safeDay(selectedDay, inMonthOf: month))
    }

    private func changeMonth(by value: Int) {
        displayedMonth = calendar.date(
            byAdding: .month,
            value: value,
            to: displayedMonth
        ) ?? displayedMonth
    }
}

import SwiftUI

private enum DebtCalendarFilter: String, CaseIterable, Identifiable {
    case all
    case cards
    case loans

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.all, .spanish): return "Todas"
        case (.all, .english): return "All"
        case (.cards, .spanish): return "Tarjetas"
        case (.cards, .english): return "Cards"
        case (.loans, .spanish): return "Préstamos"
        case (.loans, .english): return "Loans"
        }
    }

    var icon: String {
        switch self {
        case .all: return "calendar"
        case .cards: return "creditcard"
        case .loans: return "doc.text"
        }
    }
}

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
        case .statementClosing: return .blue
        case .minimumPayment: return .red
        case .loanPayment: return .orange
        }
    }

    var icon: String {
        switch self {
        case .statementClosing: return "calendar.badge.clock"
        case .minimumPayment: return "creditcard.fill"
        case .loanPayment: return "doc.text.fill"
        }
    }

    var sortPriority: Int {
        switch self {
        case .statementClosing: return 0
        case .minimumPayment: return 1
        case .loanPayment: return 2
        }
    }

    var shouldCountAsPayment: Bool {
        switch self {
        case .statementClosing:
            return false
        case .minimumPayment, .loanPayment:
            return true
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
    let expenses: [Expense]

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var selectedFilter: DebtCalendarFilter = .all

    private let creditCardCycleEstimator = CreditCardCyclePaymentEstimator()

    private var calendar: Calendar {
        Calendar.current
    }

    private var activeDebts: [Debt] {
        debts.filter { $0.isActive }
    }

    private var filteredDebts: [Debt] {
        switch selectedFilter {
        case .all:
            return activeDebts
        case .cards:
            return activeDebts.filter { $0.isCreditCard }
        case .loans:
            return activeDebts.filter { $0.isLoan }
        }
    }

    private var monthStart: Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        ) ?? displayedMonth
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
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
        filteredDebts.flatMap { events(for: $0, inMonthOf: monthStart) }
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

    private var monthlyEstimatedPaymentTotal: Double {
        monthEvents.reduce(0) { partial, event in
            guard event.kind.shouldCountAsPayment else {
                return partial
            }

            return partial + max(event.amount ?? 0, 0)
        }
    }

    private var statementClosingCount: Int {
        monthEvents.filter { $0.kind == .statementClosing }.count
    }

    private var minimumPaymentCount: Int {
        monthEvents.filter { $0.kind == .minimumPayment }.count
    }

    private var loanPaymentCount: Int {
        monthEvents.filter { $0.kind == .loanPayment }.count
    }

    private var overduePaymentCount: Int {
        monthEvents.filter { event in
            event.kind.shouldCountAsPayment
            && calendar.startOfDay(for: event.date) < today
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    monthControls
                    summaryCard
                    filterBar
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.headline)
                    .foregroundColor(BrandPalette.primary)
                    .frame(width: 38, height: 38)
                    .background(BrandPalette.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.language == .spanish ? "Resumen del mes" : "Monthly summary")
                        .font(.headline)

                    Text(settings.language == .spanish ? "Pagos estimados y eventos activos" : "Estimated payments and active events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                summaryAmountBlock(
                    title: settings.language == .spanish ? "A pagar aprox." : "Estimated due",
                    value: money(monthlyEstimatedPaymentTotal),
                    tint: BrandPalette.primary
                )

                summaryAmountBlock(
                    title: settings.language == .spanish ? "Vencidos" : "Overdue",
                    value: "\(overduePaymentCount)",
                    tint: overduePaymentCount > 0 ? .red : BrandPalette.secondary
                )
            }

            HStack(spacing: 8) {
                eventCountPill(
                    title: settings.language == .spanish ? "Cortes" : "Closings",
                    count: statementClosingCount,
                    color: .blue
                )

                eventCountPill(
                    title: settings.language == .spanish ? "Mínimos" : "Minimums",
                    count: minimumPaymentCount,
                    color: .red
                )

                eventCountPill(
                    title: settings.language == .spanish ? "Préstamos" : "Loans",
                    count: loanPaymentCount,
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func summaryAmountBlock(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func eventCountPill(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text("\(title): \(count)")
                .font(.caption.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(DebtCalendarFilter.allCases) { filter in
                Button {
                    withAnimation(.spring()) {
                        selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: filter.icon)
                            .font(.caption.bold())

                        Text(filter.title(language: settings.language))
                            .font(.caption.bold())
                    }
                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedFilter == filter ? BrandPalette.primary : BrandPalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(BrandPalette.stroke, lineWidth: selectedFilter == filter ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
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
                        .frame(height: 54)
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
        let startIndex = calendar.firstWeekday - 1
        let orderedSymbols = Array(symbols[startIndex..<symbols.count]) + Array(symbols[0..<startIndex])

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
        let hasOverduePayment = events.contains { event in
            event.kind.shouldCountAsPayment
            && calendar.startOfDay(for: event.date) < today
        }

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
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? BrandPalette.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        hasOverduePayment ? Color.red : (isToday ? BrandPalette.primary : Color.clear),
                        lineWidth: hasOverduePayment || isToday ? 1.4 : 0
                    )
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(event.kind.title(language: settings.language))
                        .font(.subheadline.bold())

                    eventStatusPill(for: event)
                }

                Text(event.debt.cardName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(event.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let amount = event.amount {
                    Text(money(amount))
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

    @ViewBuilder
    private func eventStatusPill(for event: DebtCalendarEvent) -> some View {
        if event.kind.shouldCountAsPayment {
            let eventDay = calendar.startOfDay(for: event.date)

            if eventDay < today {
                statusPill(
                    text: settings.language == .spanish ? "Vencido" : "Overdue",
                    color: .red
                )
            } else if eventDay == today {
                statusPill(
                    text: settings.language == .spanish ? "Hoy" : "Today",
                    color: .orange
                )
            } else {
                statusPill(
                    text: settings.language == .spanish ? "Próximo" : "Upcoming",
                    color: BrandPalette.primary
                )
            }
        }
    }

    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.vertical, 4)
            .padding(.horizontal, 7)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var monthSummaryText: String {
        if settings.language == .spanish {
            return "\(statementClosingCount) cortes · \(minimumPaymentCount) pagos mínimos · \(loanPaymentCount) préstamos"
        }

        return "\(statementClosingCount) closings · \(minimumPaymentCount) minimum payments · \(loanPaymentCount) loans"
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
                let dueDate = makeDate(day: safeDay(dueDay, inMonthOf: date))
                let estimate = creditCardCycleEstimator.estimate(
                    for: debt,
                    expenses: expenses,
                    referenceDate: dueDate
                )

                result.append(
                    DebtCalendarEvent(
                        date: dueDate,
                        kind: .minimumPayment,
                        debt: debt,
                        amount: estimate?.estimatedTotalDue ?? debt.estimatedMonthlyCardPayment,
                        detail: minimumPaymentDetail(for: debt, estimate: estimate)
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

    private func minimumPaymentDetail(
        for debt: Debt,
        estimate: CreditCardCyclePaymentEstimate?
    ) -> String {
        guard let estimate else {
            return settings.language == .spanish
            ? "Pago estimado con cuota de manejo incluida."
            : "Estimated payment including management fee."
        }

        let cycleAmount = money(estimate.cycleExpensesTotal)
        let principalMinimum = money(estimate.principalMinimumPayment)
        let managementFee = money(estimate.managementFee)

        if settings.language == .spanish {
            return "Ciclo: \(cycleAmount) · mínimo: \(principalMinimum) · manejo: \(managementFee)."
        }

        return "Cycle: \(cycleAmount) · minimum: \(principalMinimum) · fee: \(managementFee)."
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

    private func money(_ amount: Double) -> String {
        settings.secureCurrency(amount, decimals: 2)
    }
}

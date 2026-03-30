import SwiftUI
import UniformTypeIdentifiers

struct ExpenseHistoryView: View {

    @EnvironmentObject var settings: AppSettings

    @Binding var expenses: [Expense]
    let onPersist: () -> Void

    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    @State private var selectedTab: HistoryTab = .overview
    @State private var selectedLedgerYear: Int = 0
    @State private var selectedLedgerMonth: Int = 0
    @State private var searchText = ""

    @State private var editingExpense: Expense?
    @State private var expensePendingDelete: Expense?

    @State private var exportDocument = ExportFileDocument()
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "expenses.json"
    @State private var showExporter = false
    @State private var showImporter = false

    @State private var successMessage: String?
    @State private var errorMessage: String?

    private let calendar = Calendar.current
    private let transferService = ExpensesTransferService()

    private enum HistoryTab: String, CaseIterable, Identifiable {
        case overview
        case ledger

        var id: String { rawValue }
    }

    private struct LedgerSection: Identifiable {
        let monthStart: Date
        let expenses: [Expense]

        var id: Date { monthStart }
    }

    private var availableYears: [Int] {
        let years = Set(expenses.map { calendar.component(.year, from: $0.date) })
        let sorted = years.sorted(by: >)
        return sorted.isEmpty ? [calendar.component(.year, from: Date())] : sorted
    }

    private var selectedMonthExpenses: [Expense] {
        expenses
            .filter {
                calendar.component(.year, from: $0.date) == selectedYear &&
                calendar.component(.month, from: $0.date) == selectedMonth
            }
            .sorted { $0.date > $1.date }
    }

    private var selectedYearExpenses: [Expense] {
        expenses
            .filter { calendar.component(.year, from: $0.date) == selectedYear }
            .sorted { $0.date > $1.date }
    }

    private var selectedMonthTotal: Double {
        selectedMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var selectedYearTotal: Double {
        selectedYearExpenses.reduce(0) { $0 + $1.amount }
    }

    private var selectedMonthAverage: Double {
        guard !selectedMonthExpenses.isEmpty else { return 0 }
        return selectedMonthTotal / Double(selectedMonthExpenses.count)
    }

    private var activeMonthsInYearCount: Int {
        yearPoints.filter { $0.total > 0 }.count
    }

    private var previousMonthTotal: Double {
        guard let previousDate = calendar.date(byAdding: .month, value: -1, to: selectedMonthReferenceDate) else {
            return 0
        }

        let previousYear = calendar.component(.year, from: previousDate)
        let previousMonth = calendar.component(.month, from: previousDate)

        return expenses
            .filter {
                calendar.component(.year, from: $0.date) == previousYear &&
                calendar.component(.month, from: $0.date) == previousMonth
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var dominantCategory: Category? {
        let grouped = Dictionary(grouping: selectedMonthExpenses, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        return grouped.max(by: { $0.value < $1.value })?.key
    }

    private var yearPoints: [HistoryYearPoint] {
        (1...12).map { month in
            let total = expenses
                .filter {
                    calendar.component(.year, from: $0.date) == selectedYear &&
                    calendar.component(.month, from: $0.date) == month
                }
                .reduce(0) { $0 + $1.amount }

            return HistoryYearPoint(
                id: month,
                month: month,
                label: monthShortLabel(month),
                total: total
            )
        }
    }

    private var monthStripData: [HistoryMonthData] {
        yearPoints.map {
            HistoryMonthData(
                id: $0.month,
                month: $0.month,
                label: $0.label,
                total: $0.total,
                hasExpenses: $0.total > 0
            )
        }
    }

    private var selectedMonthReferenceDate: Date {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        return calendar.date(from: components) ?? Date()
    }

    private var monthVsPreviousText: String {
        if previousMonthTotal == 0, selectedMonthTotal > 0 {
            return settings.language == .spanish
            ? "Nuevo movimiento frente al mes anterior"
            : "Fresh activity compared to previous month"
        }

        if previousMonthTotal == 0 {
            return settings.language == .spanish
            ? "Sin comparación disponible"
            : "No comparison available"
        }

        let delta = selectedMonthTotal - previousMonthTotal
        let percentage = abs(delta / previousMonthTotal) * 100

        if delta > 0 {
            return settings.language == .spanish
            ? "\(Int(percentage))% más que el mes anterior"
            : "\(Int(percentage))% more than previous month"
        } else if delta < 0 {
            return settings.language == .spanish
            ? "\(Int(percentage))% menos que el mes anterior"
            : "\(Int(percentage))% less than previous month"
        } else {
            return settings.language == .spanish
            ? "Igual que el mes anterior"
            : "Same as previous month"
        }
    }

    private var monthVsPreviousColor: Color {
        if previousMonthTotal == 0, selectedMonthTotal > 0 { return .blue }
        if selectedMonthTotal > previousMonthTotal { return .red }
        if selectedMonthTotal < previousMonthTotal { return .green }
        return .secondary
    }

    private var comparisonHeadline: String {
        if selectedMonthExpenses.isEmpty {
            return settings.language == .spanish
            ? "Este mes está vacío"
            : "This month is empty"
        }

        if previousMonthTotal == 0, selectedMonthTotal > 0 {
            return settings.language == .spanish
            ? "Mes con actividad nueva"
            : "Month with new activity"
        }

        if selectedMonthTotal > previousMonthTotal {
            return settings.language == .spanish
            ? "Mes más pesado"
            : "Heavier month"
        } else if selectedMonthTotal < previousMonthTotal {
            return settings.language == .spanish
            ? "Mes más controlado"
            : "More controlled month"
        } else {
            return settings.language == .spanish
            ? "Mes estable"
            : "Stable month"
        }
    }

    private var filteredLedgerExpenses: [Expense] {
        let filteredByYearAndMonth = expenses.filter { expense in
            let yearMatches = selectedLedgerYear == 0 || calendar.component(.year, from: expense.date) == selectedLedgerYear
            let monthMatches = selectedLedgerMonth == 0 || calendar.component(.month, from: expense.date) == selectedLedgerMonth
            return yearMatches && monthMatches
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let searched = filteredByYearAndMonth.filter { expense in
            guard !trimmedSearch.isEmpty else { return true }

            let categoryName = expense.category.displayName(language: settings.language)
            return expense.title.localizedCaseInsensitiveContains(trimmedSearch)
            || categoryName.localizedCaseInsensitiveContains(trimmedSearch)
            || settings.shortDateString(from: expense.date).localizedCaseInsensitiveContains(trimmedSearch)
        }

        return searched.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var ledgerSections: [LedgerSection] {
        let grouped = Dictionary(grouping: filteredLedgerExpenses) { expense in
            startOfMonth(for: expense.date)
        }

        return grouped
            .map { LedgerSection(monthStart: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.monthStart > $1.monthStart }
    }

    private var filteredLedgerTotal: Double {
        filteredLedgerExpenses.reduce(0) { $0 + $1.amount }
    }

    private var oldestFilteredExpenseDate: Date? {
        filteredLedgerExpenses.last?.date
    }

    private var newestFilteredExpenseDate: Date? {
        filteredLedgerExpenses.first?.date
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    tabSelector

                    if selectedTab == .overview {
                        heroCard
                        yearSelectorCard
                        HistoryMonthStripView(
                            months: monthStripData,
                            selectedMonth: selectedMonth
                        ) { month in
                            selectedMonth = month
                        }

                        summaryGrid
                        comparisonCard
                        YearlyTrendChartCard(
                            points: yearPoints,
                            selectedMonth: selectedMonth,
                            annualTotal: selectedYearTotal
                        )

                        if let dominantCategory, !selectedMonthExpenses.isEmpty {
                            dominantCategoryCard(dominantCategory)
                        }

                        if selectedMonthExpenses.isEmpty {
                            emptyOverviewState
                        } else {
                            ExpensesChartView(expenses: selectedMonthExpenses)
                            transactionsSection
                        }
                    } else {
                        ledgerHeroCard
                        ledgerFiltersCard
                        ledgerSummaryGrid

                        if filteredLedgerExpenses.isEmpty {
                            emptyLedgerState
                        } else {
                            ledgerSectionsView
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle(settings.language == .spanish ? "Historial" : "History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showImporter = true
                        } label: {
                            Label(
                                settings.language == .spanish ? "Importar CSV o JSON" : "Import CSV or JSON",
                                systemImage: "square.and.arrow.down"
                            )
                        }

                        Divider()

                        Button {
                            prepareExport(.csv)
                        } label: {
                            Label(
                                settings.language == .spanish ? "Exportar CSV" : "Export CSV",
                                systemImage: "tablecells"
                            )
                        }

                        Button {
                            prepareExport(.json)
                        } label: {
                            Label(
                                settings.language == .spanish ? "Exportar JSON" : "Export JSON",
                                systemImage: "curlybraces"
                            )
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up.on.square")
                    }
                }
            }
            .onAppear {
                configureInitialSelection()
                normalizeLedgerFiltersIfNeeded()
            }
            .sheet(item: $editingExpense) { expense in
                AddExpenseView(existingExpense: expense) { updatedExpense in
                    updateExpense(updatedExpense)
                }
                .environmentObject(settings)
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .json]
            ) { result in
                handleImport(result)
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportFilename
            ) { result in
                if case let .failure(error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .alert(
                settings.language == .spanish ? "Eliminar gasto" : "Delete expense",
                isPresented: Binding(
                    get: { expensePendingDelete != nil },
                    set: { newValue in
                        if !newValue {
                            expensePendingDelete = nil
                        }
                    }
                )
            ) {
                Button(settings.t("common.cancel"), role: .cancel) {
                    expensePendingDelete = nil
                }

                Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                    if let expensePendingDelete {
                        deleteExpense(expensePendingDelete)
                    }
                    self.expensePendingDelete = nil
                }
            } message: {
                Text(
                    settings.language == .spanish
                    ? "Se borrará \"\(expensePendingDelete?.title ?? "")\" de forma permanente."
                    : "\"\(expensePendingDelete?.title ?? "")\" will be permanently removed."
                )
            }
            .alert(
                settings.language == .spanish ? "Importación / exportación" : "Import / export",
                isPresented: Binding(
                    get: { successMessage != nil || errorMessage != nil },
                    set: { newValue in
                        if !newValue {
                            successMessage = nil
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    successMessage = nil
                    errorMessage = nil
                }
            } message: {
                Text(successMessage ?? errorMessage ?? "")
            }
        }
    }

    private var tabSelector: some View {
        Picker("", selection: $selectedTab) {
            Text(settings.language == .spanish ? "Resumen" : "Overview").tag(HistoryTab.overview)
            Text(settings.language == .spanish ? "Registros" : "Ledger").tag(HistoryTab.ledger)
        }
        .pickerStyle(.segmented)
        .padding(6)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.language == .spanish ? "Historial mensual" : "Monthly history")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(
                        settings.language == .spanish
                        ? "Tu timeline financiero"
                        : "Your financial timeline"
                    )
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(
                        settings.language == .spanish
                        ? "Mira cómo se mueve tu dinero por mes, cuánto llevas en el año y qué cambió frente al mes anterior."
                        : "See how your money moves month by month, how much you have spent this year, and what changed versus the previous month."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(BrandPalette.primary)
                    .frame(width: 54, height: 54)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    infoPill(
                        icon: "calendar",
                        text: "\(monthFullLabel(selectedMonth)) \(selectedYear)"
                    )

                    infoPill(
                        icon: "list.bullet",
                        text: settings.language == .spanish
                        ? "\(selectedMonthExpenses.count) movimientos"
                        : "\(selectedMonthExpenses.count) transactions"
                    )

                    infoPill(
                        icon: "banknote",
                        text: settings.language == .spanish
                        ? "Año: \(settings.formatCurrency(selectedYearTotal, decimals: 0))"
                        : "Year: \(settings.formatCurrency(selectedYearTotal, decimals: 0))"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoPill(
                        icon: "calendar",
                        text: "\(monthFullLabel(selectedMonth)) \(selectedYear)"
                    )

                    infoPill(
                        icon: "list.bullet",
                        text: settings.language == .spanish
                        ? "\(selectedMonthExpenses.count) movimientos"
                        : "\(selectedMonthExpenses.count) transactions"
                    )

                    infoPill(
                        icon: "banknote",
                        text: settings.language == .spanish
                        ? "Año: \(settings.formatCurrency(selectedYearTotal, decimals: 0))"
                        : "Year: \(settings.formatCurrency(selectedYearTotal, decimals: 0))"
                    )
                }
            }
        }
        .padding(18)
        .background(BrandPalette.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var ledgerHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.language == .spanish ? "Registros históricos" : "Historical ledger")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(
                        settings.language == .spanish
                        ? "Todos tus gastos, todos tus años"
                        : "All your expenses, all your years"
                    )
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(
                        settings.language == .spanish
                        ? "Filtra por año o mes, busca movimientos viejos, impórtalos desde Excel en CSV y edítalos cuando quieras."
                        : "Filter by year or month, search old transactions, import them from Excel as CSV, and edit them anytime."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(BrandPalette.primary)
                    .frame(width: 54, height: 54)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    infoPill(
                        icon: "calendar.badge.clock",
                        text: settings.language == .spanish
                        ? "\(availableYears.count) años detectados"
                        : "\(availableYears.count) years found"
                    )

                    infoPill(
                        icon: "tray.full",
                        text: settings.language == .spanish
                        ? "\(expenses.count) gastos guardados"
                        : "\(expenses.count) saved expenses"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoPill(
                        icon: "calendar.badge.clock",
                        text: settings.language == .spanish
                        ? "\(availableYears.count) años detectados"
                        : "\(availableYears.count) years found"
                    )

                    infoPill(
                        icon: "tray.full",
                        text: settings.language == .spanish
                        ? "\(expenses.count) gastos guardados"
                        : "\(expenses.count) saved expenses"
                    )
                }
            }
        }
        .padding(18)
        .background(BrandPalette.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var yearSelectorCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.language == .spanish ? "Año activo" : "Active year")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(String(selectedYear))
                    .font(.title3.bold())
            }

            Spacer()

            Menu {
                ForEach(availableYears, id: \.self) { year in
                    Button(String(year)) {
                        selectedYear = year
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                    Text(settings.language == .spanish ? "Cambiar año" : "Change year")
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(BrandPalette.primary.opacity(0.12))
                .foregroundColor(BrandPalette.primary)
                .clipShape(Capsule())
            }
        }
        .padding(18)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var ledgerFiltersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(
                    settings.language == .spanish ? "Buscar gasto, categoría o fecha" : "Search expense, category or date",
                    text: $searchText
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            }
            .padding(14)
            .background(BrandPalette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BrandPalette.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 12) {
                Menu {
                    Button(settings.language == .spanish ? "Todos los años" : "All years") {
                        selectedLedgerYear = 0
                    }

                    ForEach(availableYears, id: \.self) { year in
                        Button(String(year)) {
                            selectedLedgerYear = year
                        }
                    }
                } label: {
                    filterChip(
                        title: settings.language == .spanish ? "Año" : "Year",
                        value: selectedLedgerYear == 0 ? (settings.language == .spanish ? "Todos" : "All") : String(selectedLedgerYear)
                    )
                }

                Menu {
                    Button(settings.language == .spanish ? "Todos los meses" : "All months") {
                        selectedLedgerMonth = 0
                    }

                    ForEach(1...12, id: \.self) { month in
                        Button(monthFullLabel(month)) {
                            selectedLedgerMonth = month
                        }
                    }
                } label: {
                    filterChip(
                        title: settings.language == .spanish ? "Mes" : "Month",
                        value: selectedLedgerMonth == 0 ? (settings.language == .spanish ? "Todos" : "All") : monthFullLabel(selectedLedgerMonth)
                    )
                }
            }
        }
    }

    private var ledgerSummaryGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Filtrados" : "Filtered",
                    value: "\(filteredLedgerExpenses.count)",
                    accent: .blue
                )

                summaryCard(
                    title: settings.language == .spanish ? "Total filtrado" : "Filtered total",
                    value: settings.formatCurrency(filteredLedgerTotal, decimals: 0),
                    accent: .purple
                )
            }

            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Más reciente" : "Most recent",
                    value: newestFilteredExpenseDate.map { settings.shortDateString(from: $0) } ?? "—",
                    accent: .green
                )

                summaryCard(
                    title: settings.language == .spanish ? "Más antiguo" : "Oldest",
                    value: oldestFilteredExpenseDate.map { settings.shortDateString(from: $0) } ?? "—",
                    accent: .orange
                )
            }
        }
    }

    private var summaryGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Total del mes" : "Month total",
                    value: settings.formatCurrency(selectedMonthTotal, decimals: 0),
                    accent: .blue
                )

                summaryCard(
                    title: settings.language == .spanish ? "Pagado en el año" : "Paid this year",
                    value: settings.formatCurrency(selectedYearTotal, decimals: 0),
                    accent: .purple
                )
            }

            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Promedio del mes" : "Month average",
                    value: settings.formatCurrency(selectedMonthAverage, decimals: 0),
                    accent: .pink
                )

                summaryCard(
                    title: settings.language == .spanish ? "Meses activos" : "Active months",
                    value: "\(activeMonthsInYearCount)/12",
                    accent: .green
                )
            }
        }
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: selectedMonthExpenses.isEmpty ? "moon.zzz.fill" : "arrow.left.arrow.right.circle.fill")
                    .foregroundColor(monthVsPreviousColor)

                Text(comparisonHeadline)
                    .font(.headline)

                Spacer()
            }

            Text(monthVsPreviousText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if previousMonthTotal > 0 {
                HStack {
                    Text(settings.language == .spanish ? "Mes anterior" : "Previous month")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(settings.formatCurrency(previousMonthTotal, decimals: 0))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func dominantCategoryCard(_ category: Category) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.16))
                    .frame(width: 52, height: 52)

                Image(systemName: category.icon)
                    .foregroundColor(category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.language == .spanish ? "Categoría más pesada" : "Heaviest category")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(category.displayName(language: settings.language))
                    .font(.headline)
            }

            Spacer()
        }
        .padding(18)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                settings.language == .spanish
                ? "Movimientos de \(monthFullLabel(selectedMonth))"
                : "\(monthFullLabel(selectedMonth)) transactions"
            )
            .font(.headline)

            ForEach(selectedMonthExpenses) { expense in
                expenseRow(expense)
            }
        }
    }

    private var ledgerSectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(ledgerSections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(settings.monthYearString(from: section.monthStart))
                            .font(.headline)

                        Spacer()

                        Text("\(section.expenses.count)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(BrandPalette.surface)
                            .clipShape(Capsule())
                    }

                    ForEach(section.expenses) { expense in
                        expenseRow(expense)
                    }
                }
            }
        }
    }

    private var emptyOverviewState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundColor(.secondary)

            Text(
                settings.language == .spanish
                ? "No hay movimientos en este mes"
                : "No transactions in this month"
            )
            .font(.headline)

            Text(
                settings.language == .spanish
                ? "Cambia de mes o agrega nuevos gastos. El gráfico anual sigue mostrando el ritmo del año completo."
                : "Switch months or add new expenses. The yearly chart still shows the rhythm of the full year."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyLedgerState: some View {
        VStack(spacing: 14) {
            Image(systemName: "archivebox")
                .font(.system(size: 30))
                .foregroundColor(.secondary)

            Text(
                settings.language == .spanish
                ? "No hay registros para este filtro"
                : "No records for this filter"
            )
            .font(.headline)

            Text(
                settings.language == .spanish
                ? "Prueba otro año, otro mes o importa un CSV exportado desde Excel."
                : "Try another year, another month, or import a CSV exported from Excel."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: expense.category.icon)
                    .foregroundColor(expense.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.subheadline.bold())

                Text(expense.category.displayName(language: settings.language))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(settings.formatCurrency(expense.amount, decimals: 0))
                    .font(.subheadline.bold())

                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Menu {
                Button {
                    editingExpense = expense
                } label: {
                    Label(
                        settings.language == .spanish ? "Editar" : "Edit",
                        systemImage: "square.and.pencil"
                    )
                }

                Button(role: .destructive) {
                    expensePendingDelete = expense
                } label: {
                    Label(
                        settings.language == .spanish ? "Eliminar" : "Delete",
                        systemImage: "trash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 34, height: 34)
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

    private func summaryCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline.bold())
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.primary)

            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BrandPalette.surface)
        .clipShape(Capsule())
    }

    private func filterChip(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.down")
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func configureInitialSelection() {
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        if availableYears.contains(currentYear) {
            selectedYear = currentYear
        } else {
            selectedYear = availableYears.first ?? currentYear
        }

        if selectedYear == currentYear {
            selectedMonth = currentMonth
        } else {
            let latestMonthWithData = selectedYearExpenses
                .map { calendar.component(.month, from: $0.date) }
                .max()

            selectedMonth = latestMonthWithData ?? currentMonth
        }
    }

    private func normalizeLedgerFiltersIfNeeded() {
        if selectedLedgerYear != 0 && !availableYears.contains(selectedLedgerYear) {
            selectedLedgerYear = 0
        }

        if !(0...12).contains(selectedLedgerMonth) {
            selectedLedgerMonth = 0
        }
    }

    private func updateExpense(_ updatedExpense: Expense) {
        guard let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) else {
            return
        }

        expenses[index] = updatedExpense
        expenses.sort { $0.date > $1.date }
        onPersist()
        configureInitialSelection()
        normalizeLedgerFiltersIfNeeded()
    }

    private func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        onPersist()
        configureInitialSelection()
        normalizeLedgerFiltersIfNeeded()
    }

    private func prepareExport(_ format: ExpensesTransferFormat) {
        do {
            let payload = try transferService.makeExport(from: expenses, format: format)
            exportDocument = ExportFileDocument(
                data: payload.data,
                contentType: payload.contentType
            )
            exportContentType = payload.contentType
            exportFilename = payload.fileName
            showExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, any Error>) {
        switch result {
        case let .success(url):
            importExpenses(from: url)

        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    private func importExpenses(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()

        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let contentType = UTType(filenameExtension: url.pathExtension)
            let importResult = try transferService.importExpenses(from: data, contentType: contentType)

            let mergeResult = mergeImportedExpenses(importResult.expenses)
            onPersist()
            configureInitialSelection()
            normalizeLedgerFiltersIfNeeded()

            successMessage = makeImportSummary(
                importedRows: importResult.importedRows,
                insertedRows: mergeResult.inserted,
                duplicateRows: mergeResult.duplicates,
                skippedRows: importResult.skippedRows
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mergeImportedExpenses(_ imported: [Expense]) -> (inserted: Int, duplicates: Int) {
        var existingKeys = Set(expenses.map { duplicateKey(for: $0) })
        var merged = expenses
        var inserted = 0
        var duplicates = 0

        for expense in imported {
            let key = duplicateKey(for: expense)

            if existingKeys.contains(key) {
                duplicates += 1
                continue
            }

            existingKeys.insert(key)
            merged.append(expense)
            inserted += 1
        }

        expenses = merged.sorted { $0.date > $1.date }
        return (inserted, duplicates)
    }

    private func duplicateKey(for expense: Expense) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return [
            expense.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            String(format: "%.2f", expense.amount),
            formatter.string(from: expense.date),
            expense.category.rawValue.lowercased()
        ].joined(separator: "|")
    }

    private func makeImportSummary(
        importedRows: Int,
        insertedRows: Int,
        duplicateRows: Int,
        skippedRows: Int
    ) -> String {
        if settings.language == .spanish {
            return """
            Importación terminada.

            Filas leídas: \(importedRows)
            Nuevos gastos agregados: \(insertedRows)
            Duplicados omitidos: \(duplicateRows)
            Filas inválidas omitidas: \(skippedRows)
            """
        } else {
            return """
            Import finished.

            Rows read: \(importedRows)
            New expenses added: \(insertedRows)
            Duplicates skipped: \(duplicateRows)
            Invalid rows skipped: \(skippedRows)
            """
        }
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func monthShortLabel(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.appLocale
        return formatter.shortMonthSymbols[month - 1].capitalized
    }

    private func monthFullLabel(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.appLocale
        return formatter.monthSymbols[month - 1].capitalized
    }
}

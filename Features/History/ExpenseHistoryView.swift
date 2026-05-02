import SwiftUI
import UniformTypeIdentifiers

struct ExpenseHistoryView: View {
    
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var auth: AuthManager

    @Binding var expenses: [Expense]
    @Binding var incomes: [Income]
    @Binding var moneyAccounts: [MoneyAccount]

    let onPersistExpenses: () -> Void
    let onPersistIncomes: () -> Void
    let onPersistMoneyAccounts: () -> Void

    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    @State private var selectedTab: HistoryTab = .overview
    @State private var selectedLedgerYear: Int = 0
    @State private var selectedLedgerMonth: Int = 0
    @State private var searchText = ""

    @State private var editingExpense: Expense?
    @State private var editingIncome: Income?
    @State private var pendingDelete: PendingDelete?

    @State private var exportDocument = ExportFileDocument()
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "expenses.json"
    @State private var showExporter = false
    @State private var showImporter = false

    @State private var successMessage: String?
    @State private var errorMessage: String?

    private let calendar = Calendar.current
    private let moneyAccountSync = MoneyAccountBalanceSync()
    private let expenseFundingSync = ExpenseFundingSync()
    private let transferService = ExpensesTransferService()
    private let importedExpenseMergeService = ImportedExpenseMergeService()
    private let recurringPaymentExpenseSync = RecurringPaymentExpenseSync()
    private let recurringGeneratedExpenseDeletionSync = RecurringGeneratedExpenseDeletionSync()

    private enum HistoryTab: String, CaseIterable, Identifiable {
        case overview
        case ledger

        var id: String { rawValue }
    }

    private enum PendingDelete {
        case expense(Expense)
        case income(Income)
    }

    private enum EntryKind {
        case expense
        case income
    }

    private struct LedgerEntry: Identifiable {
        let id: UUID
        let title: String
        let amount: Double
        let date: Date
        let subtitle: String
        let note: String?
        let icon: String
        let tint: Color
        let kind: EntryKind
        let expense: Expense?
        let income: Income?
    }

    private struct LedgerSection: Identifiable {
        let monthStart: Date
        let entries: [LedgerEntry]

        var id: Date { monthStart }
    }

    private var allYears: [Int] {
        let years = Set(
            expenses.map { calendar.component(.year, from: $0.date) }
            + incomes.map { calendar.component(.year, from: $0.date) }
        )

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

    private var selectedMonthIncomes: [Income] {
        incomes
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

    private var selectedYearIncomes: [Income] {
        incomes
            .filter { calendar.component(.year, from: $0.date) == selectedYear }
            .sorted { $0.date > $1.date }
    }
    
    private var debtNamesById: [UUID: String] {
        Dictionary(uniqueKeysWithValues: DataManager.shared.loadDebts(user: auth.currentUser).map { ($0.id, $0.cardName) })
    }

    private var selectedMonthExpenseTotal: Double {
        selectedMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var selectedMonthIncomeTotal: Double {
        selectedMonthIncomes.reduce(0) { $0 + $1.amount }
    }

    private var selectedMonthNet: Double {
        selectedMonthIncomeTotal - selectedMonthExpenseTotal
    }

    private var selectedYearExpenseTotal: Double {
        selectedYearExpenses.reduce(0) { $0 + $1.amount }
    }

    private var selectedYearIncomeTotal: Double {
        selectedYearIncomes.reduce(0) { $0 + $1.amount }
    }

    private var selectedYearNet: Double {
        selectedYearIncomeTotal - selectedYearExpenseTotal
    }

    private var selectedMonthAverageExpense: Double {
        guard !selectedMonthExpenses.isEmpty else { return 0 }
        return selectedMonthExpenseTotal / Double(selectedMonthExpenses.count)
    }

    private var activeMonthsInYearCount: Int {
        yearPoints.filter { $0.total > 0 }.count
    }

    private var previousMonthExpenseTotal: Double {
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

    private var previousMonthIncomeTotal: Double {
        guard let previousDate = calendar.date(byAdding: .month, value: -1, to: selectedMonthReferenceDate) else {
            return 0
        }

        let previousYear = calendar.component(.year, from: previousDate)
        let previousMonth = calendar.component(.month, from: previousDate)

        return incomes
            .filter {
                calendar.component(.year, from: $0.date) == previousYear &&
                calendar.component(.month, from: $0.date) == previousMonth
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var previousMonthNet: Double {
        previousMonthIncomeTotal - previousMonthExpenseTotal
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
        (1...12).map { month in
            let expensesTotal = expenses
                .filter {
                    calendar.component(.year, from: $0.date) == selectedYear &&
                    calendar.component(.month, from: $0.date) == month
                }
                .reduce(0) { $0 + $1.amount }

            let incomesTotal = incomes
                .filter {
                    calendar.component(.year, from: $0.date) == selectedYear &&
                    calendar.component(.month, from: $0.date) == month
                }
                .reduce(0) { $0 + $1.amount }

            let movementTotal = expensesTotal + incomesTotal

            return HistoryMonthData(
                id: month,
                month: month,
                label: monthShortLabel(month),
                total: movementTotal,
                hasExpenses: movementTotal > 0
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
        let delta = selectedMonthNet - previousMonthNet

        if previousMonthNet == 0, selectedMonthNet == 0 {
            return settings.language == .spanish
            ? "Sin comparación disponible"
            : "No comparison available"
        }

        if previousMonthNet == 0 {
            return settings.language == .spanish
            ? "Nuevo balance frente al mes anterior"
            : "New balance versus previous month"
        }

        if delta > 0 {
            return settings.language == .spanish
            ? "Mejoraste tu balance en \(settings.formatCurrency(delta, decimals: 2)) frente al mes anterior"
            : "Your balance improved by \(settings.formatCurrency(delta, decimals: 2)) versus previous month"
        }

        if delta < 0 {
            return settings.language == .spanish
            ? "Tu balance cayó \(settings.formatCurrency(abs(delta), decimals: 2)) frente al mes anterior"
            : "Your balance dropped by \(settings.formatCurrency(abs(delta), decimals: 2)) versus previous month"
        }

        return settings.language == .spanish
        ? "Mismo balance que el mes anterior"
        : "Same balance as previous month"
    }

    private var monthVsPreviousColor: Color {
        if selectedMonthNet > previousMonthNet { return .green }
        if selectedMonthNet < previousMonthNet { return .red }
        return .secondary
    }

    private var comparisonHeadline: String {
        if selectedMonthEntries.isEmpty {
            return settings.language == .spanish
            ? "Este mes está vacío"
            : "This month is empty"
        }

        if selectedMonthNet > 0 {
            return settings.language == .spanish
            ? "Mes con balance positivo"
            : "Month with positive balance"
        }

        if selectedMonthNet < 0 {
            return settings.language == .spanish
            ? "Mes con balance apretado"
            : "Month with tight balance"
        }

        return settings.language == .spanish
        ? "Mes equilibrado"
        : "Balanced month"
    }

    private var selectedMonthEntries: [LedgerEntry] {
        ledgerEntries(from: selectedMonthExpenses, incomes: selectedMonthIncomes)
    }

    private var filteredLedgerEntries: [LedgerEntry] {
        let filteredByYearAndMonth = ledgerEntries(from: expenses, incomes: incomes).filter { entry in
            let yearMatches = selectedLedgerYear == 0 || calendar.component(.year, from: entry.date) == selectedLedgerYear
            let monthMatches = selectedLedgerMonth == 0 || calendar.component(.month, from: entry.date) == selectedLedgerMonth
            return yearMatches && monthMatches
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let searched = filteredByYearAndMonth.filter { entry in
            guard !trimmedSearch.isEmpty else { return true }

            return entry.title.localizedCaseInsensitiveContains(trimmedSearch)
            || entry.subtitle.localizedCaseInsensitiveContains(trimmedSearch)
            || settings.shortDateString(from: entry.date).localizedCaseInsensitiveContains(trimmedSearch)
        }

        return searched.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var ledgerSections: [LedgerSection] {
        let grouped = Dictionary(grouping: filteredLedgerEntries) { entry in
            startOfMonth(for: entry.date)
        }

        return grouped
            .map { LedgerSection(monthStart: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.monthStart > $1.monthStart }
    }

    private var filteredLedgerExpenseTotal: Double {
        filteredLedgerEntries
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var filteredLedgerIncomeTotal: Double {
        filteredLedgerEntries
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var filteredLedgerNet: Double {
        filteredLedgerIncomeTotal - filteredLedgerExpenseTotal
    }

    private var oldestFilteredEntryDate: Date? {
        filteredLedgerEntries.last?.date
    }

    private var newestFilteredEntryDate: Date? {
        filteredLedgerEntries.first?.date
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
                            annualTotal: selectedYearExpenseTotal
                        )

                        if let dominantCategory, !selectedMonthExpenses.isEmpty {
                            dominantCategoryCard(dominantCategory)
                        }

                        if selectedMonthEntries.isEmpty {
                            emptyOverviewState
                        } else {
                            if !selectedMonthExpenses.isEmpty {
                                ExpensesChartView(expenses: selectedMonthExpenses)
                            }
                            transactionsSection
                        }
                    } else {
                        ledgerHeroCard
                        ledgerFiltersCard
                        ledgerSummaryGrid

                        if let newestFilteredEntryDate, let oldestFilteredEntryDate {
                            dateRangeInfo(
                                newest: newestFilteredEntryDate,
                                oldest: oldestFilteredEntryDate
                            )
                        }

                        if filteredLedgerEntries.isEmpty {
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
                                settings.language == .spanish ? "Importar gastos CSV o JSON" : "Import expenses CSV or JSON",
                                systemImage: "square.and.arrow.down"
                            )
                        }

                        Divider()

                        Button {
                            prepareExport(.csv)
                        } label: {
                            Label(
                                settings.language == .spanish ? "Exportar gastos CSV" : "Export expenses CSV",
                                systemImage: "tablecells"
                            )
                        }

                        Button {
                            prepareExport(.json)
                        } label: {
                            Label(
                                settings.language == .spanish ? "Exportar gastos JSON" : "Export expenses JSON",
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
                AddExpenseView(
                    existingExpense: expense,
                    moneyAccounts: moneyAccounts,
                    debts: DataManager.shared.loadDebts(user: auth.currentUser)
                ) { updatedExpense in
                    updateExpense(updatedExpense)
                }
                .environmentObject(auth)
                .environmentObject(settings)
            }
            .sheet(item: $editingIncome) { income in
                AddIncomeView(existingIncome: income, moneyAccounts: moneyAccounts) { updatedIncome in
                    updateIncome(updatedIncome)
                }
                .environmentObject(auth)
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
                deleteAlertTitle,
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { newValue in
                        if !newValue {
                            pendingDelete = nil
                        }
                    }
                )
            ) {
                Button(settings.t("common.cancel"), role: .cancel) {
                    pendingDelete = nil
                }

                Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                    confirmDelete()
                }
            } message: {
                Text(deleteAlertMessage)
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

    private var deleteAlertTitle: String {
        switch pendingDelete {
        case .expense:
            return settings.language == .spanish ? "Eliminar gasto" : "Delete expense"
        case .income:
            return settings.language == .spanish ? "Eliminar ingreso" : "Delete income"
        case nil:
            return ""
        }
    }

    private var deleteAlertMessage: String {
        switch pendingDelete {
        case let .expense(expense):
            return settings.language == .spanish
            ? "Se borrará \"\(expense.title)\" de forma permanente."
            : "\"\(expense.title)\" will be permanently removed."
        case let .income(income):
            return settings.language == .spanish
            ? "Se borrará \"\(income.title)\" de forma permanente."
            : "\"\(income.title)\" will be permanently removed."
        case nil:
            return ""
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
                        ? "Ahora puedes ver ingresos y gastos en el mismo mes para entender tu balance real."
                        : "You can now see income and expenses in the same month to understand your real balance."
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
                        ? "\(selectedMonthEntries.count) movimientos"
                        : "\(selectedMonthEntries.count) transactions"
                    )

                    infoPill(
                        icon: "plusminus",
                        text: settings.language == .spanish
                        ? "Balance: \(settings.formatCurrency(selectedMonthNet, decimals: 2))"
                        : "Net: \(settings.formatCurrency(selectedMonthNet, decimals: 2))"
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
                        ? "\(selectedMonthEntries.count) movimientos"
                        : "\(selectedMonthEntries.count) transactions"
                    )

                    infoPill(
                        icon: "plusminus",
                        text: settings.language == .spanish
                        ? "Balance: \(settings.formatCurrency(selectedMonthNet, decimals: 2))"
                        : "Net: \(settings.formatCurrency(selectedMonthNet, decimals: 2))"
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
                        ? "Todos tus movimientos, todos tus años"
                        : "All your movements, all your years"
                    )
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(
                        settings.language == .spanish
                        ? "Filtra por año o mes, busca ingresos y gastos viejos, importa gastos desde CSV y edita todo desde un solo lugar."
                        : "Filter by year or month, search old income and expenses, import expenses from CSV, and edit everything in one place."
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
                        ? "\(allYears.count) años detectados"
                        : "\(allYears.count) years found"
                    )

                    infoPill(
                        icon: "tray.full",
                        text: settings.language == .spanish
                        ? "\(expenses.count + incomes.count) movimientos guardados"
                        : "\(expenses.count + incomes.count) saved movements"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoPill(
                        icon: "calendar.badge.clock",
                        text: settings.language == .spanish
                        ? "\(allYears.count) años detectados"
                        : "\(allYears.count) years found"
                    )

                    infoPill(
                        icon: "tray.full",
                        text: settings.language == .spanish
                        ? "\(expenses.count + incomes.count) movimientos guardados"
                        : "\(expenses.count + incomes.count) saved movements"
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
                ForEach(allYears, id: \.self) { year in
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
                    settings.language == .spanish ? "Buscar movimiento, categoría o fecha" : "Search movement, category or date",
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

                    ForEach(allYears, id: \.self) { year in
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
                    value: "\(filteredLedgerEntries.count)",
                    accent: .blue
                )

                summaryCard(
                    title: settings.language == .spanish ? "Ingresos" : "Income",
                    value: settings.formatCurrency(filteredLedgerIncomeTotal, decimals: 2),
                    accent: .green
                )
            }

            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Gastos" : "Expenses",
                    value: settings.formatCurrency(filteredLedgerExpenseTotal, decimals: 2),
                    accent: .red
                )

                summaryCard(
                    title: settings.language == .spanish ? "Balance" : "Net",
                    value: settings.formatCurrency(filteredLedgerNet, decimals: 2),
                    accent: filteredLedgerNet >= 0 ? .green : .orange
                )
            }
        }
    }

    private var summaryGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Ingresos del mes" : "Month income",
                    value: settings.formatCurrency(selectedMonthIncomeTotal, decimals: 2),
                    accent: .green
                )

                summaryCard(
                    title: settings.language == .spanish ? "Gastos del mes" : "Month expenses",
                    value: settings.formatCurrency(selectedMonthExpenseTotal, decimals: 2),
                    accent: .red
                )
            }

            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Balance del mes" : "Month net",
                    value: settings.formatCurrency(selectedMonthNet, decimals: 2),
                    accent: selectedMonthNet >= 0 ? .green : .orange
                )

                summaryCard(
                    title: settings.language == .spanish ? "Balance del año" : "Year net",
                    value: settings.formatCurrency(selectedYearNet, decimals: 2),
                    accent: selectedYearNet >= 0 ? .blue : .orange
                )
            }

            HStack(spacing: 12) {
                summaryCard(
                    title: settings.language == .spanish ? "Promedio de gastos" : "Expense average",
                    value: settings.formatCurrency(selectedMonthAverageExpense, decimals: 2),
                    accent: .pink
                )

                summaryCard(
                    title: settings.language == .spanish ? "Meses activos" : "Active months",
                    value: "\(activeMonthsInYearCount)/12",
                    accent: .purple
                )
            }
        }
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: selectedMonthEntries.isEmpty ? "moon.zzz.fill" : "arrow.left.arrow.right.circle.fill")
                    .foregroundColor(monthVsPreviousColor)

                Text(comparisonHeadline)
                    .font(.headline)

                Spacer()
            }

            Text(monthVsPreviousText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text(settings.language == .spanish ? "Mes anterior" : "Previous month")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(settings.formatCurrency(previousMonthNet, decimals: 2))
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
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
                Text(settings.language == .spanish ? "Categoría que más pesa" : "Heaviest expense category")
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
                : "\(monthFullLabel(selectedMonth)) movements"
            )
            .font(.headline)

            ForEach(selectedMonthEntries) { entry in
                entryRow(entry)
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

                        Text("\(section.entries.count)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(BrandPalette.surface)
                            .clipShape(Capsule())
                    }

                    ForEach(section.entries) { entry in
                        entryRow(entry)
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
                : "No movements in this month"
            )
            .font(.headline)

            Text(
                settings.language == .spanish
                ? "Cambia de mes o agrega ingresos y gastos nuevos. El gráfico anual sigue mostrando el ritmo de tus gastos del año completo."
                : "Switch months or add new income and expenses. The yearly chart still shows the rhythm of your annual spending."
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
                ? "Prueba otro año, otro mes o importa un CSV de gastos exportado desde Excel."
                : "Try another year, another month, or import an expenses CSV exported from Excel."
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

    private func entryRow(_ entry: LedgerEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(entry.tint.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: entry.icon)
                    .foregroundColor(entry.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline.bold())

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: entry.kind == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(entry.kind == .income ? .green : .red)

                    Text(amountLabel(for: entry))
                        .font(.subheadline.bold())
                        .foregroundColor(entry.kind == .income ? .green : .red)
                }

                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Menu {
                if let expense = entry.expense {
                    Button {
                        editingExpense = expense
                    } label: {
                        Label(
                            settings.language == .spanish ? "Editar gasto" : "Edit expense",
                            systemImage: "square.and.pencil"
                        )
                    }
                    .accessibilityIdentifier("history.edit.expense")

                    Button(role: .destructive) {
                        pendingDelete = .expense(expense)
                    } label: {
                        Label(
                            settings.language == .spanish ? "Eliminar gasto" : "Delete expense",
                            systemImage: "trash"
                        )
                    }
                    .accessibilityIdentifier("history.delete.expense")
                }

                if let income = entry.income {
                    Button {
                        editingIncome = income
                    } label: {
                        Label(
                            settings.language == .spanish ? "Editar ingreso" : "Edit income",
                            systemImage: "square.and.pencil"
                        )
                    }
                    .accessibilityIdentifier("history.edit.income")

                    Button(role: .destructive) {
                        pendingDelete = .income(income)
                    } label: {
                        Label(
                            settings.language == .spanish ? "Eliminar ingreso" : "Delete income",
                            systemImage: "trash"
                        )
                    }
                    .accessibilityIdentifier("history.delete.income")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .accessibilityIdentifier("history.entry.menu")
        }
        .padding(16)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func directionIcon(for entry: LedgerEntry) -> String {
        switch entry.kind {
        case .expense:
            return "arrow.up.circle.fill"
        case .income:
            return "arrow.down.circle.fill"
        }
    }

    private func directionColor(for entry: LedgerEntry) -> Color {
        switch entry.kind {
        case .expense:
            return .red
        case .income:
            return .green
        }
    }

    private func amountLabel(for entry: LedgerEntry) -> String {
        let formatted = settings.formatCurrency(entry.amount, decimals: 2)

        switch entry.kind {
        case .expense:
            return "−\(formatted)"
        case .income:
            return "+\(formatted)"
        }
    }

    private func dateRangeInfo(newest: Date, oldest: Date) -> some View {
        HStack(spacing: 8) {
            infoPill(
                icon: "clock.badge.checkmark",
                text: settings.language == .spanish
                ? "Más reciente: \(settings.shortDateString(from: newest))"
                : "Newest: \(settings.shortDateString(from: newest))"
            )

            infoPill(
                icon: "clock.arrow.circlepath",
                text: settings.language == .spanish
                ? "Más antiguo: \(settings.shortDateString(from: oldest))"
                : "Oldest: \(settings.shortDateString(from: oldest))"
            )
        }
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

        if allYears.contains(currentYear) {
            selectedYear = currentYear
        } else {
            selectedYear = allYears.first ?? currentYear
        }

        if selectedYear == currentYear {
            selectedMonth = currentMonth
        } else {
            let latestMonthWithData = selectedYearEntries
                .map { calendar.component(.month, from: $0.date) }
                .max()

            selectedMonth = latestMonthWithData ?? currentMonth
        }
    }

    private var selectedYearEntries: [LedgerEntry] {
        ledgerEntries(from: selectedYearExpenses, incomes: selectedYearIncomes)
    }

    private func normalizeLedgerFiltersIfNeeded() {
        if selectedLedgerYear != 0 && !allYears.contains(selectedLedgerYear) {
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

        let previousExpense = expenses[index]
        expenses[index] = updatedExpense
        expenses.sort { $0.date > $1.date }

        var debts = DataManager.shared.loadDebts(user: auth.currentUser)
        expenseFundingSync.applyExpenseUpdate(from: previousExpense, to: updatedExpense, accounts: &moneyAccounts, debts: &debts)
        DataManager.shared.saveDebts(debts, user: auth.currentUser)
        
        AuditLogStore.shared.logExpenseUpdated(
            from: previousExpense,
            to: updatedExpense,
            user: auth.currentUser
        )

        onPersistExpenses()
        onPersistMoneyAccounts()
        configureInitialSelection()
        normalizeLedgerFiltersIfNeeded()
    }

    private func updateIncome(_ updatedIncome: Income) {
        guard let index = incomes.firstIndex(where: { $0.id == updatedIncome.id }) else {
            return
        }

        let previousIncome = incomes[index]
        incomes[index] = updatedIncome
        incomes.sort { $0.date > $1.date }

        moneyAccountSync.applyIncomeUpdate(from: previousIncome, to: updatedIncome, accounts: &moneyAccounts)
        
        AuditLogStore.shared.logIncomeUpdated(
            from: previousIncome,
            to: updatedIncome,
            user: auth.currentUser
        )

        onPersistIncomes()
        onPersistMoneyAccounts()
        configureInitialSelection()
        normalizeLedgerFiltersIfNeeded()
    }

    private func deleteExpense(_ expense: Expense) {
        var debts = DataManager.shared.loadDebts(user: auth.currentUser)

        expenseFundingSync.applyExpenseDeletion(
            expense,
            accounts: &moneyAccounts,
            debts: &debts
        )

        var recurringPayments = DataManager.shared.loadRecurringPayments(user: auth.currentUser)

        let recurringRepairResult = recurringGeneratedExpenseDeletionSync.repairAfterDeletingGeneratedExpense(
            expenseId: expense.id,
            recurringPayments: recurringPayments,
            debts: debts
        )

        if recurringRepairResult.hasChanges {
            recurringPayments = recurringRepairResult.recurringPayments
            debts = recurringRepairResult.debts

            for event in recurringRepairResult.events {
                AuditLogStore.shared.logRecurringPaymentMarkedUnpaid(
                    event.updatedPayment,
                    user: auth.currentUser
                )

                if let previousDebt = event.previousDebt,
                   let updatedDebt = event.updatedDebt {
                    AuditLogStore.shared.logLinkedLoanRecurringPaymentReverted(
                        from: previousDebt,
                        to: updatedDebt,
                        payment: event.previousPayment,
                        user: auth.currentUser
                    )
                }
            }

            DataManager.shared.saveRecurringPayments(recurringPayments, user: auth.currentUser)
        }

        DataManager.shared.saveDebts(debts, user: auth.currentUser)

        expenses.removeAll { $0.id == expense.id }

        AuditLogStore.shared.logExpenseDeleted(
            expense,
            user: auth.currentUser,
            note: recurringRepairResult.hasChanges
            ? (
                settings.language == .spanish
                ? "Se eliminó un gasto generado por pago fijo; el préstamo vinculado fue restaurado."
                : "A generated recurring payment expense was deleted; the linked loan was restored."
            )
            : nil
        )

        onPersistExpenses()
        onPersistMoneyAccounts()
        configureInitialSelection()
        normalizeLedgerFiltersIfNeeded()
    }

    private func deleteIncome(_ income: Income) {
        moneyAccountSync.applyIncomeDeletion(income, to: &moneyAccounts)
        incomes.removeAll { $0.id == income.id }
        
        AuditLogStore.shared.logIncomeDeleted(income, user: auth.currentUser)

        onPersistIncomes()
        onPersistMoneyAccounts()
        configureInitialSelection()
        normalizeLedgerFiltersIfNeeded()
    }

    private func confirmDelete() {
        defer { pendingDelete = nil }

        switch pendingDelete {
        case let .expense(expense):
            deleteExpense(expense)
        case let .income(income):
            deleteIncome(income)
        case nil:
            break
        }
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

            var debts = DataManager.shared.loadDebts(user: auth.currentUser)

            let mergeResult = importedExpenseMergeService.merge(
                existingExpenses: expenses,
                importedExpenses: importResult.expenses,
                accounts: &moneyAccounts,
                debts: &debts
            )

            expenses = mergeResult.expenses

            if mergeResult.inserted > 0 {
                DataManager.shared.saveDebts(debts, user: auth.currentUser)
                onPersistExpenses()
                onPersistMoneyAccounts()
            }

            configureInitialSelection()
            normalizeLedgerFiltersIfNeeded()

            successMessage = makeImportSummary(
                totalRows: importResult.totalRows,
                importedRows: importResult.importedRows,
                insertedRows: mergeResult.inserted,
                duplicateRows: mergeResult.duplicates,
                skippedRows: importResult.skippedRows + mergeResult.invalidFinancialRows
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeImportSummary(
        totalRows: Int,
        importedRows: Int,
        insertedRows: Int,
        duplicateRows: Int,
        skippedRows: Int
    ) -> String {
        if settings.language == .spanish {
            return """
            Importación terminada.

            Filas leídas: \(totalRows)
            Filas válidas importadas: \(importedRows)
            Nuevos gastos agregados: \(insertedRows)
            Duplicados omitidos: \(duplicateRows)
            Filas inválidas o inseguras omitidas: \(skippedRows)
            """
        } else {
            return """
            Import finished.

            Rows read: \(totalRows)
            Valid rows imported: \(importedRows)
            New expenses added: \(insertedRows)
            Duplicates skipped: \(duplicateRows)
            Invalid or unsafe rows skipped: \(skippedRows)
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
    
    private func entrySubtitle(base: String, moneyAccountId: UUID?, creditCardId: UUID?) -> String {
        if let moneyAccountId,
           let account = moneyAccounts.first(where: { $0.id == moneyAccountId }) {
            return "\(base) · \(account.name)"
        }

        if let creditCardId,
           let cardName = debtNamesById[creditCardId] {
            return "\(base) · \(cardName)"
        }

        return base
    }
    private func ledgerEntries(from expenses: [Expense], incomes: [Income]) -> [LedgerEntry] {
        let expenseEntries = expenses.map { expense in
            LedgerEntry(
                id: expense.id,
                title: expense.title,
                amount: expense.amount,
                date: expense.date,
                subtitle: entrySubtitle(
                    base: expense.categoryDisplayName(language: settings.language),
                    moneyAccountId: expense.moneyAccountId,
                    creditCardId: expense.creditCardId
                ),
                note: expense.normalizedComment,
                icon: expense.category.icon,
                tint: expense.category.color,
                kind: .expense,
                expense: expense,
                income: nil
            )
        }

        let incomeEntries = incomes.map { income in
            LedgerEntry(
                id: income.id,
                title: income.title,
                amount: income.amount,
                date: income.date,
                subtitle: entrySubtitle(
                    base: income.categoryDisplayName(language: settings.language),
                    moneyAccountId: income.moneyAccountId,
                    creditCardId: nil
                ),
                note: income.normalizedComment,
                icon: income.category.icon,
                tint: income.category.color,
                kind: .income,
                expense: nil,
                income: income
            )
        }

        return (expenseEntries + incomeEntries)
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
}

import SwiftUI
import PhotosUI
import UIKit

struct DashboardView: View {

    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var settings: AppSettings

    @Binding var expenses: [Expense]
    @Binding var incomes: [Income]
    @Binding var monthlyBudget: MonthlyBudget
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var profileImageData: Data?
    let profileDisplayName: String
    @Binding var showAddExpense: Bool
    @Binding var showAddIncome: Bool

    let onReloadHomeData: () -> Void
    let onPersistExpenses: () -> Void
    let onRequestBudgetEdit: () -> Void
    let onRefreshInsight: () -> Void
    let onEvaluateBudgetNotifications: () -> Void

    @State private var debts: [Debt] = []
    @State private var recurringPayments: [RecurringPayment] = []

    private let calendar = Calendar.current

    private var currentMonthExpenses: [Expense] {
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }
    }

    private var currentMonthIncomes: [Income] {
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return incomes.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }
    }

    private var totalSpent: Double {
        currentMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        currentMonthIncomes.reduce(0) { $0 + $1.amount }
    }

    private var netBalance: Double {
        totalIncome - totalSpent
    }

    private var remainingBudget: Double {
        monthlyBudget.amount - totalSpent
    }

    private var budgetProgress: Double {
        guard monthlyBudget.amount > 0 else { return 0 }
        let raw = totalSpent / monthlyBudget.amount
        guard raw.isFinite else { return 0 }
        return raw
    }

    private var safeBudgetProgress: Double {
        min(max(budgetProgress, 0), 1)
    }

    private var expenseTotalsByCategory: [Category: Double] {
        Dictionary(grouping: currentMonthExpenses, by: \.category)
            .mapValues { group in
                group.reduce(0) { $0 + $1.amount }
            }
    }

    private var topExpenseCategory: Category? {
        expenseTotalsByCategory.max { $0.value < $1.value }?.key
    }

    private var currentMonthLabel: String {
        settings.monthYearString(from: Date())
    }
    
    private var effectiveDashboardName: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            return trimmed
        }

        if auth.isUsingLocalMode {
            return settings.language == .spanish ? "local" : "local"
        }

        return auth.currentUser
    }

    private var greetingText: String {
        let hour = calendar.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return settings.tr("main.goodMorning", effectiveDashboardName)
        case 12..<19:
            return settings.tr("main.goodAfternoon", effectiveDashboardName)
        default:
            return settings.tr("main.goodEvening", effectiveDashboardName)
        }
    }

    private var headerSubtitle: String {
        if totalIncome <= 0 && currentMonthExpenses.isEmpty {
            return settings.language == .spanish
            ? "Empieza registrando ingresos y gastos para entender mejor tu mes."
            : "Start by recording income and expenses to understand your month."
        } else if totalIncome > 0 && currentMonthExpenses.isEmpty {
            return settings.language == .spanish
            ? "Ya registraste ingresos. Ahora agrega gastos para medir tu balance real."
            : "Your income is already registered. Now add expenses to measure your real balance."
        } else if monthlyBudget.amount <= 0 {
            return settings.t("main.header.noBudget")
        } else if remainingBudget < 0 {
            return settings.t("main.header.over")
        } else if budgetProgress >= 0.8 {
            return settings.t("main.header.near")
        } else {
            return settings.t("main.header.ok")
        }
    }

    private var incomeCountText: String {
        settings.language == .spanish
        ? "\(currentMonthIncomes.count) ingresos"
        : "\(currentMonthIncomes.count) incomes"
    }

    private var expenseCountText: String {
        settings.language == .spanish
        ? "\(currentMonthExpenses.count) gastos"
        : "\(currentMonthExpenses.count) expenses"
    }

    private var netBalanceColor: Color {
        if netBalance > 0 {
            return .green
        } else if netBalance < 0 {
            return .red
        } else {
            return BrandPalette.primary
        }
    }

    private var progressTintColor: Color {
        if budgetProgress >= 1.0 {
            return .red
        } else if budgetProgress >= 0.8 {
            return BrandPalette.secondary
        } else {
            return BrandPalette.primary
        }
    }

    private var totalDebt: Double {
        debts.reduce(0) { $0 + $1.remainingDebt }
    }

    private var totalCreditLimit: Double {
        debts.reduce(0) { $0 + $1.totalLimit }
    }

    private var debtUtilization: Double {
        guard totalCreditLimit > 0 else { return 0 }
        let raw = totalDebt / totalCreditLimit
        guard raw.isFinite else { return 0 }
        return min(max(raw, 0), 1)
    }

    private var highlightedDebt: Debt? {
        debts.max { $0.remainingDebt < $1.remainingDebt }
    }

    private var recentActivity: [DashboardActivityItem] {
        let expenseItems = currentMonthExpenses.map { expense in
            DashboardActivityItem(
                id: "expense-\(expense.id.uuidString)",
                title: expense.title,
                subtitle: expense.category.displayName(language: settings.language),
                amount: expense.amount,
                date: expense.date,
                icon: expense.category.icon,
                tint: expense.category.color,
                kind: .expense
            )
        }

        let incomeItems = currentMonthIncomes.map { income in
            DashboardActivityItem(
                id: "income-\(income.id.uuidString)",
                title: income.title,
                subtitle: income.category.displayName(language: settings.language),
                amount: income.amount,
                date: income.date,
                icon: income.category.icon,
                tint: income.category.color,
                kind: .income
            )
        }

        return (expenseItems + incomeItems)
            .sorted { $0.date > $1.date }
    }

    private var upcomingRecurringItems: [UpcomingRecurringItem] {
        recurringPayments
            .filter { $0.isActive && !$0.isPaidForCurrentMonth }
            .compactMap { payment in
                guard let dueDate = payment.dueDate(inMonthOf: Date()) else { return nil }
                return UpcomingRecurringItem(payment: payment, dueDate: dueDate)
            }
            .sorted {
                if $0.isOverdue != $1.isOverdue {
                    return $0.isOverdue && !$1.isOverdue
                }
                return $0.dueDate < $1.dueDate
            }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                overviewSection
                budgetProgressSection
                focusStripSection
                upcomingPaymentsSection
                debtSnapshotSection

                if let category = topExpenseCategory,
                   let amount = expenseTotalsByCategory[category] {
                    topCategorySection(category: category, amount: amount)
                }

                recentActivitySection
                quickActionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .refreshable {
            onReloadHomeData()
            refreshSecondaryData()
        }
        .onAppear {
            refreshSecondaryData()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(greetingText)
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(settings.language == .spanish ? "Panel financiero" : "Financial dashboard")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                avatarPickerButton
                    .padding(.top, 4)
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    headerPill(icon: "calendar", text: currentMonthLabel)
                    headerPill(icon: "list.bullet", text: settings.tr("main.movesCount", currentMonthExpenses.count + currentMonthIncomes.count))
                    headerPill(icon: "arrow.down.circle", text: incomeCountText)
                    headerPill(icon: "arrow.up.circle", text: expenseCountText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    headerPill(icon: "calendar", text: currentMonthLabel)
                    headerPill(icon: "list.bullet", text: settings.tr("main.movesCount", currentMonthExpenses.count + currentMonthIncomes.count))
                    headerPill(icon: "arrow.down.circle", text: incomeCountText)
                    headerPill(icon: "arrow.up.circle", text: expenseCountText)
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

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.language == .spanish ? "Resumen del mes" : "Month snapshot")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(settings.secureCurrency(netBalance))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(netBalanceColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(
                        settings.language == .spanish
                        ? "Balance neto = ingresos del mes menos gastos del mes."
                        : "Net balance = monthly income minus monthly expenses."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onRequestBudgetEdit) {
                    Image(systemName: "square.and.pencil")
                        .font(.headline)
                        .foregroundColor(BrandPalette.primary)
                        .frame(width: 42, height: 42)
                        .background(BrandPalette.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                summaryMetricCard(
                    title: settings.language == .spanish ? "Ingresos" : "Income",
                    value: settings.secureCurrency(totalIncome),
                    tone: .positive,
                    icon: "arrow.down.circle"
                )

                summaryMetricCard(
                    title: settings.t("main.totalSpent"),
                    value: settings.secureCurrency(totalSpent),
                    tone: .negative,
                    icon: "arrow.up.circle"
                )

                summaryMetricCard(
                    title: settings.language == .spanish ? "Balance neto" : "Net balance",
                    value: settings.secureCurrency(netBalance),
                    tone: netBalance >= 0 ? .positive : .negative,
                    icon: "equal.circle"
                )

                summaryMetricCard(
                    title: settings.language == .spanish ? "Presupuesto restante" : "Budget left",
                    value: monthlyBudget.amount > 0 ? settings.secureCurrency(remainingBudget) : budgetNotSetText,
                    tone: monthlyBudget.amount > 0
                    ? (remainingBudget >= 0 ? .neutral : .negative)
                    : .muted,
                    icon: "wallet.pass"
                )
            }
        }
        .padding(20)
        .background(BrandPalette.cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var budgetProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.t("main.progressTitle"))
                        .font(.headline)

                    Text(monthlyBudget.amount > 0 ? settings.secureCurrency(monthlyBudget.amount) : budgetNotSetText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(Int((safeBudgetProgress * 100).rounded()))%")
                    .font(.subheadline.bold())
                    .foregroundColor(progressTintColor)
            }

            ProgressView(value: safeBudgetProgress)
                .tint(progressTintColor)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)

            if monthlyBudget.amount <= 0 {
                Text(settings.t("main.progressHintSetBudget"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if remainingBudget >= 0 {
                Text(settings.tr("main.progressRemaining", settings.secureCurrency(remainingBudget)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(settings.tr("main.progressExceeded", settings.secureCurrency(abs(remainingBudget))))
                    .font(.caption.bold())
                    .foregroundColor(.red)
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

    private var focusStripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.language == .spanish ? "Enfoque del mes" : "Month focus")
                .font(.headline)

            HStack(spacing: 12) {
                compactFocusCard(
                    title: settings.language == .spanish ? "Movimientos" : "Entries",
                    value: "\(currentMonthExpenses.count + currentMonthIncomes.count)",
                    subtitle: currentMonthLabel,
                    icon: "list.bullet.rectangle.portrait"
                )

                compactFocusCard(
                    title: settings.language == .spanish ? "Gastos" : "Expenses",
                    value: "\(currentMonthExpenses.count)",
                    subtitle: settings.secureCurrency(totalSpent),
                    icon: "arrow.up.right"
                )
            }

            HStack(spacing: 12) {
                compactFocusCard(
                    title: settings.language == .spanish ? "Ingresos" : "Incomes",
                    value: "\(currentMonthIncomes.count)",
                    subtitle: settings.secureCurrency(totalIncome),
                    icon: "arrow.down.left"
                )

                compactFocusCard(
                    title: settings.language == .spanish ? "Deudas" : "Debts",
                    value: "\(debts.count)",
                    subtitle: settings.secureCurrency(totalDebt),
                    icon: "creditcard"
                )
            }
        }
    }

    private var upcomingPaymentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(settings.language == .spanish ? "Próximos pagos fijos" : "Upcoming fixed payments")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    RecurringPaymentsView()
                } label: {
                    Text(settings.language == .spanish ? "Ver todo" : "See all")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)
                }
            }

            if upcomingRecurringItems.isEmpty {
                emptyDashboardCard(
                    title: settings.language == .spanish ? "Nada pendiente por ahora" : "Nothing pending right now",
                    subtitle: settings.language == .spanish
                    ? "Tus pagos fijos activos del mes ya están marcados o aún no tienes ninguno creado."
                    : "Your active monthly fixed payments are already marked or you have not created any yet."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(upcomingRecurringItems.prefix(4)) { item in
                        upcomingPaymentRow(item)
                    }
                }
            }
        }
    }

    private var debtSnapshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(settings.language == .spanish ? "Resumen de deudas" : "Debt snapshot")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    DebtsView()
                } label: {
                    Text(settings.language == .spanish ? "Abrir" : "Open")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)
                }
            }

            if debts.isEmpty {
                emptyDashboardCard(
                    title: settings.language == .spanish ? "Aún no tienes deudas registradas" : "You do not have debts yet",
                    subtitle: settings.language == .spanish
                    ? "Agrega tarjetas o saldos pendientes para seguir el uso de tu crédito."
                    : "Add cards or pending balances to track your credit usage."
                )
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        summaryMetricCard(
                            title: settings.language == .spanish ? "Deuda total" : "Total debt",
                            value: settings.secureCurrency(totalDebt),
                            tone: .negative,
                            icon: "creditcard.trianglebadge.exclamationmark"
                        )

                        summaryMetricCard(
                            title: settings.language == .spanish ? "Utilización" : "Utilization",
                            value: "\(Int((debtUtilization * 100).rounded()))%",
                            tone: debtUtilization >= 0.8 ? .negative : .neutral,
                            icon: "chart.bar.xaxis"
                        )
                    }

                    if let highlightedDebt {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 46, height: 46)

                                Image(systemName: highlightedDebt.brand.systemImageName)
                                    .foregroundColor(.red)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(highlightedDebt.cardName)
                                    .font(.subheadline.bold())

                                Text(
                                    settings.language == .spanish
                                    ? "Saldo más alto del mes"
                                    : "Highest balance right now"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(settings.secureCurrency(highlightedDebt.remainingDebt))
                                .font(.subheadline.bold())
                                .foregroundColor(.red)
                        }
                        .padding(16)
                        .background(BrandPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private func topCategorySection(category: Category, amount: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.18))
                    .frame(width: 54, height: 54)

                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.t("main.topCategory"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(category.displayName(language: settings.language))
                    .font(.headline)
            }

            Spacer()

            Text(settings.secureCurrency(amount))
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(18)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(settings.language == .spanish ? "Actividad reciente" : "Recent activity")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    ExpenseHistoryView(
                        expenses: $expenses,
                        onPersist: {
                            onPersistExpenses()
                            onRefreshInsight()
                            onEvaluateBudgetNotifications()
                        }
                    )
                    .environmentObject(settings)
                } label: {
                    Text(settings.language == .spanish ? "Historial" : "History")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)
                }
            }

            if recentActivity.isEmpty {
                emptyDashboardCard(
                    title: settings.language == .spanish ? "Todavía no hay actividad" : "No activity yet",
                    subtitle: settings.language == .spanish
                    ? "Empieza agregando ingresos o gastos para llenar esta sección."
                    : "Start adding income or expenses to populate this section."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(recentActivity.prefix(6)) { item in
                        activityRow(item)
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("main.quickActions"))
                .font(.headline)

            VStack(spacing: 10) {
                Button {
                    showAddExpense = true
                } label: {
                    quickActionCard(
                        icon: "plus.circle",
                        title: settings.language == .spanish ? "Agregar gasto" : "Add expense",
                        subtitle: settings.language == .spanish
                        ? "Registra una salida de dinero"
                        : "Record money going out"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showAddIncome = true
                } label: {
                    quickActionCard(
                        icon: "arrow.down.circle",
                        title: settings.language == .spanish ? "Registrar ingreso" : "Record income",
                        subtitle: settings.language == .spanish
                        ? "Agrega dinero que entra este mes"
                        : "Add money coming in this month"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ExpenseHistoryView(
                        expenses: $expenses,
                        onPersist: {
                            onPersistExpenses()
                            onRefreshInsight()
                            onEvaluateBudgetNotifications()
                        }
                    )
                    .environmentObject(settings)
                } label: {
                    quickActionCard(
                        icon: "calendar",
                        title: settings.t("main.historyTitle"),
                        subtitle: settings.t("main.historySubtitle")
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SettingsView()
                } label: {
                    quickActionCard(
                        icon: "gearshape",
                        title: settings.t("main.settingsTitle"),
                        subtitle: settings.t("main.settingsSubtitle")
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var avatarPickerButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let profileImageData,
                       let uiImage = UIImage(data: profileImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    BrandPalette.primary.opacity(0.18),
                                    BrandPalette.secondary.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            Text(userInitials)
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(BrandPalette.stroke, lineWidth: 1)
                )

                ZStack {
                    Circle()
                        .fill(BrandPalette.primary)

                    Image(systemName: "camera.fill")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                }
                .frame(width: 22, height: 22)
            }
        }
        .buttonStyle(.plain)
    }

    private var userInitials: String {
        let sourceName = effectiveDashboardName

        let components = sourceName
            .split(separator: " ")
            .prefix(2)

        let initials = components.compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "U" : initials.uppercased()
    }

    private func headerPill(icon: String, text: String) -> some View {
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

    private func summaryMetricCard(title: String, value: String, tone: DashboardTone, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(tone.accent)

                Spacer()

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            Text(value)
                .font(.title3.bold())
                .foregroundColor(tone.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(BrandPalette.surfaceRaised)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func compactFocusCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.primary)
                .font(.headline)

            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func upcomingPaymentRow(_ item: UpcomingRecurringItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.payment.category.color.opacity(0.18))
                    .frame(width: 46, height: 46)

                Image(systemName: item.payment.category.icon)
                    .foregroundColor(item.payment.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.payment.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(upcomingLabel(for: item))
                    .font(.caption)
                    .foregroundColor(item.isOverdue ? .red : .secondary)
            }

            Spacer()

            Text(settings.secureCurrency(item.payment.amount))
                .font(.subheadline.bold())
                .foregroundColor(item.isOverdue ? .red : .primary)
        }
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func activityRow(_ item: DashboardActivityItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.18))
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon)
                    .foregroundColor(item.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.kind == .income ? "+\(settings.secureCurrency(item.amount))" : "-\(settings.secureCurrency(item.amount))")
                    .font(.subheadline.bold())
                    .foregroundColor(item.kind == .income ? .green : .red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(settings.shortDateString(from: item.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func emptyDashboardCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func quickActionCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(BrandPalette.primary)
                .frame(width: 40, height: 40)
                .background(BrandPalette.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func upcomingLabel(for item: UpcomingRecurringItem) -> String {
        if item.isOverdue {
            return settings.language == .spanish
            ? "Vencido · \(settings.shortDateString(from: item.dueDate))"
            : "Overdue · \(settings.shortDateString(from: item.dueDate))"
        }

        return settings.language == .spanish
        ? "Próximo · \(settings.shortDateString(from: item.dueDate))"
        : "Upcoming · \(settings.shortDateString(from: item.dueDate))"
    }

    private func refreshSecondaryData() {
        debts = DataManager.shared.loadDebts(user: auth.currentUser)
        recurringPayments = DataManager.shared.loadRecurringPayments(user: auth.currentUser)
    }

    private var budgetNotSetText: String {
        settings.language == .spanish ? "Sin definir" : "Not set"
    }
}

private enum DashboardTone {
    case positive
    case negative
    case neutral
    case muted

    var accent: Color {
        switch self {
        case .positive:
            return .green
        case .negative:
            return .red
        case .neutral:
            return BrandPalette.primary
        case .muted:
            return .secondary
        }
    }
}

private struct UpcomingRecurringItem: Identifiable {
    let payment: RecurringPayment
    let dueDate: Date

    var id: UUID { payment.id }

    var isOverdue: Bool {
        dueDate < Calendar.current.startOfDay(for: Date())
    }
}

private struct DashboardActivityItem: Identifiable {
    enum Kind {
        case income
        case expense
    }

    let id: String
    let title: String
    let subtitle: String
    let amount: Double
    let date: Date
    let icon: String
    let tint: Color
    let kind: Kind
}

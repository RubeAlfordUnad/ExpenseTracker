import SwiftUI
import PhotosUI
import UIKit

struct MainTabView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var expenses: [Expense] = []
    @State private var showAddExpense = false

    @State private var monthlyBudget: MonthlyBudget = MonthlyBudget(amount: 0)

    @State private var showInsight = false
    @State private var currentInsight: InsightResult?

    @State private var showBudgetEditAlert = false
    @State private var budgetInput = ""

    @State private var showBudgetValidationAlert = false
    @State private var budgetValidationMessage = ""

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImageData: Data?

    @State private var hasLoadedInitialData = false
    @State private var hasShownInsightThisSession = false

    private let profileImageChangedNotification = Notification.Name("profileImageDidChange")
    private let notificationPreferencesDidChange = Notification.Name("notificationPreferencesDidChange")

    private var currentMonthExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }
    }

    private var totalSpent: Double {
        currentMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var remainingBudget: Double {
        monthlyBudget.amount - totalSpent
    }

    private var budgetProgress: Double {
        guard monthlyBudget.amount > 0 else { return 0 }
        return totalSpent / monthlyBudget.amount
    }

    private var safeBudgetProgress: Double {
        guard budgetProgress.isFinite else { return 0 }
        return min(max(budgetProgress, 0), 1)
    }

    private var recentExpenses: [Expense] {
        Array(
            currentMonthExpenses
                .sorted { $0.date > $1.date }
                .prefix(5)
        )
    }

    private var groupedByCategory: [Category: Double] {
        Dictionary(grouping: currentMonthExpenses, by: { $0.category })
            .mapValues { group in
                group.reduce(0) { $0 + $1.amount }
            }
    }

    private var topCategory: Category? {
        groupedByCategory.max { $0.value < $1.value }?.key
    }

    var body: some View {
        ZStack {
            TabView {
                NavigationStack {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            headerSection
                            budgetHeroCard
                            progressSection

                            if let topCategory {
                                topCategorySection(topCategory)
                            }

                            recentExpensesSection
                            quickActionsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .background(Color(.systemBackground))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(settings.t("main.logout")) {
                                auth.logout()
                            }
                            .accessibilityIdentifier("expenses.logout")
                        }

                        ToolbarItemGroup(placement: .topBarTrailing) {
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Image(systemName: "gearshape")
                            }

                            Button {
                                showAddExpense = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityIdentifier("expenses.add")
                        }
                    }
                    .sheet(isPresented: $showAddExpense) {
                        AddExpenseView { newExpense in
                            expenses.append(newExpense)
                            DataManager.shared.saveExpenses(expenses, user: auth.currentUser)
                            refreshInsight()
                            evaluateBudgetNotifications()
                        }
                        .environmentObject(settings)
                    }
                    .alert(settings.t("main.editBudgetTitle"), isPresented: $showBudgetEditAlert) {
                        TextField(settings.t("main.editBudgetPlaceholder"), text: $budgetInput)
                            .keyboardType(.decimalPad)

                        Button(settings.t("common.cancel"), role: .cancel) { }

                        Button(settings.t("common.save")) {
                            saveBudgetInline()
                        }
                    } message: {
                        Text(settings.t("main.editBudgetMessage"))
                    }
                    .alert(
                        settings.language == .spanish ? "Presupuesto inválido" : "Invalid budget",
                        isPresented: $showBudgetValidationAlert
                    ) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(budgetValidationMessage)
                    }
                    .onAppear {
                        guard !hasLoadedInitialData else { return }
                        hasLoadedInitialData = true
                        loadInitialData()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: profileImageChangedNotification)) { _ in
                        profileImageData = DataManager.shared.loadProfileImageData(user: auth.currentUser)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: notificationPreferencesDidChange)) { _ in
                        evaluateBudgetNotifications()
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            await loadSelectedPhoto(from: newItem)
                        }
                    }
                }
                .tabItem {
                    Label(settings.t("tab.expenses"), systemImage: "list.bullet")
                }

                DebtsView()
                    .tabItem {
                        Label(settings.t("tab.debts"), systemImage: "creditcard")
                    }

                RecurringPaymentsView()
                    .tabItem {
                        Label(settings.t("tab.recurring"), systemImage: "calendar.badge.clock")
                    }
            }

            if showInsight, let insight = currentInsight {
                InsightPopupView(
                    insight: insight,
                    show: $showInsight
                )
                .transition(.scale)
                .zIndex(2)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(greetingText)
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(settings.t("main.screenTitle"))
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
                    headerInfoPill(
                        icon: "calendar",
                        text: currentMonthLabel
                    )

                    headerInfoPill(
                        icon: "list.bullet",
                        text: settings.tr("main.movesCount", currentMonthExpenses.count)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    headerInfoPill(
                        icon: "calendar",
                        text: currentMonthLabel
                    )

                    headerInfoPill(
                        icon: "list.bullet",
                        text: settings.tr("main.movesCount", currentMonthExpenses.count)
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

    private var budgetHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.t("main.monthlySummary"))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(settings.formatCurrency(monthlyBudget.amount))
                        .font(.system(size: 32, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                Button {
                    budgetInput = String(Int(monthlyBudget.amount))
                    showBudgetEditAlert = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.headline)
                        .foregroundColor(BrandPalette.primary)
                        .frame(width: 42, height: 42)
                        .background(BrandPalette.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                budgetStatItem(
                    title: settings.t("main.totalSpent"),
                    value: settings.formatCurrency(totalSpent),
                    valueColor: .red
                )

                budgetStatItem(
                    title: settings.t("main.available"),
                    value: settings.formatCurrency(remainingBudget),
                    valueColor: remainingBudget < 0 ? .red : BrandPalette.primary
                )
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    BrandPalette.surface,
                    BrandPalette.primary.opacity(0.06),
                    BrandPalette.secondary.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(settings.t("main.progressTitle"))
                    .font(.headline)

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
                Text(settings.tr("main.progressRemaining", settings.formatCurrency(remainingBudget)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(settings.tr("main.progressExceeded", settings.formatCurrency(abs(remainingBudget))))
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }
        }
        .padding(18)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func topCategorySection(_ category: Category) -> some View {
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

            if let amount = groupedByCategory[category] {
                Text(settings.formatCurrency(amount))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(18)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("main.recentExpenses"))
                .font(.headline)

            if recentExpenses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.t("main.noExpensesTitle"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(settings.t("main.noExpensesSubtitle"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(recentExpenses) { expense in
                        recentExpenseRow(expense)
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
                NavigationLink {
                    ExpenseHistoryView(
                        expenses: $expenses,
                        onPersist: {
                            DataManager.shared.saveExpenses(expenses, user: auth.currentUser)
                            refreshInsight()
                            evaluateBudgetNotifications()
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

    private func loadInitialData() {
        expenses = DataManager.shared.loadExpenses(user: auth.currentUser)
        monthlyBudget = DataManager.shared.loadMonthlyBudget(user: auth.currentUser) ?? MonthlyBudget(amount: 0)
        profileImageData = DataManager.shared.loadProfileImageData(user: auth.currentUser)

        DataManager.shared.resetBudgetAlertStateIfNeeded(user: auth.currentUser)

        refreshInsight()
        presentInsightIfNeeded()
        evaluateBudgetNotifications()
    }

    private func refreshInsight() {
        currentInsight = SpendingInsightsManager.shared.analyzeSpending(
            expenses: expenses,
            monthlyBudget: monthlyBudget.amount,
            currencyCode: settings.effectiveCurrency.rawValue,
            locale: settings.appLocale,
            language: settings.language
        )
    }

    private func presentInsightIfNeeded() {
        guard !UITestResetManager.isRunningUITests else { return }
        guard !hasShownInsightThisSession else { return }
        guard currentInsight != nil else { return }

        hasShownInsightThisSession = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring()) {
                showInsight = true
            }
        }
    }

    private func evaluateBudgetNotifications() {
        let preferences = DataManager.shared.loadNotificationPreferences(user: auth.currentUser)

        guard preferences.budgetAlertsEnabled else {
            NotificationManager.shared.cancelBudgetNotifications()
            return
        }

        guard monthlyBudget.amount > 0 else {
            NotificationManager.shared.cancelBudgetNotifications()
            return
        }

        DataManager.shared.resetBudgetAlertStateIfNeeded(user: auth.currentUser)
        let state = DataManager.shared.loadBudgetAlertState(user: auth.currentUser)

        let monthlySpent = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let progress = monthlySpent / monthlyBudget.amount
        let threshold = preferences.budgetAlertThreshold

        if progress >= 1.0, !state.didSend100PercentAlert {
            NotificationManager.shared.notifyBudgetExceeded()
            DataManager.shared.markBudget100AlertSent(user: auth.currentUser)
            return
        }

        if progress >= threshold, !state.didSend80PercentAlert {
            NotificationManager.shared.notifyBudgetThresholdReached(progress: progress)
            DataManager.shared.markBudget80AlertSent(user: auth.currentUser)
        }
    }

    private func saveBudgetInline() {
        if let error = FormValidator.validateBudget(budgetInput) {
            budgetValidationMessage = error.message(language: settings.language)
            showBudgetValidationAlert = true
            return
        }

        guard let value = FormValidator.normalizedPositiveAmount(from: budgetInput) else {
            budgetValidationMessage = settings.language == .spanish
            ? "Ingresa un presupuesto válido mayor que cero."
            : "Enter a valid budget greater than zero."
            showBudgetValidationAlert = true
            return
        }

        monthlyBudget = MonthlyBudget(amount: value)
        DataManager.shared.saveMonthlyBudget(monthlyBudget, user: auth.currentUser)

        refreshInsight()
        evaluateBudgetNotifications()
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    profileImageData = data
                }
                DataManager.shared.saveProfileImageData(data, user: auth.currentUser)
                NotificationCenter.default.post(name: profileImageChangedNotification, object: nil)
            }
        } catch {
            AppLogger.debug("Error cargando foto: \(error.localizedDescription)")
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

    private var currentMonthLabel: String {
        settings.monthYearString(from: Date())
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let userName = auth.isUsingLocalMode
            ? (settings.language == .spanish ? "local" : "local")
            : auth.currentUser

        switch hour {
        case 5..<12:
            return settings.tr("main.goodMorning", userName)
        case 12..<19:
            return settings.tr("main.goodAfternoon", userName)
        default:
            return settings.tr("main.goodEvening", userName)
        }
    }

    private var headerSubtitle: String {
        if monthlyBudget.amount <= 0 {
            return settings.t("main.header.noBudget")
        } else if currentMonthExpenses.isEmpty {
            return settings.t("main.header.hasBudget")
        } else if remainingBudget < 0 {
            return settings.t("main.header.over")
        } else if budgetProgress >= 0.8 {
            return settings.t("main.header.near")
        } else {
            return settings.t("main.header.ok")
        }
    }

    private var userInitials: String {
        let sourceName = auth.isUsingLocalMode
            ? (settings.language == .spanish ? "Mi dispositivo" : "My Device")
            : auth.currentUser

        let components = sourceName
            .split(separator: " ")
            .prefix(2)

        let initials = components.compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "U" : initials.uppercased()
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

    private func headerInfoPill(icon: String, text: String) -> some View {
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

    private func budgetStatItem(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(valueColor)
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

    private func recentExpenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(expense.category.color.opacity(0.18))
                    .frame(width: 46, height: 46)

                Image(systemName: expense.category.icon)
                    .foregroundColor(expense.category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(expense.category.displayName(language: settings.language))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(settings.formatCurrency(expense.amount))
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

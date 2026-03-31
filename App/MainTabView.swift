import SwiftUI
import PhotosUI

struct MainTabView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var expenses: [Expense] = []
    @State private var incomes: [Income] = []

    @State private var showAddExpense = false
    @State private var showAddIncome = false

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

    @State private var showLockOverlay = false
    @State private var isAuthenticatingLock = false

    private let profileImageChangedNotification = Notification.Name("profileImageDidChange")
    private let notificationPreferencesDidChange = Notification.Name("notificationPreferencesDidChange")
    private let backupRestoreDidComplete = Notification.Name("backupRestoreDidComplete")

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

    var body: some View {
        ZStack {
            TabView {
                NavigationStack {
                    DashboardView(
                        expenses: $expenses,
                        incomes: $incomes,
                        monthlyBudget: $monthlyBudget,
                        selectedPhotoItem: $selectedPhotoItem,
                        profileImageData: $profileImageData,
                        showAddExpense: $showAddExpense,
                        showAddIncome: $showAddIncome,
                        onReloadHomeData: reloadHomeData,
                        onPersistExpenses: persistExpenses,
                        onRequestBudgetEdit: openBudgetEditor,
                        onRefreshInsight: refreshInsight,
                        onEvaluateBudgetNotifications: evaluateBudgetNotifications
                    )
                    .environmentObject(auth)
                    .environmentObject(settings)
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

                            Menu {
                                Button(addExpenseActionTitle) {
                                    showAddExpense = true
                                }

                                Button(addIncomeActionTitle) {
                                    showAddIncome = true
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                    .sheet(isPresented: $showAddExpense) {
                        AddExpenseView { newExpense in
                            expenses.append(newExpense)
                            persistExpenses()
                            refreshInsight()
                            evaluateBudgetNotifications()
                        }
                        .environmentObject(settings)
                    }
                    .sheet(isPresented: $showAddIncome) {
                        AddIncomeView { newIncome in
                            incomes.append(newIncome)
                            persistIncomes()
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
                        reloadHomeData()

                        guard !hasLoadedInitialData else { return }
                        hasLoadedInitialData = true
                        presentInsightIfNeeded()

                        if settings.biometricLockEnabled {
                            showLockOverlay = true
                            Task { await unlockAppIfNeeded() }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: profileImageChangedNotification)) { _ in
                        profileImageData = DataManager.shared.loadProfileImageData(user: auth.currentUser)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: notificationPreferencesDidChange)) { _ in
                        evaluateBudgetNotifications()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: backupRestoreDidComplete)) { _ in
                        reloadHomeData()
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            await loadSelectedPhoto(from: newItem)
                        }
                    }
                }
                .tabItem {
                    Label(homeTabTitle, systemImage: "house")
                }

                NavigationStack {
                    IncomesView(
                        incomes: $incomes,
                        onPersist: {
                            persistIncomes()
                        }
                    )
                    .environmentObject(settings)
                }
                .tabItem {
                    Label(incomesTabTitle, systemImage: "arrow.down.circle")
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
            .blur(radius: showLockOverlay ? 10 : 0)
            .disabled(showLockOverlay)
            .allowsHitTesting(!showLockOverlay)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onChange(of: settings.biometricLockEnabled) { _, enabled in
                if enabled {
                    showLockOverlay = true
                    Task { await unlockAppIfNeeded() }
                } else {
                    showLockOverlay = false
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

            if showLockOverlay {
                AppLockOverlayView(
                    isAuthenticating: isAuthenticatingLock,
                    onUnlock: {
                        Task { await unlockAppIfNeeded() }
                    }
                )
                .environmentObject(settings)
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLockOverlay)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            if settings.biometricLockEnabled {
                showLockOverlay = true
            }
        case .active:
            if settings.biometricLockEnabled, showLockOverlay {
                Task { await unlockAppIfNeeded() }
            }
        default:
            break
        }
    }

    private func unlockAppIfNeeded() async {
        guard settings.biometricLockEnabled else {
            await MainActor.run {
                showLockOverlay = false
            }
            return
        }

        guard !isAuthenticatingLock else { return }

        await MainActor.run {
            isAuthenticatingLock = true
        }

        let success = await AppLockService.shared.authenticate(language: settings.language)

        await MainActor.run {
            isAuthenticatingLock = false
            showLockOverlay = !success
        }
    }

    private func reloadHomeData() {
        expenses = DataManager.shared.loadExpenses(user: auth.currentUser)
        incomes = DataManager.shared.loadIncomes(user: auth.currentUser)
        monthlyBudget = DataManager.shared.loadMonthlyBudget(user: auth.currentUser) ?? MonthlyBudget(amount: 0)
        profileImageData = DataManager.shared.loadProfileImageData(user: auth.currentUser)

        DataManager.shared.resetBudgetAlertStateIfNeeded(user: auth.currentUser)

        refreshInsight()
        evaluateBudgetNotifications()
    }

    private func persistExpenses() {
        DataManager.shared.saveExpenses(expenses, user: auth.currentUser)
    }

    private func persistIncomes() {
        DataManager.shared.saveIncomes(incomes, user: auth.currentUser)
    }

    private func openBudgetEditor() {
        budgetInput = monthlyBudget.amount > 0 ? String(Int(monthlyBudget.amount)) : ""
        showBudgetEditAlert = true
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

    private var homeTabTitle: String {
        settings.language == .spanish ? "Inicio" : "Home"
    }

    private var incomesTabTitle: String {
        settings.language == .spanish ? "Ingresos" : "Incomes"
    }

    private var addExpenseActionTitle: String {
        settings.language == .spanish ? "Agregar gasto" : "Add expense"
    }

    private var addIncomeActionTitle: String {
        settings.language == .spanish ? "Agregar ingreso" : "Add income"
    }
}

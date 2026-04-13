import SwiftUI
import PhotosUI

struct MainTabView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var expenses: [Expense] = []
    @State private var incomes: [Income] = []
    @State private var moneyAccounts: [MoneyAccount] = []
    @State private var accountTransfers: [AccountTransfer] = []

    @State private var showAddExpense = false
    @State private var showAddIncome = false
    @State private var showAddTransfer = false

    @State private var monthlyBudget: MonthlyBudget = MonthlyBudget(amount: 0)

    @State private var showInsight = false
    @State private var currentInsight: InsightResult?

    @State private var showBudgetEditAlert = false
    @State private var showMoneyAccountsSheet = false
    @State private var moneyAccountsSheetStartsInCreateMode = false
    @State private var budgetInput = ""

    @State private var showBudgetValidationAlert = false
    @State private var budgetValidationMessage = ""

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var profileDisplayName: String = ""

    @State private var hasLoadedInitialData = false
    @State private var hasShownInsightThisSession = false

    @State private var showLockOverlay = false
    @State private var isAuthenticatingLock = false

    private let profileImageChangedNotification = Notification.Name("profileImageDidChange")
    private let notificationPreferencesDidChange = Notification.Name("notificationPreferencesDidChange")
    private let backupRestoreDidComplete = Notification.Name("backupRestoreDidComplete")
    private let profileDisplayNameChangedNotification = Notification.Name("profileDisplayNameDidChange")

    private let moneyAccountSync = MoneyAccountBalanceSync()
    private let moneyAccountTransferSync = MoneyAccountTransferSync()
    private let expenseFundingSync = ExpenseFundingSync()

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
                        moneyAccounts: $moneyAccounts,
                        transfers: $accountTransfers,
                        monthlyBudget: $monthlyBudget,
                        selectedPhotoItem: $selectedPhotoItem,
                        profileImageData: $profileImageData,
                        profileDisplayName: profileDisplayName,
                        onReloadHomeData: reloadHomeData,
                        onPersistExpenses: persistExpenses,
                        onPersistIncomes: persistIncomes,
                        onPersistMoneyAccounts: persistMoneyAccounts,
                        onPersistTransfers: persistAccountTransfers,
                        onRequestBudgetEdit: openBudgetEditor,
                        onRequestAccountsEdit: openMoneyAccountsEditor,
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
                            .accessibilityIdentifier("main.settings")

                            Menu {
                                Button {
                                    showAddExpense = true
                                } label: {
                                    Label {
                                        Text(addExpenseActionTitle)
                                    } icon: {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .red)
                                    }
                                }
                                .accessibilityIdentifier("main.add.expense")

                                Button {
                                    showAddIncome = true
                                } label: {
                                    Label {
                                        Text(addIncomeActionTitle)
                                    } icon: {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .green)
                                    }
                                }
                                .accessibilityIdentifier("main.add.income")

                                Button {
                                    showAddTransfer = true
                                } label: {
                                    Label {
                                        Text(addTransferActionTitle)
                                    } icon: {
                                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .blue)
                                    }
                                }
                                .accessibilityIdentifier("main.add.transfer")

                                Button {
                                    moneyAccountsSheetStartsInCreateMode = true
                                    showMoneyAccountsSheet = true
                                } label: {
                                    Label {
                                        Text(addMoneyAccountActionTitle)
                                    } icon: {
                                        Image(systemName: "building.columns.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .mint)
                                    }
                                }
                                .accessibilityIdentifier("main.add.moneyAccount")
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .accessibilityIdentifier("main.add.menu")
                        }
                    }
                    .sheet(isPresented: $showAddExpense) {
                        AddExpenseView(
                            moneyAccounts: moneyAccounts,
                            debts: DataManager.shared.loadDebts(user: auth.currentUser)
                        ) { newExpense in
                            expenses.append(newExpense)
                            expenses.sort { $0.date > $1.date }

                            var debts = DataManager.shared.loadDebts(user: auth.currentUser)
                            expenseFundingSync.applyNewExpense(newExpense, accounts: &moneyAccounts, debts: &debts)
                            DataManager.shared.saveDebts(debts, user: auth.currentUser)

                            persistExpenses()
                            persistMoneyAccounts()
                            refreshInsight()
                            evaluateBudgetNotifications()
                        }
                        .environmentObject(auth)
                        .environmentObject(settings)
                    }
                    .sheet(isPresented: $showAddIncome) {
                        AddIncomeView(moneyAccounts: moneyAccounts) { newIncome in
                            incomes.append(newIncome)
                            incomes.sort { $0.date > $1.date }

                            moneyAccountSync.applyNewIncome(newIncome, to: &moneyAccounts)

                            persistIncomes()
                            persistMoneyAccounts()
                            refreshInsight()
                        }
                        .environmentObject(auth)
                        .environmentObject(settings)
                    }
                    .sheet(isPresented: $showAddTransfer) {
                        NavigationStack {
                            AddTransferView(moneyAccounts: moneyAccounts) { newTransfer in
                                accountTransfers.append(newTransfer)
                                accountTransfers.sort { $0.date > $1.date }

                                moneyAccountTransferSync.applyNewTransfer(newTransfer, accounts: &moneyAccounts)

                                persistAccountTransfers()
                                persistMoneyAccounts()
                            }
                            .environmentObject(settings)
                        }
                    }
                    .sheet(isPresented: $showBudgetEditAlert) {
                        BudgetEditSheetView(initialValue: budgetInput) { newValue in
                            budgetInput = newValue
                            saveBudgetInline()
                        }
                        .environmentObject(settings)
                        .presentationDetents([.height(240)])
                        .presentationDragIndicator(.visible)
                    }
                    .sheet(isPresented: $showMoneyAccountsSheet, onDismiss: {
                        moneyAccountsSheetStartsInCreateMode = false
                    }) {
                        MoneyAccountsSheetView(
                            accounts: moneyAccounts,
                            expenses: expenses,
                            incomes: incomes,
                            transfers: accountTransfers,
                            startInCreateMode: moneyAccountsSheetStartsInCreateMode
                        ) { updatedAccounts in
                            moneyAccounts = updatedAccounts
                            persistMoneyAccounts()
                        }
                        .environmentObject(auth)
                        .environmentObject(settings)
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
                    .onReceive(NotificationCenter.default.publisher(for: profileDisplayNameChangedNotification)) { _ in
                        profileDisplayName = DataManager.shared.loadProfileDisplayName(user: auth.currentUser) ?? ""
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

                ExpenseHistoryView(
                    expenses: $expenses,
                    incomes: $incomes,
                    moneyAccounts: $moneyAccounts,
                    onPersistExpenses: {
                        persistExpenses()
                        refreshInsight()
                        evaluateBudgetNotifications()
                    },
                    onPersistIncomes: {
                        persistIncomes()
                        refreshInsight()
                    },
                    onPersistMoneyAccounts: {
                        persistMoneyAccounts()
                    }
                )
                .environmentObject(auth)
                .environmentObject(settings)
                .tabItem {
                    Label(historyTabTitle, systemImage: "clock.arrow.circlepath")
                }

                NavigationStack {
                    TransfersView(
                        transfers: $accountTransfers,
                        moneyAccounts: $moneyAccounts,
                        onPersistTransfers: {
                            persistAccountTransfers()
                        },
                        onPersistMoneyAccounts: {
                            persistMoneyAccounts()
                        }
                    )
                    .environmentObject(settings)
                }
                .tabItem {
                    Label(transferTabTitle, systemImage: "arrow.left.arrow.right")
                }

                DebtsView(
                    moneyAccounts: moneyAccounts,
                    onRegisterCardExpense: { newExpense in
                        expenses.append(newExpense)
                        expenses.sort { $0.date > $1.date }

                        var debts = DataManager.shared.loadDebts(user: auth.currentUser)
                        expenseFundingSync.applyNewExpense(newExpense, accounts: &moneyAccounts, debts: &debts)
                        DataManager.shared.saveDebts(debts, user: auth.currentUser)

                        persistExpenses()
                        persistMoneyAccounts()
                        refreshInsight()
                        evaluateBudgetNotifications()
                    },
                    onRegisterDebtPayment: { paymentAmount, moneyAccountId in
                        moneyAccountSync.applyDebtPayment(
                            amount: paymentAmount,
                            from: moneyAccountId,
                            to: &moneyAccounts
                        )
                        persistMoneyAccounts()
                    }
                )
                .tabItem {
                    Label(settings.t("tab.debts"), systemImage: "creditcard")
                }
                
                RecurringPaymentsView(
                    moneyAccounts: moneyAccounts,
                    onRegisterPaidRecurringExpense: { payment, moneyAccountId, expenseId in
                        registerRecurringPaymentAsExpense(
                            payment,
                            from: moneyAccountId,
                            expenseId: expenseId
                        )
                    },
                    onDeletePaidRecurringExpense: { expenseId in
                        deleteRecurringPaymentExpense(withId: expenseId)
                    }
                )
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
        moneyAccounts = DataManager.shared.loadMoneyAccounts(user: auth.currentUser)
        accountTransfers = DataManager.shared.loadAccountTransfers(user: auth.currentUser)
        monthlyBudget = DataManager.shared.loadMonthlyBudget(user: auth.currentUser) ?? MonthlyBudget(amount: 0)
        profileImageData = DataManager.shared.loadProfileImageData(user: auth.currentUser)
        profileDisplayName = DataManager.shared.loadProfileDisplayName(user: auth.currentUser) ?? ""

        DataManager.shared.resetBudgetAlertStateIfNeeded(user: auth.currentUser)

        refreshInsight()
        evaluateBudgetNotifications()
    }

    private func persistAccountTransfers() {
        DataManager.shared.saveAccountTransfers(accountTransfers, user: auth.currentUser)
    }

    private var transferTabTitle: String {
        settings.language == .spanish ? "Transferencias" : "Transfers"
    }

    private var addTransferActionTitle: String {
        settings.language == .spanish ? "Hacer transferencia" : "Make transfer"
    }
    
    private var addMoneyAccountActionTitle: String {
        settings.language == .spanish ? "Crear cuenta" : "Create account"
    }
    
    private func persistExpenses() {
        DataManager.shared.saveExpenses(expenses, user: auth.currentUser)
    }

    private func persistIncomes() {
        DataManager.shared.saveIncomes(incomes, user: auth.currentUser)
    }

    private func persistMoneyAccounts() {
        DataManager.shared.saveMoneyAccounts(moneyAccounts, user: auth.currentUser)
    }
    
    private func registerRecurringPaymentAsExpense(
        _ payment: RecurringPayment,
        from moneyAccountId: UUID,
        expenseId: UUID
    ) {
        let generatedExpense = Expense(
            id: expenseId,
            title: payment.title,
            amount: payment.amount,
            date: Date(),
            category: payment.category.expenseCategory(),
            customCategoryName: payment.normalizedCustomCategoryName,
            moneyAccountId: moneyAccountId,
            comment: settings.language == .spanish
                ? "Generado desde pagos fijos"
                : "Generated from recurring payments"
        )

        expenses.append(generatedExpense)
        expenses.sort { $0.date > $1.date }

        var debts = DataManager.shared.loadDebts(user: auth.currentUser)
        expenseFundingSync.applyNewExpense(generatedExpense, accounts: &moneyAccounts, debts: &debts)
        DataManager.shared.saveDebts(debts, user: auth.currentUser)

        persistExpenses()
        persistMoneyAccounts()
        refreshInsight()
        evaluateBudgetNotifications()
    }

    private func deleteRecurringPaymentExpense(withId expenseId: UUID) {
        guard let expense = expenses.first(where: { $0.id == expenseId }) else { return }

        var debts = DataManager.shared.loadDebts(user: auth.currentUser)
        expenseFundingSync.applyExpenseDeletion(expense, accounts: &moneyAccounts, debts: &debts)
        DataManager.shared.saveDebts(debts, user: auth.currentUser)

        expenses.removeAll { $0.id == expenseId }

        persistExpenses()
        persistMoneyAccounts()
        refreshInsight()
        evaluateBudgetNotifications()
    }

    private func openBudgetEditor() {
        if monthlyBudget.amount > 0 {
            budgetInput = MoneyInputFormatter.formatRawForDisplay(
                String(monthlyBudget.amount),
                locale: settings.appLocale,
                maximumFractionDigits: 2
            )
        } else {
            budgetInput = ""
        }

        showBudgetEditAlert = true
    }

    private func openMoneyAccountsEditor() {
        moneyAccountsSheetStartsInCreateMode = false
        showMoneyAccountsSheet = true
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
        let trimmedInput = budgetInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if let error = FormValidator.validateBudget(trimmedInput) {
            budgetValidationMessage = error.message(language: settings.language)
            showBudgetValidationAlert = true
            return
        }

        guard let value = FormValidator.normalizedPositiveAmount(from: trimmedInput) else {
            budgetValidationMessage = settings.language == .spanish
            ? "Ingresa un presupuesto válido mayor que cero."
            : "Enter a valid budget greater than zero."
            showBudgetValidationAlert = true
            return
        }

        monthlyBudget = MonthlyBudget(amount: value)
        DataManager.shared.saveMonthlyBudget(monthlyBudget, user: auth.currentUser)

        showBudgetEditAlert = false

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

    private var historyTabTitle: String {
        settings.language == .spanish ? "Historial" : "History"
    }

    private var addExpenseActionTitle: String {
        settings.language == .spanish ? "Agregar gasto" : "Add expense"
    }

    private var addIncomeActionTitle: String {
        settings.language == .spanish ? "Agregar ingreso" : "Add income"
    }
}

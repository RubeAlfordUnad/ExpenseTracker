import Foundation
import SwiftData

final class DataManager {

    static let shared = DataManager()

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Keys

    private let financialMigrationPrefix = "swiftDataFinancialMigration_v1_"

    private func profileImageKey(for user: String) -> String {
        "profileImage_\(user)"
    }

    private func sanitizedFileName(for user: String) -> String {
        user.replacingOccurrences(of: #"[^A-Za-z0-9._-]"#, with: "_", options: .regularExpression)
    }

    private func profileImagesDirectoryURL() -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseURL.appendingPathComponent("ProfileImages", isDirectory: true)
    }

    private func profileImageFileURL(for user: String) -> URL {
        profileImagesDirectoryURL()
            .appendingPathComponent(sanitizedFileName(for: user))
            .appendingPathExtension("bin")
    }

    private func expensesKey(for user: String) -> String {
        "expenses_\(user)"
    }

    private func debtsKey(for user: String) -> String {
        "debts_\(user)"
    }

    private func recurringPaymentsKey(for user: String) -> String {
        "recurringPayments_\(user)"
    }

    private func budgetKey(for user: String) -> String {
        "monthlyBudget_\(user)"
    }

    private func notificationPreferencesKey(for user: String) -> String {
        "notificationPreferences_\(user)"
    }

    private func budgetAlertStateKey(for user: String) -> String {
        "budgetAlertState_\(user)"
    }

    private func financialMigrationFlagKey(for user: String) -> String {
        "\(financialMigrationPrefix)\(user)"
    }

    // MARK: - Expenses

    func saveExpenses(_ expenses: [Expense], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            legacySave(expenses, forKey: expensesKey(for: cleanUser))
            return
        }

        do {
            let context = makeContext()
            try replaceExpenses(expenses, user: cleanUser, context: context)
            try context.save()
        } catch {
            AppLogger.debug("Error guardando gastos en SwiftData: \(error)")
            legacySave(expenses, forKey: expensesKey(for: cleanUser))
        }
    }

    func loadExpenses(user: String) -> [Expense] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            return legacyLoad([Expense].self, forKey: expensesKey(for: cleanUser)) ?? []
        }

        do {
            let context = makeContext()
            let targetUser = cleanUser

            let descriptor = FetchDescriptor<StoredExpense>(
                predicate: #Predicate { $0.user == targetUser },
                sortBy: [SortDescriptor(\StoredExpense.date, order: .reverse)]
            )

            return try context.fetch(descriptor).map { $0.toExpense() }
        } catch {
            AppLogger.debug("Error cargando gastos desde SwiftData: \(error)")
            return legacyLoad([Expense].self, forKey: expensesKey(for: cleanUser)) ?? []
        }
    }

    // MARK: - Debts

    func saveDebts(_ debts: [Debt], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            legacySave(debts, forKey: debtsKey(for: cleanUser))
            return
        }

        do {
            let context = makeContext()
            try replaceDebts(debts, user: cleanUser, context: context)
            try context.save()
        } catch {
            AppLogger.debug("Error guardando deudas en SwiftData: \(error)")
            legacySave(debts, forKey: debtsKey(for: cleanUser))
        }
    }

    func loadDebts(user: String) -> [Debt] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            return legacyLoad([Debt].self, forKey: debtsKey(for: cleanUser)) ?? []
        }

        do {
            let context = makeContext()
            let targetUser = cleanUser

            let descriptor = FetchDescriptor<StoredDebt>(
                predicate: #Predicate { $0.user == targetUser },
                sortBy: [SortDescriptor(\StoredDebt.cardName)]
            )

            return try context.fetch(descriptor).map { $0.toDebt() }
        } catch {
            AppLogger.debug("Error cargando deudas desde SwiftData: \(error)")
            return legacyLoad([Debt].self, forKey: debtsKey(for: cleanUser)) ?? []
        }
    }

    // MARK: - Recurring Payments

    func saveRecurringPayments(_ payments: [RecurringPayment], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            legacySave(payments, forKey: recurringPaymentsKey(for: cleanUser))
            return
        }

        do {
            let context = makeContext()
            try replaceRecurringPayments(payments, user: cleanUser, context: context)
            try context.save()
        } catch {
            AppLogger.debug("Error guardando pagos recurrentes en SwiftData: \(error)")
            legacySave(payments, forKey: recurringPaymentsKey(for: cleanUser))
        }
    }

    func loadRecurringPayments(user: String) -> [RecurringPayment] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            return legacyLoad([RecurringPayment].self, forKey: recurringPaymentsKey(for: cleanUser)) ?? []
        }

        do {
            let context = makeContext()
            let targetUser = cleanUser

            let descriptor = FetchDescriptor<StoredRecurringPayment>(
                predicate: #Predicate { $0.user == targetUser },
                sortBy: [SortDescriptor(\StoredRecurringPayment.dueDay)]
            )

            return try context.fetch(descriptor).map { $0.toRecurringPayment() }
        } catch {
            AppLogger.debug("Error cargando pagos recurrentes desde SwiftData: \(error)")
            return legacyLoad([RecurringPayment].self, forKey: recurringPaymentsKey(for: cleanUser)) ?? []
        }
    }

    // MARK: - Monthly Budget

    func saveMonthlyBudget(_ budget: MonthlyBudget, user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            legacySave(budget, forKey: budgetKey(for: cleanUser))
            return
        }

        do {
            let context = makeContext()
            try upsertMonthlyBudget(budget, user: cleanUser, context: context)
            try context.save()
        } catch {
            AppLogger.debug("Error guardando presupuesto en SwiftData: \(error)")
            legacySave(budget, forKey: budgetKey(for: cleanUser))
        }
    }

    func loadMonthlyBudget(user: String) -> MonthlyBudget? {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return nil }

        guard migrateFinancialDataIfNeeded(for: cleanUser) else {
            return legacyLoad(MonthlyBudget.self, forKey: budgetKey(for: cleanUser))
        }

        do {
            let context = makeContext()
            let targetUser = cleanUser

            var descriptor = FetchDescriptor<StoredMonthlyBudget>(
                predicate: #Predicate { $0.user == targetUser }
            )
            descriptor.fetchLimit = 1

            return try context.fetch(descriptor).first?.toMonthlyBudget()
        } catch {
            AppLogger.debug("Error cargando presupuesto desde SwiftData: \(error)")
            return legacyLoad(MonthlyBudget.self, forKey: budgetKey(for: cleanUser))
        }
    }

    // MARK: - Notification Preferences

    func saveNotificationPreferences(_ preferences: NotificationPreferences, user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }
        legacySave(preferences, forKey: notificationPreferencesKey(for: cleanUser))
    }

    func loadNotificationPreferences(user: String) -> NotificationPreferences {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return NotificationPreferences() }

        return legacyLoad(NotificationPreferences.self, forKey: notificationPreferencesKey(for: cleanUser))
        ?? NotificationPreferences()
    }

    // MARK: - Budget Alert State

    func saveBudgetAlertState(_ state: BudgetAlertState, user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }
        legacySave(state, forKey: budgetAlertStateKey(for: cleanUser))
    }

    func loadBudgetAlertState(user: String) -> BudgetAlertState {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else {
            return BudgetAlertState(monthIdentifier: currentMonthIdentifier())
        }

        return legacyLoad(BudgetAlertState.self, forKey: budgetAlertStateKey(for: cleanUser))
        ?? BudgetAlertState(monthIdentifier: currentMonthIdentifier())
    }

    func resetBudgetAlertStateIfNeeded(user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        let currentMonth = currentMonthIdentifier()
        var state = loadBudgetAlertState(user: cleanUser)

        if state.monthIdentifier != currentMonth {
            state = BudgetAlertState(monthIdentifier: currentMonth)
            saveBudgetAlertState(state, user: cleanUser)
        }
    }

    func markBudget80AlertSent(user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        var state = loadBudgetAlertState(user: cleanUser)
        state.monthIdentifier = currentMonthIdentifier()
        state.didSend80PercentAlert = true
        saveBudgetAlertState(state, user: cleanUser)
    }

    func markBudget100AlertSent(user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        var state = loadBudgetAlertState(user: cleanUser)
        state.monthIdentifier = currentMonthIdentifier()
        state.didSend100PercentAlert = true
        saveBudgetAlertState(state, user: cleanUser)
    }

    // MARK: - Profile Image

    func saveProfileImageData(_ data: Data?, user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        let legacyKey = profileImageKey(for: cleanUser)
        let fileURL = profileImageFileURL(for: cleanUser)

        if let data {
            do {
                try fileManager.createDirectory(
                    at: profileImagesDirectoryURL(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try data.write(to: fileURL, options: .atomic)
                UserDefaults.standard.removeObject(forKey: legacyKey)
            } catch {
                AppLogger.debug("Error guardando imagen de perfil en archivo: \(error)")
                UserDefaults.standard.set(data, forKey: legacyKey)
            }
        } else {
            try? fileManager.removeItem(at: fileURL)
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    func loadProfileImageData(user: String) -> Data? {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return nil }

        let fileURL = profileImageFileURL(for: cleanUser)

        if let data = try? Data(contentsOf: fileURL) {
            return data
        }

        let legacyKey = profileImageKey(for: cleanUser)

        if let legacyData = UserDefaults.standard.data(forKey: legacyKey) {
            saveProfileImageData(legacyData, user: cleanUser)
            return legacyData
        }

        return nil
    }

    // MARK: - Account Deletion

    func deleteAllLocalData(for user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        do {
            let context = makeContext()
            try deleteStoredExpenses(user: cleanUser, context: context)
            try deleteStoredDebts(user: cleanUser, context: context)
            try deleteStoredRecurringPayments(user: cleanUser, context: context)
            try deleteStoredMonthlyBudget(user: cleanUser, context: context)
            try context.save()
        } catch {
            AppLogger.debug("Error borrando datos financieros de SwiftData: \(error)")
        }

        try? fileManager.removeItem(at: profileImageFileURL(for: cleanUser))

        let defaults = UserDefaults.standard
        let keys = [
            profileImageKey(for: cleanUser),
            expensesKey(for: cleanUser),
            debtsKey(for: cleanUser),
            recurringPaymentsKey(for: cleanUser),
            budgetKey(for: cleanUser),
            notificationPreferencesKey(for: cleanUser),
            budgetAlertStateKey(for: cleanUser),
            financialMigrationFlagKey(for: cleanUser)
        ]

        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - SwiftData Migration

    @discardableResult
    private func migrateFinancialDataIfNeeded(for user: String) -> Bool {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return false }

        let defaults = UserDefaults.standard
        let migrationKey = financialMigrationFlagKey(for: cleanUser)

        if defaults.bool(forKey: migrationKey) {
            return true
        }

        do {
            let context = makeContext()

            if let legacyExpenses: [Expense] = legacyLoad([Expense].self, forKey: expensesKey(for: cleanUser)) {
                try replaceExpenses(legacyExpenses, user: cleanUser, context: context)
            }

            if let legacyDebts: [Debt] = legacyLoad([Debt].self, forKey: debtsKey(for: cleanUser)) {
                try replaceDebts(legacyDebts, user: cleanUser, context: context)
            }

            if let legacyPayments: [RecurringPayment] = legacyLoad([RecurringPayment].self, forKey: recurringPaymentsKey(for: cleanUser)) {
                try replaceRecurringPayments(legacyPayments, user: cleanUser, context: context)
            }

            if let legacyBudget: MonthlyBudget = legacyLoad(MonthlyBudget.self, forKey: budgetKey(for: cleanUser)) {
                try upsertMonthlyBudget(legacyBudget, user: cleanUser, context: context)
            }

            try context.save()

            defaults.removeObject(forKey: expensesKey(for: cleanUser))
            defaults.removeObject(forKey: debtsKey(for: cleanUser))
            defaults.removeObject(forKey: recurringPaymentsKey(for: cleanUser))
            defaults.removeObject(forKey: budgetKey(for: cleanUser))
            defaults.set(true, forKey: migrationKey)

            return true
        } catch {
            AppLogger.debug("Error migrando datos financieros a SwiftData para \(cleanUser): \(error)")
            return false
        }
    }

    // MARK: - SwiftData Helpers

    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController.shared.container)
    }

    private func replaceExpenses(_ expenses: [Expense], user: String, context: ModelContext) throws {
        try deleteStoredExpenses(user: user, context: context)

        for expense in expenses {
            context.insert(StoredExpense(expense: expense, user: user))
        }
    }

    private func replaceDebts(_ debts: [Debt], user: String, context: ModelContext) throws {
        try deleteStoredDebts(user: user, context: context)

        for debt in debts {
            context.insert(StoredDebt(debt: debt, user: user))
        }
    }

    private func replaceRecurringPayments(_ payments: [RecurringPayment], user: String, context: ModelContext) throws {
        try deleteStoredRecurringPayments(user: user, context: context)

        for payment in payments {
            context.insert(StoredRecurringPayment(payment: payment, user: user))
        }
    }

    private func upsertMonthlyBudget(_ budget: MonthlyBudget, user: String, context: ModelContext) throws {
        let targetUser = user
        var descriptor = FetchDescriptor<StoredMonthlyBudget>(
            predicate: #Predicate { $0.user == targetUser }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.amount = budget.amount
        } else {
            context.insert(StoredMonthlyBudget(user: user, amount: budget.amount))
        }
    }

    private func deleteStoredExpenses(user: String, context: ModelContext) throws {
        let targetUser = user
        let descriptor = FetchDescriptor<StoredExpense>(
            predicate: #Predicate { $0.user == targetUser }
        )

        try context.fetch(descriptor).forEach { context.delete($0) }
    }

    private func deleteStoredDebts(user: String, context: ModelContext) throws {
        let targetUser = user
        let descriptor = FetchDescriptor<StoredDebt>(
            predicate: #Predicate { $0.user == targetUser }
        )

        try context.fetch(descriptor).forEach { context.delete($0) }
    }

    private func deleteStoredRecurringPayments(user: String, context: ModelContext) throws {
        let targetUser = user
        let descriptor = FetchDescriptor<StoredRecurringPayment>(
            predicate: #Predicate { $0.user == targetUser }
        )

        try context.fetch(descriptor).forEach { context.delete($0) }
    }

    private func deleteStoredMonthlyBudget(user: String, context: ModelContext) throws {
        let targetUser = user
        let descriptor = FetchDescriptor<StoredMonthlyBudget>(
            predicate: #Predicate { $0.user == targetUser }
        )

        try context.fetch(descriptor).forEach { context.delete($0) }
    }

    // MARK: - Legacy Storage Helpers

    private func legacySave<T: Codable>(_ value: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func legacyLoad<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Shared Helpers

    private func sanitizeUser(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentMonthIdentifier() -> String {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return "\(year)-\(month)"
    }
}

import Foundation
import UniformTypeIdentifiers

struct AppBackupSnapshot: Codable {
    let version: Int
    let exportedAt: Date
    let sourceUser: String

    let expenses: [Expense]
    let incomes: [Income]
    let debts: [Debt]
    let recurringPayments: [RecurringPayment]
    let moneyAccounts: [MoneyAccount]
    let accountTransfers: [AccountTransfer]
    let monthlyBudget: MonthlyBudget?
    let notificationPreferences: NotificationPreferences
    let expenseCustomCategories: [CustomExpenseCategory]
    let incomeCustomCategories: [CustomIncomeCategory]
    let moneyAccountCustomCategories: [CustomMoneyAccountCategory]
    let recurringPaymentCustomCategories: [CustomRecurringPaymentCategory]
    let profileImageData: Data?
    let profileDisplayName: String?

    enum CodingKeys: String, CodingKey {
        case version
        case exportedAt
        case sourceUser
        case expenses
        case incomes
        case debts
        case recurringPayments
        case moneyAccounts
        case accountTransfers
        case monthlyBudget
        case notificationPreferences
        case profileImageData
        case profileDisplayName
        case expenseCustomCategories
        case incomeCustomCategories
        case moneyAccountCustomCategories
        case recurringPaymentCustomCategories
    }

    init(
        version: Int,
        exportedAt: Date,
        sourceUser: String,
        expenses: [Expense],
        incomes: [Income],
        debts: [Debt],
        recurringPayments: [RecurringPayment],
        moneyAccounts: [MoneyAccount] = [],
        accountTransfers: [AccountTransfer] = [],
        monthlyBudget: MonthlyBudget?,
        notificationPreferences: NotificationPreferences,
        expenseCustomCategories: [CustomExpenseCategory] = [],
        incomeCustomCategories: [CustomIncomeCategory] = [],
        moneyAccountCustomCategories: [CustomMoneyAccountCategory] = [],
        recurringPaymentCustomCategories: [CustomRecurringPaymentCategory] = [],
        profileImageData: Data?,
        profileDisplayName: String?
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.sourceUser = sourceUser
        self.expenses = expenses
        self.incomes = incomes
        self.debts = debts
        self.recurringPayments = recurringPayments
        self.moneyAccounts = moneyAccounts
        self.accountTransfers = accountTransfers
        self.monthlyBudget = monthlyBudget
        self.notificationPreferences = notificationPreferences
        self.expenseCustomCategories = expenseCustomCategories
        self.incomeCustomCategories = incomeCustomCategories
        self.moneyAccountCustomCategories = moneyAccountCustomCategories
        self.recurringPaymentCustomCategories = recurringPaymentCustomCategories
        self.profileImageData = profileImageData
        self.profileDisplayName = profileDisplayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        sourceUser = try container.decode(String.self, forKey: .sourceUser)
        expenses = try container.decodeIfPresent([Expense].self, forKey: .expenses) ?? []
        incomes = try container.decodeIfPresent([Income].self, forKey: .incomes) ?? []
        debts = try container.decodeIfPresent([Debt].self, forKey: .debts) ?? []
        recurringPayments = try container.decodeIfPresent([RecurringPayment].self, forKey: .recurringPayments) ?? []
        moneyAccounts = try container.decodeIfPresent([MoneyAccount].self, forKey: .moneyAccounts) ?? []
        accountTransfers = try container.decodeIfPresent([AccountTransfer].self, forKey: .accountTransfers) ?? []
        monthlyBudget = try container.decodeIfPresent(MonthlyBudget.self, forKey: .monthlyBudget)
        notificationPreferences = try container.decodeIfPresent(NotificationPreferences.self, forKey: .notificationPreferences) ?? NotificationPreferences()
        expenseCustomCategories = try container.decodeIfPresent([CustomExpenseCategory].self, forKey: .expenseCustomCategories) ?? []
        incomeCustomCategories = try container.decodeIfPresent([CustomIncomeCategory].self, forKey: .incomeCustomCategories) ?? []
        moneyAccountCustomCategories = try container.decodeIfPresent([CustomMoneyAccountCategory].self, forKey: .moneyAccountCustomCategories) ?? []
        profileImageData = try container.decodeIfPresent(Data.self, forKey: .profileImageData)
        profileDisplayName = try container.decodeIfPresent(String.self, forKey: .profileDisplayName)
        recurringPaymentCustomCategories = try container.decodeIfPresent([CustomRecurringPaymentCategory].self, forKey: .recurringPaymentCustomCategories) ?? []
    }
}

struct AppBackupSummary {
    let expensesCount: Int
    let incomesCount: Int
    let debtsCount: Int
    let recurringPaymentsCount: Int
    let moneyAccountsCount: Int
    let accountTransfersCount: Int
    let hasBudget: Bool
    let hasProfileImage: Bool
}

struct AppBackupTransferPayload {
    let data: Data
    let contentType: UTType
    let fileName: String
}

enum AppBackupError: LocalizedError {
    case emptyUser
    case encodingFailed
    case decodingFailed
    case emptyData
    case unsupportedVersion
    case tooLargeFile
    case invalidSnapshot

    var errorDescription: String? {
        switch self {
        case .emptyUser:
            return "No se encontró un usuario activo para exportar o restaurar."
        case .encodingFailed:
            return "No se pudo generar el respaldo."
        case .decodingFailed:
            return "No se pudo leer el archivo de respaldo."
        case .emptyData:
            return "El archivo seleccionado está vacío."
        case .unsupportedVersion:
            return "Este respaldo usa una versión que la app no soporta todavía."
        case .tooLargeFile:
            return "El archivo de respaldo es demasiado grande para importarse de forma segura."
        case .invalidSnapshot:
            return "El respaldo no es válido o contiene datos inconsistentes."
        }
    }
}

final class AppBackupService {
    private let currentVersion = 4
    private let maximumBackupBytes = 12 * 1024 * 1024
    private let maximumRecordsPerCollection = 100_000
    private let maximumSourceUserLength = 80
    private let maximumProfileDisplayNameLength = 60
    private let maximumProfileImageBytes = 5 * 1024 * 1024
    private let identityRemapper = AppBackupIdentityRemapper()
    private let referenceSanitizer = AppBackupReferenceSanitizer()
    private let financialStateSanitizer = AppBackupFinancialStateSanitizer()

    func currentSnapshot(for user: String) throws -> AppBackupSnapshot {
        let cleanUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty else {
            throw AppBackupError.emptyUser
        }

        let rawSnapshot = AppBackupSnapshot(
            version: currentVersion,
            exportedAt: Date(),
            sourceUser: cleanUser,
            expenses: DataManager.shared.loadExpenses(user: cleanUser),
            incomes: DataManager.shared.loadIncomes(user: cleanUser),
            debts: DataManager.shared.loadDebts(user: cleanUser),
            recurringPayments: DataManager.shared.loadRecurringPayments(user: cleanUser),
            moneyAccounts: DataManager.shared.loadMoneyAccounts(user: cleanUser),
            accountTransfers: DataManager.shared.loadAccountTransfers(user: cleanUser),
            monthlyBudget: DataManager.shared.loadMonthlyBudget(user: cleanUser),
            notificationPreferences: DataManager.shared.loadNotificationPreferences(user: cleanUser),
            expenseCustomCategories: TransactionCustomizationStore.shared.loadExpenseCustomCategories(user: cleanUser),
            incomeCustomCategories: TransactionCustomizationStore.shared.loadIncomeCustomCategories(user: cleanUser),
            moneyAccountCustomCategories: TransactionCustomizationStore.shared.loadMoneyAccountCustomCategories(user: cleanUser),
            recurringPaymentCustomCategories: TransactionCustomizationStore.shared.loadRecurringPaymentCustomCategories(user: cleanUser),
            profileImageData: DataManager.shared.loadProfileImageData(user: cleanUser),
            profileDisplayName: DataManager.shared.loadProfileDisplayName(user: cleanUser)
        )

        return try validatedSnapshot(rawSnapshot)
    }

    func currentSummary(for user: String) -> AppBackupSummary {
        let cleanUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty else {
            return AppBackupSummary(
                expensesCount: 0,
                incomesCount: 0,
                debtsCount: 0,
                recurringPaymentsCount: 0,
                moneyAccountsCount: 0,
                accountTransfersCount: 0,
                hasBudget: false,
                hasProfileImage: false
            )
        }

        return AppBackupSummary(
            expensesCount: DataManager.shared.loadExpenses(user: cleanUser).count,
            incomesCount: DataManager.shared.loadIncomes(user: cleanUser).count,
            debtsCount: DataManager.shared.loadDebts(user: cleanUser).count,
            recurringPaymentsCount: DataManager.shared.loadRecurringPayments(user: cleanUser).count,
            moneyAccountsCount: DataManager.shared.loadMoneyAccounts(user: cleanUser).count,
            accountTransfersCount: DataManager.shared.loadAccountTransfers(user: cleanUser).count,
            hasBudget: normalizedBudget(DataManager.shared.loadMonthlyBudget(user: cleanUser)) != nil,
            hasProfileImage: sanitizedProfileImageData(DataManager.shared.loadProfileImageData(user: cleanUser)) != nil
        )
    }

    func summary(for snapshot: AppBackupSnapshot) -> AppBackupSummary {
        AppBackupSummary(
            expensesCount: snapshot.expenses.count,
            incomesCount: snapshot.incomes.count,
            debtsCount: snapshot.debts.count,
            recurringPaymentsCount: snapshot.recurringPayments.count,
            moneyAccountsCount: snapshot.moneyAccounts.count,
            accountTransfersCount: snapshot.accountTransfers.count,
            hasBudget: normalizedBudget(snapshot.monthlyBudget) != nil,
            hasProfileImage: sanitizedProfileImageData(snapshot.profileImageData) != nil
        )
    }

    func makeExport(for user: String) throws -> AppBackupTransferPayload {
        let snapshot = try currentSnapshot(for: user)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            return AppBackupTransferPayload(
                data: data,
                contentType: .json,
                fileName: fileName()
            )
        } catch {
            throw AppBackupError.encodingFailed
        }
    }

    func importSnapshot(from data: Data) throws -> AppBackupSnapshot {
        let cleanedData = removeUTF8BOMIfNeeded(from: data)

        guard !cleanedData.isEmpty else {
            throw AppBackupError.emptyData
        }

        guard cleanedData.count <= maximumBackupBytes else {
            throw AppBackupError.tooLargeFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let snapshot = try decoder.decode(AppBackupSnapshot.self, from: cleanedData)
            return try validatedSnapshot(snapshot)
        } catch let error as AppBackupError {
            throw error
        } catch {
            throw AppBackupError.decodingFailed
        }
    }

    func restore(_ snapshot: AppBackupSnapshot, to user: String) throws {
        let cleanUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty else {
            throw AppBackupError.emptyUser
        }

        let validated = try validatedSnapshot(snapshot)
        let remapped = try validatedSnapshot(identityRemapper.remap(validated))

        DataManager.shared.saveExpenses(remapped.expenses, user: cleanUser)
        DataManager.shared.saveIncomes(remapped.incomes, user: cleanUser)
        DataManager.shared.saveDebts(remapped.debts, user: cleanUser)
        DataManager.shared.saveRecurringPayments(remapped.recurringPayments, user: cleanUser)
        DataManager.shared.saveMoneyAccounts(remapped.moneyAccounts, user: cleanUser)
        DataManager.shared.saveAccountTransfers(remapped.accountTransfers, user: cleanUser)
        DataManager.shared.saveMonthlyBudget(remapped.monthlyBudget ?? MonthlyBudget(amount: 0), user: cleanUser)
        DataManager.shared.saveNotificationPreferences(remapped.notificationPreferences, user: cleanUser)
        TransactionCustomizationStore.shared.saveExpenseCustomCategories(remapped.expenseCustomCategories, user: cleanUser)
        TransactionCustomizationStore.shared.saveIncomeCustomCategories(remapped.incomeCustomCategories, user: cleanUser)
        TransactionCustomizationStore.shared.saveMoneyAccountCustomCategories(remapped.moneyAccountCustomCategories, user: cleanUser)
        TransactionCustomizationStore.shared.saveRecurringPaymentCustomCategories(remapped.recurringPaymentCustomCategories, user: cleanUser)
        DataManager.shared.saveBudgetAlertState(BudgetAlertState(), user: cleanUser)
        DataManager.shared.saveProfileImageData(remapped.profileImageData, user: cleanUser)
        DataManager.shared.saveProfileDisplayName(remapped.profileDisplayName, user: cleanUser)
    }
    
    private func validatedSnapshot(_ snapshot: AppBackupSnapshot) throws -> AppBackupSnapshot {
        guard snapshot.version > 0 else {
            throw AppBackupError.invalidSnapshot
        }

        guard snapshot.version <= currentVersion else {
            throw AppBackupError.unsupportedVersion
        }

        let cleanSourceUser = snapshot.sourceUser
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanSourceUser.isEmpty, cleanSourceUser.count <= maximumSourceUserLength else {
            throw AppBackupError.invalidSnapshot
        }

        let sanitizedReferencesSnapshot = referenceSanitizer.sanitize(snapshot)
        let sanitizedFinancialSnapshot = try financialStateSanitizer.sanitize(sanitizedReferencesSnapshot)

        try validateExpenses(sanitizedFinancialSnapshot.expenses)
        try validateIncomes(sanitizedFinancialSnapshot.incomes)
        try validateDebts(sanitizedFinancialSnapshot.debts)
        try validateRecurringPayments(sanitizedFinancialSnapshot.recurringPayments)
        try validateMoneyAccounts(sanitizedFinancialSnapshot.moneyAccounts)
        try validateAccountTransfers(
            sanitizedFinancialSnapshot.accountTransfers,
            moneyAccounts: sanitizedFinancialSnapshot.moneyAccounts
        )

        let budget = normalizedBudget(sanitizedFinancialSnapshot.monthlyBudget)
        let notificationPreferences = sanitizedNotificationPreferences(sanitizedFinancialSnapshot.notificationPreferences)
        let expenseCustomCategories = sanitizedExpenseCustomCategories(sanitizedFinancialSnapshot.expenseCustomCategories)
        let incomeCustomCategories = sanitizedIncomeCustomCategories(sanitizedFinancialSnapshot.incomeCustomCategories)
        let moneyAccountCustomCategories = sanitizedMoneyAccountCustomCategories(sanitizedFinancialSnapshot.moneyAccountCustomCategories)
        let profileImageData = try validatedProfileImageData(sanitizedFinancialSnapshot.profileImageData)
        let profileDisplayName = sanitizedProfileDisplayName(sanitizedFinancialSnapshot.profileDisplayName)

        return AppBackupSnapshot(
            version: sanitizedFinancialSnapshot.version,
            exportedAt: sanitizedFinancialSnapshot.exportedAt,
            sourceUser: cleanSourceUser,
            expenses: sanitizedFinancialSnapshot.expenses,
            incomes: sanitizedFinancialSnapshot.incomes,
            debts: sanitizedFinancialSnapshot.debts,
            recurringPayments: sanitizedFinancialSnapshot.recurringPayments,
            moneyAccounts: sanitizedFinancialSnapshot.moneyAccounts,
            accountTransfers: sanitizedFinancialSnapshot.accountTransfers,
            monthlyBudget: budget,
            notificationPreferences: notificationPreferences,
            expenseCustomCategories: expenseCustomCategories,
            incomeCustomCategories: incomeCustomCategories,
            moneyAccountCustomCategories: moneyAccountCustomCategories,
            recurringPaymentCustomCategories: snapshot.recurringPaymentCustomCategories,
            profileImageData: profileImageData,
            profileDisplayName: profileDisplayName
        )
    }
    
    private func sanitizedRecurringPaymentCustomCategories(_ items: [CustomRecurringPaymentCategory]) -> [CustomRecurringPaymentCategory] {
        var seen: Set<String> = []

        return items.compactMap { item in
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }

            seen.insert(key)
            return CustomRecurringPaymentCategory(id: item.id, name: trimmed, style: item.style)
        }
    }

    private func validateExpenses(_ expenses: [Expense]) throws {
        guard expenses.count <= maximumRecordsPerCollection else {
            throw AppBackupError.invalidSnapshot
        }

        for expense in expenses {
            guard !expense.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  expense.amount.isFinite,
                  expense.amount > 0 else {
                throw AppBackupError.invalidSnapshot
            }
        }
    }

    private func validateIncomes(_ incomes: [Income]) throws {
        guard incomes.count <= maximumRecordsPerCollection else {
            throw AppBackupError.invalidSnapshot
        }

        for income in incomes {
            guard !income.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  income.amount.isFinite,
                  income.amount > 0 else {
                throw AppBackupError.invalidSnapshot
            }
        }
    }

    private func validateDebts(_ debts: [Debt]) throws {
        guard debts.count <= maximumRecordsPerCollection else {
            throw AppBackupError.invalidSnapshot
        }

        for debt in debts {
            guard !debt.cardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  debt.totalLimit.isFinite,
                  debt.remainingDebt.isFinite,
                  debt.totalLimit >= 0,
                  debt.remainingDebt >= 0,
                  debt.remainingDebt <= debt.totalLimit else {
                throw AppBackupError.invalidSnapshot
            }
        }
    }

    private func validateRecurringPayments(_ payments: [RecurringPayment]) throws {
        guard payments.count <= maximumRecordsPerCollection else {
            throw AppBackupError.invalidSnapshot
        }

        for payment in payments {
            guard !payment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  payment.amount.isFinite,
                  payment.amount > 0,
                  (1...31).contains(payment.dueDay) else {
                throw AppBackupError.invalidSnapshot
            }

            if let month = payment.lastPaidMonth, !(1...12).contains(month) {
                throw AppBackupError.invalidSnapshot
            }

            if let year = payment.lastPaidYear, !(1900...3000).contains(year) {
                throw AppBackupError.invalidSnapshot
            }
        }
    }

    private func validateMoneyAccounts(_ accounts: [MoneyAccount]) throws {
        guard accounts.count <= maximumRecordsPerCollection else {
            throw AppBackupError.invalidSnapshot
        }

        for account in accounts {
            guard !account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  account.balance.isFinite,
                  account.balance >= 0 else {
                throw AppBackupError.invalidSnapshot
            }
        }
    }
    
    private func validateAccountTransfers(_ transfers: [AccountTransfer], moneyAccounts: [MoneyAccount]) throws {
        guard transfers.count <= maximumRecordsPerCollection else {
            throw AppBackupError.invalidSnapshot
        }

        let validAccountIds = Set(moneyAccounts.map(\.id))

        for transfer in transfers {
            guard transfer.amount.isFinite,
                  transfer.amount > 0,
                  transfer.fromAccountId != transfer.toAccountId,
                  validAccountIds.contains(transfer.fromAccountId),
                  validAccountIds.contains(transfer.toAccountId) else {
                throw AppBackupError.invalidSnapshot
            }
        }
    }

    private func normalizedBudget(_ budget: MonthlyBudget?) -> MonthlyBudget? {
        guard let budget else { return nil }
        guard budget.amount.isFinite, budget.amount > 0 else { return nil }
        return MonthlyBudget(amount: budget.amount)
    }

    private func sanitizedNotificationPreferences(_ preferences: NotificationPreferences) -> NotificationPreferences {
        let threshold = preferences.budgetAlertThreshold.isFinite
        ? min(max(preferences.budgetAlertThreshold, 0), 1)
        : 0.80

        let leadDays = min(max(preferences.recurringReminderLeadDays, 0), 3)

        return NotificationPreferences(
            recurringPaymentsEnabled: preferences.recurringPaymentsEnabled,
            recurringReminderLeadDays: leadDays,
            budgetAlertsEnabled: preferences.budgetAlertsEnabled,
            budgetAlertThreshold: threshold,
            dailySummaryEnabled: preferences.dailySummaryEnabled
        )
    }

    private func validatedProfileImageData(_ data: Data?) throws -> Data? {
        guard let data else { return nil }
        guard !data.isEmpty else { return nil }
        guard data.count <= maximumProfileImageBytes else {
            throw AppBackupError.invalidSnapshot
        }
        return data
    }

    private func sanitizedProfileImageData(_ data: Data?) -> Data? {
        guard let data else { return nil }
        guard !data.isEmpty, data.count <= maximumProfileImageBytes else { return nil }
        return data
    }

    private func sanitizedProfileDisplayName(_ name: String?) -> String? {
        guard let name else { return nil }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return String(trimmed.prefix(maximumProfileDisplayNameLength))
    }

    private func removeUTF8BOMIfNeeded(from data: Data) -> Data {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        if data.starts(with: bom) {
            return data.dropFirst(3)
        }
        return data
    }

    private func fileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "nexora_backup_\(formatter.string(from: Date())).json"
    }
}

private func sanitizedExpenseCustomCategories(_ items: [CustomExpenseCategory]) -> [CustomExpenseCategory] {
    var seen: Set<String> = []

    return items.compactMap { item in
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = trimmed.lowercased()
        guard !seen.contains(key) else { return nil }

        seen.insert(key)
        return CustomExpenseCategory(id: item.id, name: trimmed, style: item.style)
    }
}

private func sanitizedIncomeCustomCategories(_ items: [CustomIncomeCategory]) -> [CustomIncomeCategory] {
    var seen: Set<String> = []

    return items.compactMap { item in
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = trimmed.lowercased()
        guard !seen.contains(key) else { return nil }

        seen.insert(key)
        return CustomIncomeCategory(id: item.id, name: trimmed, style: item.style)
    }
}

private func sanitizedMoneyAccountCustomCategories(_ items: [CustomMoneyAccountCategory]) -> [CustomMoneyAccountCategory] {
    var seen: Set<String> = []

    return items.compactMap { item in
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let key = trimmed.lowercased()
        guard !seen.contains(key) else { return nil }

        seen.insert(key)
        return CustomMoneyAccountCategory(id: item.id, name: trimmed, style: item.style)
    }
}

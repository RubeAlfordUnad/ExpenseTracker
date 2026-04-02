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
    let monthlyBudget: MonthlyBudget?
    let notificationPreferences: NotificationPreferences
    let profileImageData: Data?
    let profileDisplayName: String?
}

struct AppBackupSummary {
    let expensesCount: Int
    let incomesCount: Int
    let debtsCount: Int
    let recurringPaymentsCount: Int
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

    private let currentVersion = 1
    private let maximumBackupBytes = 12 * 1024 * 1024
    private let maximumRecordsPerCollection = 100_000
    private let maximumSourceUserLength = 80
    private let maximumProfileDisplayNameLength = 60
    private let maximumProfileImageBytes = 5 * 1024 * 1024

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
            monthlyBudget: DataManager.shared.loadMonthlyBudget(user: cleanUser),
            notificationPreferences: DataManager.shared.loadNotificationPreferences(user: cleanUser),
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
                hasBudget: false,
                hasProfileImage: false
            )
        }

        return AppBackupSummary(
            expensesCount: DataManager.shared.loadExpenses(user: cleanUser).count,
            incomesCount: DataManager.shared.loadIncomes(user: cleanUser).count,
            debtsCount: DataManager.shared.loadDebts(user: cleanUser).count,
            recurringPaymentsCount: DataManager.shared.loadRecurringPayments(user: cleanUser).count,
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

        DataManager.shared.saveExpenses(validated.expenses, user: cleanUser)
        DataManager.shared.saveIncomes(validated.incomes, user: cleanUser)
        DataManager.shared.saveDebts(validated.debts, user: cleanUser)
        DataManager.shared.saveRecurringPayments(validated.recurringPayments, user: cleanUser)
        DataManager.shared.saveMonthlyBudget(validated.monthlyBudget ?? MonthlyBudget(amount: 0), user: cleanUser)
        DataManager.shared.saveNotificationPreferences(validated.notificationPreferences, user: cleanUser)
        DataManager.shared.saveBudgetAlertState(BudgetAlertState(), user: cleanUser)
        DataManager.shared.saveProfileImageData(validated.profileImageData, user: cleanUser)
        DataManager.shared.saveProfileDisplayName(validated.profileDisplayName, user: cleanUser)
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

        try validateExpenses(snapshot.expenses)
        try validateIncomes(snapshot.incomes)
        try validateDebts(snapshot.debts)
        try validateRecurringPayments(snapshot.recurringPayments)

        let budget = normalizedBudget(snapshot.monthlyBudget)
        let notificationPreferences = sanitizedNotificationPreferences(snapshot.notificationPreferences)
        let profileImageData = try validatedProfileImageData(snapshot.profileImageData)
        let profileDisplayName = sanitizedProfileDisplayName(snapshot.profileDisplayName)

        return AppBackupSnapshot(
            version: snapshot.version,
            exportedAt: snapshot.exportedAt,
            sourceUser: cleanSourceUser,
            expenses: snapshot.expenses,
            incomes: snapshot.incomes,
            debts: snapshot.debts,
            recurringPayments: snapshot.recurringPayments,
            monthlyBudget: budget,
            notificationPreferences: notificationPreferences,
            profileImageData: profileImageData,
            profileDisplayName: profileDisplayName
        )
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
                  debt.remainingDebt >= 0 else {
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

    private func normalizedBudget(_ budget: MonthlyBudget?) -> MonthlyBudget? {
        guard let budget else { return nil }
        guard budget.amount.isFinite, budget.amount > 0 else { return nil }
        return MonthlyBudget(amount: budget.amount)
    }

    private func sanitizedNotificationPreferences(_ preferences: NotificationPreferences) -> NotificationPreferences {
        let threshold = preferences.budgetAlertThreshold.isFinite
        ? min(max(preferences.budgetAlertThreshold, 0), 1)
        : 0.80

        return NotificationPreferences(
            recurringPaymentsEnabled: preferences.recurringPaymentsEnabled,
            budgetAlertsEnabled: preferences.budgetAlertsEnabled,
            budgetAlertThreshold: threshold
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

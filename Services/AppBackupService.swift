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
        }
    }
}

final class AppBackupService {

    private let currentVersion = 1

    func currentSnapshot(for user: String) throws -> AppBackupSnapshot {
        let cleanUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty else {
            throw AppBackupError.emptyUser
        }

        return AppBackupSnapshot(
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
            hasBudget: (DataManager.shared.loadMonthlyBudget(user: cleanUser)?.amount ?? 0) > 0,
            hasProfileImage: DataManager.shared.loadProfileImageData(user: cleanUser) != nil
        )
    }

    func summary(for snapshot: AppBackupSnapshot) -> AppBackupSummary {
        AppBackupSummary(
            expensesCount: snapshot.expenses.count,
            incomesCount: snapshot.incomes.count,
            debtsCount: snapshot.debts.count,
            recurringPaymentsCount: snapshot.recurringPayments.count,
            hasBudget: (snapshot.monthlyBudget?.amount ?? 0) > 0,
            hasProfileImage: snapshot.profileImageData != nil
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
        guard !data.isEmpty else {
            throw AppBackupError.emptyData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let snapshot = try decoder.decode(AppBackupSnapshot.self, from: data)
            guard snapshot.version <= currentVersion else {
                throw AppBackupError.unsupportedVersion
            }
            return snapshot
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

        DataManager.shared.saveExpenses(snapshot.expenses, user: cleanUser)
        DataManager.shared.saveIncomes(snapshot.incomes, user: cleanUser)
        DataManager.shared.saveDebts(snapshot.debts, user: cleanUser)
        DataManager.shared.saveRecurringPayments(snapshot.recurringPayments, user: cleanUser)

        if let budget = snapshot.monthlyBudget {
            DataManager.shared.saveMonthlyBudget(budget, user: cleanUser)
        } else {
            DataManager.shared.saveMonthlyBudget(MonthlyBudget(amount: 0), user: cleanUser)
        }

        DataManager.shared.saveNotificationPreferences(snapshot.notificationPreferences, user: cleanUser)
        DataManager.shared.saveBudgetAlertState(BudgetAlertState(), user: cleanUser)
        DataManager.shared.saveProfileImageData(snapshot.profileImageData, user: cleanUser)
        DataManager.shared.saveProfileDisplayName(snapshot.profileDisplayName, user: cleanUser)
    }

    private func fileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "nexora_backup_\(formatter.string(from: Date())).json"
    }
}

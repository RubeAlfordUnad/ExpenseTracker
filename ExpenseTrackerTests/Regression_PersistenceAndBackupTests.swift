import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - persistence and backup")
struct RegressionPersistenceAndBackupTests {

    @Test("Income metadata merge preserves moneyAccountId")
    func incomeMetadataMerge_preserves_moneyAccountId() {
        let user = makeUniqueUsername("incomeMeta")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let accountId = UUID()
        let incomes = [
            Income(
                title: "Salario abril",
                amount: 3_500_000,
                date: makeDate(year: 2026, month: 4, day: 1),
                category: .salary,
                customCategoryName: "Nomina principal",
                moneyAccountId: accountId,
                comment: "Consignado en Bancolombia"
            )
        ]

        DataManager.shared.saveIncomes(incomes, user: user)
        let loaded = DataManager.shared.loadIncomes(user: user)

        #expect(loaded.count == 1)
        #expect(loaded.first?.moneyAccountId == accountId)
        #expect(loaded.first?.customCategoryName == "Nomina principal")
        #expect(loaded.first?.comment == "Consignado en Bancolombia")
    }

    @Test("Backup export preserves new notification fields")
    func backupExport_preserves_new_notification_fields() throws {
        let user = makeUniqueUsername("backupNotificationExport")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let originalPreferences = NotificationPreferences(
            recurringPaymentsEnabled: true,
            recurringReminderLeadDays: 3,
            budgetAlertsEnabled: false,
            budgetAlertThreshold: 0.65,
            dailySummaryEnabled: true
        )

        DataManager.shared.saveNotificationPreferences(originalPreferences, user: user)

        let service = AppBackupService()
        let payload = try service.makeExport(for: user)
        let importedSnapshot = try service.importSnapshot(from: payload.data)

        #expect(importedSnapshot.notificationPreferences == originalPreferences)
    }

    @Test("Backup restore preserves new notification fields")
    func backupRestore_preserves_new_notification_fields() throws {
        let user = makeUniqueUsername("backupNotificationRestore")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let originalPreferences = NotificationPreferences(
            recurringPaymentsEnabled: false,
            recurringReminderLeadDays: 2,
            budgetAlertsEnabled: true,
            budgetAlertThreshold: 0.72,
            dailySummaryEnabled: true
        )

        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [],
            incomes: [],
            debts: [],
            recurringPayments: [],
            moneyAccounts: [],
            accountTransfers: [],
            monthlyBudget: nil,
            notificationPreferences: originalPreferences,
            expenseCustomCategories: [],
            incomeCustomCategories: [],
            moneyAccountCustomCategories: [],
            profileImageData: nil,
            profileDisplayName: nil
        )

        try AppBackupService().restore(snapshot, to: user)
        let restoredPreferences = DataManager.shared.loadNotificationPreferences(user: user)

        #expect(restoredPreferences == originalPreferences)
    }

    @Test("Backup snapshot supports legacy payloads without reusable categories")
    func backupSnapshot_supports_legacy_payload_without_reusable_categories() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "2026-04-06T10:00:00Z",
          "sourceUser": "legacy_user",
          "expenses": [],
          "incomes": [],
          "debts": [],
          "recurringPayments": [],
          "monthlyBudget": { "amount": 900000 },
          "notificationPreferences": {
            "recurringPaymentsEnabled": true,
            "budgetAlertsEnabled": true,
            "budgetAlertThreshold": 0.8
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot = try decoder.decode(AppBackupSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.version == 1)
        #expect(snapshot.expenseCustomCategories.isEmpty)
        #expect(snapshot.incomeCustomCategories.isEmpty)
        #expect(snapshot.moneyAccountCustomCategories.isEmpty)
    }

    @Test("Backup export and import preserve reusable custom categories")
    func backupExportImport_preserves_reusable_custom_categories() throws {
        let user = makeUniqueUsername("backupCategoriesExport")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        TransactionCustomizationStore.shared.saveExpenseCustomCategories([
            CustomExpenseCategory(name: "Mascotas", style: .pets),
            CustomExpenseCategory(name: "Gym Pro", style: .health)
        ], user: user)

        TransactionCustomizationStore.shared.saveIncomeCustomCategories([
            CustomIncomeCategory(name: "Side Hustle", style: .freelance)
        ], user: user)

        TransactionCustomizationStore.shared.saveMoneyAccountCustomCategories([
            CustomMoneyAccountCategory(name: "Caja Fuerte", style: .savings)
        ], user: user)

        let service = AppBackupService()
        let payload = try service.makeExport(for: user)
        let snapshot = try service.importSnapshot(from: payload.data)

        #expect(snapshot.expenseCustomCategories.map(\.name) == ["Mascotas", "Gym Pro"])
        #expect(snapshot.incomeCustomCategories.map(\.name) == ["Side Hustle"])
        #expect(snapshot.moneyAccountCustomCategories.map(\.name) == ["Caja Fuerte"])
    }

    @Test("Backup restore persists reusable custom categories")
    func backupRestore_persists_reusable_custom_categories() throws {
        let user = makeUniqueUsername("backupCategoriesRestore")

        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [],
            incomes: [],
            debts: [],
            recurringPayments: [],
            moneyAccounts: [],
            accountTransfers: [],
            monthlyBudget: nil,
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [
                CustomExpenseCategory(name: "Mascotas", style: .pets),
                CustomExpenseCategory(name: "Viajes relampago", style: .travel)
            ],
            incomeCustomCategories: [
                CustomIncomeCategory(name: "Bono startup", style: .bonus)
            ],
            moneyAccountCustomCategories: [
                CustomMoneyAccountCategory(name: "Fondo reserva", style: .savings)
            ],
            profileImageData: nil,
            profileDisplayName: nil
        )

        try AppBackupService().restore(snapshot, to: user)

        #expect(TransactionCustomizationStore.shared.loadExpenseCustomCategories(user: user).map(\.name) == ["Mascotas", "Viajes relampago"])
        #expect(TransactionCustomizationStore.shared.loadIncomeCustomCategories(user: user).map(\.name) == ["Bono startup"])
        #expect(TransactionCustomizationStore.shared.loadMoneyAccountCustomCategories(user: user).map(\.name) == ["Fondo reserva"])
    }

    @Test("Backup service sanitizes empty and duplicate reusable categories")
    func backupService_sanitizes_empty_and_duplicate_reusable_categories() throws {
        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [],
            incomes: [],
            debts: [],
            recurringPayments: [],
            moneyAccounts: [],
            accountTransfers: [],
            monthlyBudget: nil,
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [
                CustomExpenseCategory(name: " Mascotas ", style: .pets),
                CustomExpenseCategory(name: "mascotas", style: .health),
                CustomExpenseCategory(name: "   ", style: .food)
            ],
            incomeCustomCategories: [
                CustomIncomeCategory(name: " Freelance ", style: .freelance),
                CustomIncomeCategory(name: "freelance", style: .salary)
            ],
            moneyAccountCustomCategories: [
                CustomMoneyAccountCategory(name: " Caja ", style: .cash),
                CustomMoneyAccountCategory(name: "", style: .savings)
            ],
            profileImageData: nil,
            profileDisplayName: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let validated = try AppBackupService().importSnapshot(from: data)

        #expect(validated.expenseCustomCategories.count == 1)
        #expect(validated.expenseCustomCategories[0].name == "Mascotas")
        #expect(validated.incomeCustomCategories.count == 1)
        #expect(validated.incomeCustomCategories[0].name == "Freelance")
        #expect(validated.moneyAccountCustomCategories.count == 1)
        #expect(validated.moneyAccountCustomCategories[0].name == "Caja")
    }
}

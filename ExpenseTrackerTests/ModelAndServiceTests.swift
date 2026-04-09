import Foundation
import UniformTypeIdentifiers
import Testing
@testable import ExpenseTracker

@Suite("Models and services")
struct ModelAndServiceTests {

    @Test("Debt calcula crédito disponible y porcentaje de uso")
    func debt_computed_values_are_correct() {
        let debt = Debt(
            cardName: "Visa Platinum",
            brand: .visa,
            totalLimit: 4000000,
            remainingDebt: 1000000
        )

        #expect(debt.availableCredit == 3000000)
        #expect(debt.utilization == 0.25)
        #expect(debt.utilizationPercentage == 25)
    }

    @Test("RecurringPayment detecta si ya fue pagado en el mes actual")
    func recurringPayment_detects_current_month_payment() {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())

        let paid = RecurringPayment(
            title: "Spotify",
            amount: 23000,
            dueDay: 12,
            category: .subscriptions,
            isActive: true,
            lastPaidMonth: currentMonth,
            lastPaidYear: currentYear
        )

        let unpaid = RecurringPayment(
            title: "Rent",
            amount: 900000,
            dueDay: 5,
            category: .housing,
            isActive: true,
            lastPaidMonth: nil,
            lastPaidYear: nil
        )

        #expect(paid.isPaidForCurrentMonth)
        #expect(!unpaid.isPaidForCurrentMonth)
    }

    @Test("DebtsExportService genera JSON válido")
    func debtsExportService_generates_json() throws {
        let debt = Debt(
            cardName: "Visa Gold",
            brand: .visa,
            totalLimit: 5000000,
            remainingDebt: 1200000
        )

        let payload = try DebtsExportService().makeExport(from: [debt], format: .json)
        let decoded = try JSONDecoder().decode([Debt].self, from: payload.data)

        #expect(payload.contentType == .json)
        #expect(payload.fileName.hasSuffix(".json"))
        #expect(decoded.count == 1)
        #expect(decoded.first?.cardName == "Visa Gold")
        #expect(decoded.first?.remainingDebt == 1200000)
    }

    @Test("DebtsExportService genera CSV con encabezados y escapa comas")
    func debtsExportService_generates_csv() throws {
        let debt = Debt(
            cardName: "Visa Gold, Shared",
            brand: .visa,
            totalLimit: 5000000,
            remainingDebt: 1200000
        )

        let payload = try DebtsExportService().makeExport(from: [debt], format: .csv)
        let csv = String(decoding: payload.data, as: UTF8.self)

        #expect(payload.contentType == .commaSeparatedText)
        #expect(payload.fileName.hasSuffix(".csv"))
        #expect(csv.contains("card_name,brand,total_limit,remaining_debt,available_credit,utilization_percentage"))
        #expect(csv.contains("\"Visa Gold, Shared\""))
        #expect(csv.contains("Visa"))
        #expect(csv.contains("1200000.0"))
    }

    @Test("NotificationPreferences soporta payloads viejos")
    func notificationPreferences_decodes_legacy_payload() throws {
        let json = """
        {
          "recurringPaymentsEnabled": false,
          "budgetAlertsEnabled": true,
          "budgetAlertThreshold": 0.9
        }
        """

        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: Data(json.utf8))

        #expect(decoded.recurringPaymentsEnabled == false)
        #expect(decoded.recurringReminderLeadDays == 0)
        #expect(decoded.budgetAlertsEnabled == true)
        #expect(abs(decoded.budgetAlertThreshold - 0.9) < 0.0001)
        #expect(decoded.dailySummaryEnabled == false)
    }

    @Test("NotificationPreferences conserva nuevas claves")
    func notificationPreferences_preserves_new_fields() throws {
        let original = NotificationPreferences(
            recurringPaymentsEnabled: true,
            recurringReminderLeadDays: 2,
            budgetAlertsEnabled: true,
            budgetAlertThreshold: 0.75,
            dailySummaryEnabled: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        #expect(decoded == original)
    }

    @Test("AppBackupSnapshot soporta respaldos viejos sin cuentas de dinero")
    func appBackupSnapshot_decodes_legacy_payload_without_money_accounts() throws {
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
        #expect(snapshot.moneyAccounts.isEmpty)
        #expect(snapshot.monthlyBudget?.amount == 900000)
    }

    @Test("AppBackupService restaura cuentas de dinero y presupuesto")
    func appBackupService_restores_money_accounts_and_budget() throws {
        let user = makeUniqueUsername("backupRestore")
        clearAppStorage(for: [user])
        defer { clearAppStorage(for: [user]) }

        let service = AppBackupService()
        let snapshot = AppBackupSnapshot(
            version: 2,
            exportedAt: makeDate(year: 2026, month: 4, day: 6),
            sourceUser: "source_user",
            expenses: [
                Expense(title: "Mercado", amount: 120000, date: makeDate(year: 2026, month: 4, day: 2), category: .food)
            ],
            incomes: [
                Income(title: "Salario", amount: 3500000, date: makeDate(year: 2026, month: 4, day: 1), category: .salary)
            ],
            debts: [],
            recurringPayments: [],
            moneyAccounts: [
                MoneyAccount(name: "Efectivo", balance: 250000, kind: .cash),
                MoneyAccount(name: "Ahorros", balance: 1800000, kind: .savings, includeInAvailableTotal: false)
            ],
            monthlyBudget: MonthlyBudget(amount: 1400000),
            notificationPreferences: NotificationPreferences(
                recurringPaymentsEnabled: true,
                recurringReminderLeadDays: 1,
                budgetAlertsEnabled: true,
                budgetAlertThreshold: 0.7,
                dailySummaryEnabled: true
            ),
            profileImageData: nil,
            profileDisplayName: "Rube"
        )

        try service.restore(snapshot, to: user)

        let restoredAccounts = DataManager.shared.loadMoneyAccounts(user: user)
        let restoredBudget = DataManager.shared.loadMonthlyBudget(user: user)
        let restoredExpenses = DataManager.shared.loadExpenses(user: user)
        let restoredIncomes = DataManager.shared.loadIncomes(user: user)

        #expect(restoredAccounts.count == 2)
        #expect(restoredAccounts.map(\.name) == ["Ahorros", "Efectivo"])
        #expect(restoredAccounts.first(where: { $0.name == "Ahorros" })?.includeInAvailableTotal == false)
        #expect(restoredBudget?.amount == 1400000)
        #expect(restoredExpenses.count == 1)
        #expect(restoredIncomes.count == 1)
        #expect(DataManager.shared.loadProfileDisplayName(user: user) == "Rube")
    }
}

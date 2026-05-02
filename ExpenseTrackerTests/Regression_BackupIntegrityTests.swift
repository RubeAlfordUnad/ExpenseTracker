import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - backup integrity")
struct RegressionBackupIntegrityTests {

    @Test("RecurringPaymentExpenseSync clears paid status linked to deleted expense")
    func recurringPaymentExpenseSync_clears_paid_status_linked_to_deleted_expense() {
        let linkedExpenseId = UUID()
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())

        var payments = [
            RecurringPayment(
                title: "Internet",
                amount: 95_000,
                dueDay: 10,
                category: .utilities,
                isActive: true,
                lastPaidMonth: currentMonth,
                lastPaidYear: currentYear,
                lastPaidExpenseId: linkedExpenseId
            )
        ]

        let cleared = RecurringPaymentExpenseSync().clearPaidStatusLinked(to: linkedExpenseId, payments: &payments)

        #expect(cleared == 1)
        #expect(payments[0].lastPaidMonth == nil)
        #expect(payments[0].lastPaidYear == nil)
        #expect(payments[0].lastPaidExpenseId == nil)
        #expect(payments[0].isPaidForCurrentMonth == false)
    }

    @Test("Backup identity remapper preserves custom categories")
    func backupIdentityRemapper_preserves_custom_categories() {
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
            monthlyBudget: MonthlyBudget(amount: 1_000_000),
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [CustomExpenseCategory(name: "Mascotas", style: .other)],
            incomeCustomCategories: [CustomIncomeCategory(name: "Side Hustle", style: .freelance)],
            moneyAccountCustomCategories: [CustomMoneyAccountCategory(name: "Caja Fuerte", style: .savings)],
            profileImageData: nil,
            profileDisplayName: "Rube"
        )

        let remapped = AppBackupIdentityRemapper().remap(snapshot)

        #expect(remapped.expenseCustomCategories.map { $0.name } == ["Mascotas"])
        #expect(remapped.incomeCustomCategories.map { $0.name } == ["Side Hustle"])
        #expect(remapped.moneyAccountCustomCategories.map { $0.name } == ["Caja Fuerte"])
    }

    @Test("Backup reference sanitizer clears orphan expense and income references")
    func backupReferenceSanitizer_clears_orphan_expense_and_income_references() {
        let validAccountId = UUID()
        let validDebtId = UUID()

        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [
                Expense(title: "Mercado", amount: 150_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food, moneyAccountId: UUID(), creditCardId: UUID(), comment: "IDs invalidos"),
                Expense(title: "Compra tarjeta", amount: 200_000, date: makeDate(year: 2026, month: 4, day: 12), category: .shopping, moneyAccountId: validAccountId, creditCardId: validDebtId)
            ],
            incomes: [
                Income(title: "Salario", amount: 2_500_000, date: makeDate(year: 2026, month: 4, day: 1), category: .salary, moneyAccountId: UUID(), comment: "Cuenta invalida")
            ],
            debts: [Debt(id: validDebtId, cardName: "Visa", brand: .visa, totalLimit: 5_000_000, remainingDebt: 300_000)],
            recurringPayments: [],
            moneyAccounts: [MoneyAccount(id: validAccountId, name: "Bancolombia", balance: 1_000_000, kind: .checking)],
            accountTransfers: [],
            monthlyBudget: nil,
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [],
            incomeCustomCategories: [],
            moneyAccountCustomCategories: [],
            profileImageData: nil,
            profileDisplayName: nil
        )

        let sanitized = AppBackupReferenceSanitizer().sanitize(snapshot)

        #expect(sanitized.expenses[0].moneyAccountId == nil)
        #expect(sanitized.expenses[0].creditCardId == nil)
        #expect(sanitized.expenses[1].creditCardId == validDebtId)
        #expect(sanitized.expenses[1].moneyAccountId == nil)
        #expect(sanitized.incomes[0].moneyAccountId == nil)
    }

    @Test("Backup reference sanitizer clears orphan recurring payment paid state")
    func backupReferenceSanitizer_clears_orphan_recurring_payment_paid_state() {
        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [],
            incomes: [],
            debts: [],
            recurringPayments: [
                RecurringPayment(title: "Internet", amount: 95_000, dueDay: 10, category: .utilities, isActive: true, lastPaidMonth: 4, lastPaidYear: 2026, lastPaidExpenseId: UUID())
            ],
            moneyAccounts: [],
            accountTransfers: [],
            monthlyBudget: nil,
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [],
            incomeCustomCategories: [],
            moneyAccountCustomCategories: [],
            profileImageData: nil,
            profileDisplayName: nil
        )

        let sanitized = AppBackupReferenceSanitizer().sanitize(snapshot)

        #expect(sanitized.recurringPayments[0].lastPaidExpenseId == nil)
        #expect(sanitized.recurringPayments[0].lastPaidMonth == nil)
        #expect(sanitized.recurringPayments[0].lastPaidYear == nil)
    }

    @Test("Backup service rejects negative money account balances")
    func backupService_rejects_negative_money_account_balances() throws {
        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [],
            incomes: [],
            debts: [],
            recurringPayments: [],
            moneyAccounts: [MoneyAccount(name: "Bancolombia", balance: -100, kind: .checking)],
            accountTransfers: [],
            monthlyBudget: nil,
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [],
            incomeCustomCategories: [],
            moneyAccountCustomCategories: [],
            profileImageData: nil,
            profileDisplayName: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        do {
            _ = try AppBackupService().importSnapshot(from: data)
            Issue.record("Expected invalid snapshot error")
        } catch let error as AppBackupError {
            switch error {
            case .invalidSnapshot: break
            default: Issue.record("Unexpected AppBackupError: \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

    @Test("Backup service rejects debt above total limit")
    func backupService_rejects_debt_above_total_limit() throws {
        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [],
            incomes: [],
            debts: [Debt(cardName: "Visa", brand: .visa, totalLimit: 1_000_000, remainingDebt: 1_200_000)],
            recurringPayments: [],
            moneyAccounts: [],
            accountTransfers: [],
            monthlyBudget: nil,
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [],
            incomeCustomCategories: [],
            moneyAccountCustomCategories: [],
            profileImageData: nil,
            profileDisplayName: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        do {
            _ = try AppBackupService().importSnapshot(from: data)
            Issue.record("Expected invalid snapshot error")
        } catch let error as AppBackupError {
            switch error {
            case .invalidSnapshot: break
            default: Issue.record("Unexpected AppBackupError: \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

    @Test("Backup service restores same snapshot to two users with fresh identities")
    func backupService_restores_same_snapshot_to_two_users_with_fresh_identities() throws {
        let userA = makeUniqueUsername("restoreA")
        let userB = makeUniqueUsername("restoreB")

        clearAppStorage(for: [userA, userB])
        defer { clearAppStorage(for: [userA, userB]) }

        let accountId = UUID()
        let debtId = UUID()
        let expenseId = UUID()
        let incomeId = UUID()
        let recurringId = UUID()

        let snapshot = AppBackupSnapshot(
            version: 4,
            exportedAt: makeDate(year: 2026, month: 4, day: 12),
            sourceUser: "source_user",
            expenses: [Expense(id: expenseId, title: "Mercado", amount: 150_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food, moneyAccountId: accountId, creditCardId: debtId, comment: "Compra principal")],
            incomes: [Income(id: incomeId, title: "Salario", amount: 2_500_000, date: makeDate(year: 2026, month: 4, day: 1), category: .salary, moneyAccountId: accountId, comment: "Pago nomina")],
            debts: [Debt(id: debtId, cardName: "Visa", brand: .visa, totalLimit: 5_000_000, remainingDebt: 300_000)],
            recurringPayments: [RecurringPayment(id: recurringId, title: "Internet", amount: 95_000, dueDay: 10, category: .utilities, isActive: true, lastPaidMonth: 4, lastPaidYear: 2026, lastPaidExpenseId: expenseId)],
            moneyAccounts: [MoneyAccount(id: accountId, name: "Bancolombia", balance: 1_000_000, kind: .checking)],
            accountTransfers: [],
            monthlyBudget: MonthlyBudget(amount: 2_000_000),
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [CustomExpenseCategory(name: "Mascotas", style: .other)],
            incomeCustomCategories: [CustomIncomeCategory(name: "Bono", style: .gift)],
            moneyAccountCustomCategories: [CustomMoneyAccountCategory(name: "Caja", style: .cash)],
            profileImageData: nil,
            profileDisplayName: "Rube"
        )

        let service = AppBackupService()
        try service.restore(snapshot, to: userA)
        try service.restore(snapshot, to: userB)

        let expensesA = DataManager.shared.loadExpenses(user: userA)
        let expensesB = DataManager.shared.loadExpenses(user: userB)
        let incomesA = DataManager.shared.loadIncomes(user: userA)
        let incomesB = DataManager.shared.loadIncomes(user: userB)
        let accountsA = DataManager.shared.loadMoneyAccounts(user: userA)
        let accountsB = DataManager.shared.loadMoneyAccounts(user: userB)
        let debtsA = DataManager.shared.loadDebts(user: userA)
        let debtsB = DataManager.shared.loadDebts(user: userB)
        let recurringA = DataManager.shared.loadRecurringPayments(user: userA)
        let recurringB = DataManager.shared.loadRecurringPayments(user: userB)

        #expect(expensesA.count == 1)
        #expect(expensesB.count == 1)
        #expect(incomesA.count == 1)
        #expect(incomesB.count == 1)
        #expect(accountsA.count == 1)
        #expect(accountsB.count == 1)
        #expect(debtsA.count == 1)
        #expect(debtsB.count == 1)
        #expect(recurringA.count == 1)
        #expect(recurringB.count == 1)

        #expect(expensesA[0].id != expensesB[0].id)
        #expect(incomesA[0].id != incomesB[0].id)
        #expect(accountsA[0].id != accountsB[0].id)
        #expect(debtsA[0].id != debtsB[0].id)
        #expect(recurringA[0].id != recurringB[0].id)

        #expect(expensesA[0].moneyAccountId == nil)
        #expect(expensesB[0].moneyAccountId == nil)
        #expect(expensesA[0].creditCardId == debtsA[0].id)
        #expect(expensesB[0].creditCardId == debtsB[0].id)
        #expect(incomesA[0].moneyAccountId == accountsA[0].id)
        #expect(incomesB[0].moneyAccountId == accountsB[0].id)
        #expect(recurringA[0].lastPaidExpenseId == expensesA[0].id)
        #expect(recurringB[0].lastPaidExpenseId == expensesB[0].id)
    }


    private func makeUniqueUsername(_ prefix: String) -> String {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return "test_\(prefix)_\(suffix)"
    }

    private func clearAppStorage(for users: [String]) {
        for user in users {
            DataManager.shared.deleteAllLocalData(for: user)
        }
        UserDefaults.standard.synchronize()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        components.second = 0

        return components.date ?? Date(timeIntervalSince1970: 0)
    }

}
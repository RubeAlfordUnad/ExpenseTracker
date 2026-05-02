import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - import and dedupe")
struct RegressionImportAndDedupeTests {

    @Test("Imported expense merge updates money account balance")
    func importedExpenseMerge_updates_money_account_balance() {
        let accountId = UUID()
        var accounts = [MoneyAccount(id: accountId, name: "Bancolombia", balance: 1_000_000, kind: .checking)]
        var debts: [Debt] = []

        let imported = [Expense(title: "Mercado", amount: 150_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food, moneyAccountId: accountId, comment: "Importado desde JSON")]

        let result = ImportedExpenseMergeService().merge(existingExpenses: [], importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 1)
        #expect(result.duplicates == 0)
        #expect(accounts[0].balance == 850_000)
        #expect(result.expenses[0].moneyAccountId == accountId)
    }

    @Test("Imported expense merge updates debt when expense is linked to card")
    func importedExpenseMerge_updates_debt_when_expense_is_linked_to_card() {
        let debtId = UUID()
        var accounts: [MoneyAccount] = []
        var debts = [Debt(id: debtId, cardName: "Visa Platinum", brand: .visa, totalLimit: 4_000_000, remainingDebt: 500_000)]

        let imported = [Expense(title: "Portatil", amount: 300_000, date: makeDate(year: 2026, month: 4, day: 12), category: .shopping, creditCardId: debtId, comment: "Compra importada")]

        let result = ImportedExpenseMergeService().merge(existingExpenses: [], importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 1)
        #expect(result.expenses[0].creditCardId == debtId)
        #expect(debts[0].remainingDebt == 800_000)
    }

    @Test("Imported expense merge clears invalid funding references")
    func importedExpenseMerge_clears_invalid_funding_references() {
        var accounts = [MoneyAccount(name: "Efectivo", balance: 500_000, kind: .cash)]
        var debts = [Debt(cardName: "Mastercard", brand: .mastercard, totalLimit: 2_000_000, remainingDebt: 250_000)]

        let imported = [Expense(title: "Taxi", amount: 20_000, date: makeDate(year: 2026, month: 4, day: 12), category: .transport, moneyAccountId: UUID(), creditCardId: UUID(), comment: "IDs ajenos")]

        let result = ImportedExpenseMergeService().merge(existingExpenses: [], importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 1)
        #expect(result.expenses[0].moneyAccountId == nil)
        #expect(result.expenses[0].creditCardId == nil)
        #expect(accounts[0].balance == 500_000)
        #expect(debts[0].remainingDebt == 250_000)
    }

    @Test("Imported expense merge skips duplicates without reapplying funding")
    func importedExpenseMerge_skips_duplicates_without_reapplying_funding() {
        let accountId = UUID()
        let existingExpense = Expense(title: "Uber", amount: 20_000, date: makeDate(year: 2026, month: 4, day: 10), category: .transport)
        let importedDuplicate = Expense(id: UUID(), title: " Uber ", amount: 20_000, date: makeDate(year: 2026, month: 4, day: 10), category: .transport, moneyAccountId: accountId)

        var accounts = [MoneyAccount(id: accountId, name: "Nequi", balance: 300_000, kind: .digitalWallet)]
        var debts: [Debt] = []

        let result = ImportedExpenseMergeService().merge(existingExpenses: [existingExpense], importedExpenses: [importedDuplicate], accounts: &accounts, debts: &debts)

        #expect(result.inserted == 0)
        #expect(result.duplicates == 1)
        #expect(accounts[0].balance == 300_000)
    }

    @Test("Imported expense merge skips account expense that would overdraw balance")
    func importedExpenseMerge_skips_account_expense_that_would_overdraw_balance() {
        let accountId = UUID()
        var accounts = [MoneyAccount(id: accountId, name: "Nequi", balance: 50_000, kind: .digitalWallet)]
        var debts: [Debt] = []

        let imported = [Expense(title: "Mercado grande", amount: 80_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food, moneyAccountId: accountId)]

        let result = ImportedExpenseMergeService().merge(existingExpenses: [], importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 0)
        #expect(result.invalidFinancialRows == 1)
        #expect(accounts[0].balance == 50_000)
    }

    @Test("Imported expense merge skips card expense that would exceed limit")
    func importedExpenseMerge_skips_card_expense_that_would_exceed_limit() {
        let debtId = UUID()
        var accounts: [MoneyAccount] = []
        var debts = [Debt(id: debtId, cardName: "Visa", brand: .visa, totalLimit: 1_000_000, remainingDebt: 950_000)]

        let imported = [Expense(title: "Compra grande", amount: 100_000, date: makeDate(year: 2026, month: 4, day: 12), category: .shopping, creditCardId: debtId)]

        let result = ImportedExpenseMergeService().merge(existingExpenses: [], importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 0)
        #expect(result.invalidFinancialRows == 1)
        #expect(debts[0].remainingDebt == 950_000)
    }

    @Test("Duplicate fingerprint builder normalizes accent and punctuation variants")
    func duplicateFingerprintBuilder_normalizes_accent_and_punctuation_variants() {
        let builder = ImportedExpenseDuplicateFingerprintBuilder()

        let expenseA = Expense(title: "Uber  Eats", amount: 50_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food)
        let expenseB = Expense(title: "uber-eats", amount: 50_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food)

        let fingerprintA = builder.fingerprint(for: expenseA)
        let fingerprintB = builder.fingerprint(for: expenseB)

        #expect(fingerprintA.primaryKey == fingerprintB.primaryKey)
        #expect(fingerprintA.enrichedKey == fingerprintB.enrichedKey)
    }

    @Test("Imported expense merge distinguishes same day same amount by funding type")
    func importedExpenseMerge_distinguishes_same_day_same_amount_by_funding_type() {
        let accountId = UUID()
        let debtId = UUID()

        var accounts = [MoneyAccount(id: accountId, name: "Bancolombia", balance: 500_000, kind: .checking)]
        var debts = [Debt(id: debtId, cardName: "Visa", brand: .visa, totalLimit: 2_000_000, remainingDebt: 0)]

        let existing = [Expense(title: "Uber Eats", amount: 50_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food, moneyAccountId: accountId)]
        let imported = [Expense(title: "Uber Eats", amount: 50_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food, creditCardId: debtId)]

        let result = ImportedExpenseMergeService().merge(existingExpenses: existing, importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 1)
        #expect(result.duplicates == 0)
        #expect(result.expenses.count == 2)
    }

    @Test("Imported expense merge uses comment to avoid false duplicate")
    func importedExpenseMerge_uses_comment_to_avoid_false_duplicate() {
        var accounts: [MoneyAccount] = []
        var debts: [Debt] = []

        let existing = [Expense(title: "Taxi", amount: 20_000, date: makeDate(year: 2026, month: 4, day: 12), category: .transport, comment: "Aeropuerto")]
        let imported = [Expense(title: "Taxi", amount: 20_000, date: makeDate(year: 2026, month: 4, day: 12), category: .transport, comment: "Centro")]

        let result = ImportedExpenseMergeService().merge(existingExpenses: existing, importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 1)
        #expect(result.duplicates == 0)
        #expect(result.expenses.count == 2)
    }

    @Test("Imported expense merge detects plain duplicate without metadata")
    func importedExpenseMerge_detects_plain_duplicate_without_metadata() {
        var accounts: [MoneyAccount] = []
        var debts: [Debt] = []

        let existing = [Expense(title: "Mercado", amount: 120_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food)]
        let imported = [Expense(title: " mercado ", amount: 120_000, date: makeDate(year: 2026, month: 4, day: 12), category: .food)]

        let result = ImportedExpenseMergeService().merge(existingExpenses: existing, importedExpenses: imported, accounts: &accounts, debts: &debts)

        #expect(result.inserted == 0)
        #expect(result.duplicates == 1)
        #expect(result.expenses.count == 1)
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

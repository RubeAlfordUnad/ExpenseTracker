import Foundation

struct ImportedExpenseMergeResult {
    let expenses: [Expense]
    let inserted: Int
    let duplicates: Int
    let invalidFinancialRows: Int
}

struct ImportedExpenseMergeService {

    private let fundingSync = ExpenseFundingSync()
    private let financialGuard = ImportedExpenseFinancialGuard()
    private let duplicateFingerprintBuilder = ImportedExpenseDuplicateFingerprintBuilder()

    func merge(
        existingExpenses: [Expense],
        importedExpenses: [Expense],
        accounts: inout [MoneyAccount],
        debts: inout [Debt]
    ) -> ImportedExpenseMergeResult {
        let validAccountIds = Set(accounts.map(\.id))
        let validDebtIds = Set(debts.map(\.id))

        var merged = existingExpenses
        var inserted = 0
        var duplicates = 0
        var invalidFinancialRows = 0

        var existingBuckets = makeBuckets(from: existingExpenses)

        for rawExpense in importedExpenses {
            let expense = sanitizeFundingReferences(
                for: rawExpense,
                validAccountIds: validAccountIds,
                validDebtIds: validDebtIds
            )

            let fingerprint = duplicateFingerprintBuilder.fingerprint(for: expense)

            if isDuplicate(fingerprint, existingBuckets: existingBuckets) {
                duplicates += 1
                continue
            }

            if financialGuard.wouldCreateInvalidState(
                expense: expense,
                accounts: accounts,
                debts: debts
            ) {
                invalidFinancialRows += 1
                continue
            }

            merged.append(expense)
            register(fingerprint, in: &existingBuckets)
            fundingSync.applyNewExpense(expense, accounts: &accounts, debts: &debts)
            inserted += 1
        }

        merged.sort { $0.date > $1.date }

        return ImportedExpenseMergeResult(
            expenses: merged,
            inserted: inserted,
            duplicates: duplicates,
            invalidFinancialRows: invalidFinancialRows
        )
    }

    func sanitizeFundingReferences(
        for expense: Expense,
        validAccountIds: Set<UUID>,
        validDebtIds: Set<UUID>
    ) -> Expense {
        let validCreditCardId = expense.creditCardId.flatMap { validDebtIds.contains($0) ? $0 : nil }
        let validMoneyAccountId = expense.moneyAccountId.flatMap { validAccountIds.contains($0) ? $0 : nil }

        let resolvedCreditCardId = validCreditCardId
        let resolvedMoneyAccountId = resolvedCreditCardId == nil ? validMoneyAccountId : nil

        return Expense(
            id: expense.id,
            title: expense.title,
            amount: expense.amount,
            date: expense.date,
            category: expense.category,
            customCategoryName: expense.customCategoryName,
            moneyAccountId: resolvedMoneyAccountId,
            creditCardId: resolvedCreditCardId,
            comment: expense.comment
        )
    }

    private func makeBuckets(from expenses: [Expense]) -> [String: Set<ImportedExpenseDuplicateFingerprint>] {
        var buckets: [String: Set<ImportedExpenseDuplicateFingerprint>] = [:]

        for expense in expenses {
            let fingerprint = duplicateFingerprintBuilder.fingerprint(for: expense)
            buckets[fingerprint.primaryKey, default: []].insert(fingerprint)
        }

        return buckets
    }

    private func register(
        _ fingerprint: ImportedExpenseDuplicateFingerprint,
        in buckets: inout [String: Set<ImportedExpenseDuplicateFingerprint>]
    ) {
        buckets[fingerprint.primaryKey, default: []].insert(fingerprint)
    }

    private func isDuplicate(
        _ fingerprint: ImportedExpenseDuplicateFingerprint,
        existingBuckets: [String: Set<ImportedExpenseDuplicateFingerprint>]
    ) -> Bool {
        guard let bucket = existingBuckets[fingerprint.primaryKey], !bucket.isEmpty else {
            return false
        }

        if bucket.contains(fingerprint) {
            return true
        }

        if bucket.count == 1, let existing = bucket.first {
            if !fingerprint.hasDisambiguators || !existing.hasDisambiguators {
                return true
            }
        }

        return false
    }
}

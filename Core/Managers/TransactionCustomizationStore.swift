import Foundation

final class TransactionCustomizationStore {

    static let shared = TransactionCustomizationStore()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Expense Categories

    func loadExpenseCustomCategories(user: String) -> [CustomExpenseCategory] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        let items = decode([CustomExpenseCategory].self, forKey: expenseCustomCategoriesKey(for: cleanUser)) ?? []
        return normalizedExpenseCustomCategories(items)
    }

    func saveExpenseCustomCategories(_ items: [CustomExpenseCategory], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        let normalized = normalizedExpenseCustomCategories(items)

        if normalized.isEmpty {
            defaults.removeObject(forKey: expenseCustomCategoriesKey(for: cleanUser))
            return
        }

        encode(normalized, forKey: expenseCustomCategoriesKey(for: cleanUser))
    }

    // MARK: - Income Categories

    func loadIncomeCustomCategories(user: String) -> [CustomIncomeCategory] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        let items = decode([CustomIncomeCategory].self, forKey: incomeCustomCategoriesKey(for: cleanUser)) ?? []
        return normalizedIncomeCustomCategories(items)
    }

    func saveIncomeCustomCategories(_ items: [CustomIncomeCategory], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        let normalized = normalizedIncomeCustomCategories(items)

        if normalized.isEmpty {
            defaults.removeObject(forKey: incomeCustomCategoriesKey(for: cleanUser))
            return
        }

        encode(normalized, forKey: incomeCustomCategoriesKey(for: cleanUser))
    }
    
    // MARK: - Money Account Categories

    func loadMoneyAccountCustomCategories(user: String) -> [CustomMoneyAccountCategory] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        let items = decode([CustomMoneyAccountCategory].self, forKey: moneyAccountCustomCategoriesKey(for: cleanUser)) ?? []
        return normalizedMoneyAccountCustomCategories(items)
    }

    func saveMoneyAccountCustomCategories(_ items: [CustomMoneyAccountCategory], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        let normalized = normalizedMoneyAccountCustomCategories(items)

        if normalized.isEmpty {
            defaults.removeObject(forKey: moneyAccountCustomCategoriesKey(for: cleanUser))
            return
        }

        encode(normalized, forKey: moneyAccountCustomCategoriesKey(for: cleanUser))
    }

    // MARK: - Expense Metadata

    func saveExpenseMetadata(from expenses: [Expense], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        var payload: [String: StoredExpenseMetadata] = [:]

        for expense in expenses {
            let customCategoryName = normalizedText(expense.customCategoryName)
            let comment = normalizedText(expense.comment)
            let creditCardId = expense.creditCardId

            guard customCategoryName != nil || comment != nil || creditCardId != nil else { continue }

            payload[expense.id.uuidString] = StoredExpenseMetadata(
                customCategoryName: customCategoryName,
                comment: comment,
                creditCardId: creditCardId
            )
        }

        if payload.isEmpty {
            defaults.removeObject(forKey: expenseMetadataKey(for: cleanUser))
            return
        }

        encode(payload, forKey: expenseMetadataKey(for: cleanUser))
    }

    func mergeExpenseMetadata(into expenses: [Expense], user: String) -> [Expense] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return expenses }

        let payload = decode([String: StoredExpenseMetadata].self, forKey: expenseMetadataKey(for: cleanUser)) ?? [:]

        return expenses.map { expense in
            guard let metadata = payload[expense.id.uuidString] else {
                return expense
            }

            return Expense(
                id: expense.id,
                title: expense.title,
                amount: expense.amount,
                date: expense.date,
                category: expense.category,
                customCategoryName: metadata.customCategoryName ?? expense.customCategoryName,
                moneyAccountId: expense.moneyAccountId,
                creditCardId: metadata.creditCardId ?? expense.creditCardId,
                comment: metadata.comment ?? expense.comment
            )
        }
    }

    // MARK: - Income Metadata

    func saveIncomeMetadata(from incomes: [Income], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        var payload: [String: StoredIncomeMetadata] = [:]

        for income in incomes {
            let customCategoryName = normalizedText(income.customCategoryName)
            let comment = normalizedText(income.comment)

            guard customCategoryName != nil || comment != nil else { continue }

            payload[income.id.uuidString] = StoredIncomeMetadata(
                customCategoryName: customCategoryName,
                comment: comment
            )
        }

        if payload.isEmpty {
            defaults.removeObject(forKey: incomeMetadataKey(for: cleanUser))
            return
        }

        encode(payload, forKey: incomeMetadataKey(for: cleanUser))
    }

    func mergeIncomeMetadata(into incomes: [Income], user: String) -> [Income] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return incomes }

        let payload = decode([String: StoredIncomeMetadata].self, forKey: incomeMetadataKey(for: cleanUser)) ?? [:]

        return incomes.map { income in
            guard let metadata = payload[income.id.uuidString] else {
                return income
            }

            return Income(
                id: income.id,
                title: income.title,
                amount: income.amount,
                date: income.date,
                category: income.category,
                customCategoryName: metadata.customCategoryName ?? income.customCategoryName,
                moneyAccountId: income.moneyAccountId,
                comment: metadata.comment ?? income.comment
            )
        }
    }
    
    // MARK: - Cleanup

    func deleteAllData(for user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        [
                expenseCustomCategoriesKey(for: cleanUser),
                incomeCustomCategoriesKey(for: cleanUser),
                moneyAccountCustomCategoriesKey(for: cleanUser),
                expenseMetadataKey(for: cleanUser),
                incomeMetadataKey(for: cleanUser)
        ]
            .forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - Helpers

    private struct StoredExpenseMetadata: Codable {
        let customCategoryName: String?
        let comment: String?
        let creditCardId: UUID?
    }
    
    private func moneyAccountCustomCategoriesKey(for user: String) -> String {
        "moneyAccountCustomCategories_\(user)"
    }

    private struct StoredIncomeMetadata: Codable {
        let customCategoryName: String?
        let comment: String?
    }

    private func sanitizeUser(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func expenseCustomCategoriesKey(for user: String) -> String {
        "expenseCustomCategories_\(user)"
    }

    private func incomeCustomCategoriesKey(for user: String) -> String {
        "incomeCustomCategories_\(user)"
    }

    private func expenseMetadataKey(for user: String) -> String {
        "expenseMetadata_\(user)"
    }

    private func incomeMetadataKey(for user: String) -> String {
        "incomeMetadata_\(user)"
    }

    private func normalizedExpenseCustomCategories(_ items: [CustomExpenseCategory]) -> [CustomExpenseCategory] {
        var seen: Set<String> = []

        return items.compactMap { item in
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }

            seen.insert(key)
            return CustomExpenseCategory(id: item.id, name: trimmed, style: item.style)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func normalizedMoneyAccountCustomCategories(_ items: [CustomMoneyAccountCategory]) -> [CustomMoneyAccountCategory] {
        var seen: Set<String> = []

        return items.compactMap { item in
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }

            seen.insert(key)
            return CustomMoneyAccountCategory(id: item.id, name: trimmed, style: item.style)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    
    private func normalizedIncomeCustomCategories(_ items: [CustomIncomeCategory]) -> [CustomIncomeCategory] {
        var seen: Set<String> = []

        return items.compactMap { item in
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }

            seen.insert(key)
            return CustomIncomeCategory(id: item.id, name: trimmed, style: item.style)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.debug("Error codificando personalización para \(key): \(error)")
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            AppLogger.debug("Error decodificando personalización para \(key): \(error)")
            return nil
        }
    }
}

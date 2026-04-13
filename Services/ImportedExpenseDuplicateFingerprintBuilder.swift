import Foundation

struct ImportedExpenseDuplicateFingerprint: Hashable {
    let primaryKey: String
    let enrichedKey: String
    let hasDisambiguators: Bool
}

struct ImportedExpenseDuplicateFingerprintBuilder {

    func fingerprint(for expense: Expense) -> ImportedExpenseDuplicateFingerprint {
        let normalizedTitle = normalizedText(expense.title)
        let normalizedCategory = normalizedCategoryKey(for: expense)
        let normalizedComment = normalizedOptionalText(expense.comment)
        let fundingKey = normalizedFundingKey(for: expense)

        let primaryKey = [
            normalizedTitle,
            amountKey(expense.amount),
            dayKey(expense.date),
            normalizedCategory
        ].joined(separator: "|")

        let enrichedKey = [
            primaryKey,
            fundingKey,
            normalizedComment
        ].joined(separator: "|")

        let hasDisambiguators = fundingKey != "none" || !normalizedComment.isEmpty

        return ImportedExpenseDuplicateFingerprint(
            primaryKey: primaryKey,
            enrichedKey: enrichedKey,
            hasDisambiguators: hasDisambiguators
        )
    }

    private func normalizedCategoryKey(for expense: Expense) -> String {
        if let customCategoryName = expense.customCategoryName,
           !customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "custom:\(normalizedText(customCategoryName))"
        }

        return "base:\(normalizedText(expense.category.rawValue))"
    }

    private func normalizedFundingKey(for expense: Expense) -> String {
        if expense.creditCardId != nil { return "credit" }
        if expense.moneyAccountId != nil { return "account" }
        return "none"
    }

    private func normalizedOptionalText(_ text: String?) -> String {
        guard let text else { return "" }
        return normalizedText(text)
    }

    private func normalizedText(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        let scalarView = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            } else {
                return " "
            }
        }

        return String(scalarView)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func amountKey(_ amount: Double) -> String {
        let cents = Int((amount * 100).rounded())
        return String(cents)
    }

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

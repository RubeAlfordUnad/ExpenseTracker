import Foundation

struct AccountTransfer: Identifiable, Codable, Equatable {
    var id = UUID()
    var fromAccountId: UUID
    var toAccountId: UUID
    var amount: Double
    var date: Date
    var note: String?

    init(
        id: UUID = UUID(),
        fromAccountId: UUID,
        toAccountId: UUID,
        amount: Double,
        date: Date,
        note: String? = nil
    ) {
        self.id = id
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.amount = amount
        self.date = date
        self.note = Self.normalizedText(note)
    }

    var normalizedNote: String? {
        Self.normalizedText(note)
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

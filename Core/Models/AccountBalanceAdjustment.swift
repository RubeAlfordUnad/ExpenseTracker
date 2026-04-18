import Foundation

struct AccountBalanceAdjustment: Identifiable, Codable, Equatable {
    var id: UUID
    var moneyAccountId: UUID
    var amount: Double
    var date: Date
    var reason: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        moneyAccountId: UUID,
        amount: Double,
        date: Date = Date(),
        reason: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.moneyAccountId = moneyAccountId
        self.amount = Self.normalizedAmount(amount)
        self.date = date
        self.reason = Self.normalizedReason(reason)
        self.createdAt = createdAt
    }

    var normalizedReason: String? {
        Self.normalizedReason(reason)
    }

    var isZeroEffect: Bool {
        abs(amount) < 0.0001
    }

    private static func normalizedAmount(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return abs(value) < 0.0001 ? 0 : value
    }

    private static func normalizedReason(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

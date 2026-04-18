import Foundation
import SwiftUI

enum MoneyAccountKind: String, CaseIterable, Codable {
    case cash = "cash"
    case checking = "checking"
    case savings = "savings"
    case digitalWallet = "digitalWallet"
    case investment = "investment"
    case other = "other"

    var icon: String {
        switch self {
        case .cash:
            return "banknote"
        case .checking:
            return "building.columns"
        case .savings:
            return "tray.full"
        case .digitalWallet:
            return "iphone.gen3"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        case .other:
            return "wallet.pass"
        }
    }

    var color: Color {
        switch self {
        case .cash:
            return .green
        case .checking:
            return .blue
        case .savings:
            return .mint
        case .digitalWallet:
            return .purple
        case .investment:
            return .orange
        case .other:
            return .gray
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.cash, .spanish): return "Efectivo"
        case (.checking, .spanish): return "Cuenta corriente"
        case (.savings, .spanish): return "Ahorros"
        case (.digitalWallet, .spanish): return "Billetera digital"
        case (.investment, .spanish): return "Inversión"
        case (.other, .spanish): return "Otra"

        case (.cash, .english): return "Cash"
        case (.checking, .english): return "Checking"
        case (.savings, .english): return "Savings"
        case (.digitalWallet, .english): return "Digital wallet"
        case (.investment, .english): return "Investment"
        case (.other, .english): return "Other"
        }
    }
}

struct MoneyAccount: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var balance: Double
    var kind: MoneyAccountKind
    var customCategoryName: String?
    var includeInAvailableTotal: Bool

    /// Foto base del saldo con la que arrancó la cuenta dentro de la app.
    /// Es opcional para mantener compatibilidad con datos viejos.
    var openingBalance: Double?
    var openingBalanceDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        balance: Double,
        kind: MoneyAccountKind,
        customCategoryName: String? = nil,
        includeInAvailableTotal: Bool = true,
        openingBalance: Double? = nil,
        openingBalanceDate: Date? = nil
    ) {
        self.id = id
        self.name = Self.normalizedName(name)
        self.balance = balance
        self.kind = kind
        self.customCategoryName = Self.normalizedText(customCategoryName)
        self.includeInAvailableTotal = includeInAvailableTotal
        self.openingBalance = Self.normalizedOptionalNonNegativeAmount(openingBalance)
        self.openingBalanceDate = openingBalanceDate
    }

    func categoryDisplayName(language: AppLanguage) -> String {
        normalizedCustomCategoryName ?? kind.displayName(language: language)
    }

    var normalizedCustomCategoryName: String? {
        Self.normalizedText(customCategoryName)
    }

    var hasCustomCategory: Bool {
        normalizedCustomCategoryName != nil
    }

    var hasOpeningSnapshot: Bool {
        openingBalance != nil || openingBalanceDate != nil
    }

    var resolvedOpeningBalance: Double? {
        Self.normalizedOptionalNonNegativeAmount(openingBalance)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case balance
        case kind
        case customCategoryName
        case includeInAvailableTotal
        case openingBalance
        case openingBalanceDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = Self.normalizedName(try container.decode(String.self, forKey: .name))
        balance = try container.decode(Double.self, forKey: .balance)
        kind = try container.decode(MoneyAccountKind.self, forKey: .kind)
        customCategoryName = Self.normalizedText(
            try container.decodeIfPresent(String.self, forKey: .customCategoryName)
        )
        includeInAvailableTotal = try container.decodeIfPresent(Bool.self, forKey: .includeInAvailableTotal) ?? true
        openingBalance = Self.normalizedOptionalNonNegativeAmount(
            try container.decodeIfPresent(Double.self, forKey: .openingBalance)
        )
        openingBalanceDate = try container.decodeIfPresent(Date.self, forKey: .openingBalanceDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(balance, forKey: .balance)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(normalizedCustomCategoryName, forKey: .customCategoryName)
        try container.encode(includeInAvailableTotal, forKey: .includeInAvailableTotal)
        try container.encodeIfPresent(resolvedOpeningBalance, forKey: .openingBalance)
        try container.encodeIfPresent(openingBalanceDate, forKey: .openingBalanceDate)
    }

    private static func normalizedName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? value : trimmed
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedOptionalNonNegativeAmount(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        guard value >= 0 else { return nil }
        return value
    }
}

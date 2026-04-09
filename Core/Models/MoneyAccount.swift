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

    init(
        id: UUID = UUID(),
        name: String,
        balance: Double,
        kind: MoneyAccountKind,
        customCategoryName: String? = nil,
        includeInAvailableTotal: Bool = true
    ) {
        self.id = id
        self.name = Self.normalizedName(name)
        self.balance = balance
        self.kind = kind
        self.customCategoryName = Self.normalizedText(customCategoryName)
        self.includeInAvailableTotal = includeInAvailableTotal
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

    private static func normalizedName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? value : trimmed
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

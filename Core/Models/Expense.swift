import Foundation
import SwiftUI

enum Category: String, CaseIterable, Codable {
    case food = "Comida"
    case transport = "Transporte"
    case entertainment = "Entretenimiento"
    case bills = "Facturas"
    case housing = "Vivienda"
    case health = "Salud"
    case shopping = "Compras"
    case education = "Educación"
    case subscriptions = "Suscripciones"
    case personalCare = "Cuidado personal"
    case travel = "Viajes"
    case gifts = "Regalos"
    case other = "Otros"

    var color: Color {
        switch self {
        case .food:
            return .orange
        case .transport:
            return .blue
        case .entertainment:
            return .purple
        case .bills:
            return .red
        case .housing:
            return .brown
        case .health:
            return .pink
        case .shopping:
            return .indigo
        case .education:
            return .mint
        case .subscriptions:
            return .cyan
        case .personalCare:
            return .teal
        case .travel:
            return .green
        case .gifts:
            return .yellow
        case .other:
            return .gray
        }
    }

    var icon: String {
        switch self {
        case .food:
            return "fork.knife"
        case .transport:
            return "car.fill"
        case .entertainment:
            return "gamecontroller.fill"
        case .bills:
            return "doc.text.fill"
        case .housing:
            return "house.fill"
        case .health:
            return "cross.case.fill"
        case .shopping:
            return "bag.fill"
        case .education:
            return "book.fill"
        case .subscriptions:
            return "play.rectangle.fill"
        case .personalCare:
            return "heart.text.square.fill"
        case .travel:
            return "airplane"
        case .gifts:
            return "gift.fill"
        case .other:
            return "square.grid.2x2.fill"
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.food, .spanish): return "Comida"
        case (.transport, .spanish): return "Transporte"
        case (.entertainment, .spanish): return "Entretenimiento"
        case (.bills, .spanish): return "Facturas"
        case (.housing, .spanish): return "Vivienda"
        case (.health, .spanish): return "Salud"
        case (.shopping, .spanish): return "Compras"
        case (.education, .spanish): return "Educación"
        case (.subscriptions, .spanish): return "Suscripciones"
        case (.personalCare, .spanish): return "Cuidado personal"
        case (.travel, .spanish): return "Viajes"
        case (.gifts, .spanish): return "Regalos"
        case (.other, .spanish): return "Otros"

        case (.food, .english): return "Food"
        case (.transport, .english): return "Transport"
        case (.entertainment, .english): return "Entertainment"
        case (.bills, .english): return "Bills"
        case (.housing, .english): return "Housing"
        case (.health, .english): return "Health"
        case (.shopping, .english): return "Shopping"
        case (.education, .english): return "Education"
        case (.subscriptions, .english): return "Subscriptions"
        case (.personalCare, .english): return "Personal care"
        case (.travel, .english): return "Travel"
        case (.gifts, .english): return "Gifts"
        case (.other, .english): return "Other"
        }
    }
}

struct Expense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var date: Date
    var category: Category
    var customCategoryName: String?
    var moneyAccountId: UUID?
    var comment: String?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date,
        category: Category,
        customCategoryName: String? = nil,
        moneyAccountId: UUID? = nil,
        comment: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.customCategoryName = Self.normalizedText(customCategoryName)
        self.moneyAccountId = moneyAccountId
        self.comment = Self.normalizedText(comment)
    }

    func categoryDisplayName(language: AppLanguage) -> String {
        let trimmed = customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? category.displayName(language: language) : trimmed
    }

    var normalizedComment: String? {
        Self.normalizedText(comment)
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

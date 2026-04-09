import Foundation
import SwiftUI

enum IncomeCategory: String, CaseIterable, Codable {
    case salary = "Salario"
    case freelance = "Freelance"
    case business = "Negocio"
    case gift = "Regalo"
    case other = "Otros"

    var color: Color {
        switch self {
        case .salary:
            return .green
        case .freelance:
            return .blue
        case .business:
            return .teal
        case .gift:
            return .pink
        case .other:
            return .gray
        }
    }

    var icon: String {
        switch self {
        case .salary:
            return "banknote.fill"
        case .freelance:
            return "laptopcomputer"
        case .business:
            return "briefcase.fill"
        case .gift:
            return "gift.fill"
        case .other:
            return "square.grid.2x2.fill"
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.salary, .spanish): return "Salario"
        case (.freelance, .spanish): return "Freelance"
        case (.business, .spanish): return "Negocio"
        case (.gift, .spanish): return "Regalo"
        case (.other, .spanish): return "Otros"

        case (.salary, .english): return "Salary"
        case (.freelance, .english): return "Freelance"
        case (.business, .english): return "Business"
        case (.gift, .english): return "Gift"
        case (.other, .english): return "Other"
        }
    }
}

struct Income: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var amount: Double
    var date: Date
    var category: IncomeCategory
    var customCategoryName: String?
    var moneyAccountId: UUID?
    var comment: String?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date,
        category: IncomeCategory,
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

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
}

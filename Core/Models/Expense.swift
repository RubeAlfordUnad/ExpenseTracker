import Foundation
import SwiftUI

enum Category: String, CaseIterable, Codable {
    case food = "Comida"
    case transport = "Transporte"
    case entertainment = "Entretenimiento"
    case bills = "Facturas"
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
        case (.other, .spanish): return "Otros"
        case (.food, .english): return "Food"
        case (.transport, .english): return "Transport"
        case (.entertainment, .english): return "Entertainment"
        case (.bills, .english): return "Bills"
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
}

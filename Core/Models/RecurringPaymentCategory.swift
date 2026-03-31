import Foundation
import SwiftUI

enum RecurringPaymentCategory: String, CaseIterable, Codable, Identifiable {

    case housing = "Vivienda"
    case transport = "Transporte"
    case utilities = "Servicios"
    case insurance = "Seguros"
    case health = "Salud"
    case subscriptions = "Suscripciones"
    case education = "Educación"
    case loans = "Préstamos"
    case other = "Otros"

    var id: String { rawValue }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.housing, .spanish): return "Vivienda"
        case (.transport, .spanish): return "Transporte"
        case (.utilities, .spanish): return "Servicios"
        case (.insurance, .spanish): return "Seguros"
        case (.health, .spanish): return "Salud"
        case (.subscriptions, .spanish): return "Suscripciones"
        case (.education, .spanish): return "Educación"
        case (.loans, .spanish): return "Préstamos"
        case (.other, .spanish): return "Otros"
        case (.housing, .english): return "Housing"
        case (.transport, .english): return "Transport"
        case (.utilities, .english): return "Utilities"
        case (.insurance, .english): return "Insurance"
        case (.health, .english): return "Health"
        case (.subscriptions, .english): return "Subscriptions"
        case (.education, .english): return "Education"
        case (.loans, .english): return "Loans"
        case (.other, .english): return "Other"
        }
    }

    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .transport: return "car.fill"
        case .utilities: return "bolt.fill"
        case .insurance: return "shield.fill"
        case .health: return "cross.case.fill"
        case .subscriptions: return "play.rectangle.fill"
        case .education: return "book.fill"
        case .loans: return "creditcard.fill"
        case .other: return "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .housing: return BrandPalette.primary
        case .transport: return .teal
        case .utilities: return BrandPalette.secondary
        case .insurance: return .indigo
        case .health: return .red
        case .subscriptions: return .purple
        case .education: return .mint
        case .loans: return .orange
        case .other: return .gray
        }
    }
}

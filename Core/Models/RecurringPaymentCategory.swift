import Foundation

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
}

import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }

    var localeCode: String { rawValue }
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func title(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.system, .spanish): return "Sistema"
        case (.light, .spanish): return "Claro"
        case (.dark, .spanish): return "Oscuro"
        case (.system, .english): return "System"
        case (.light, .english): return "Light"
        case (.dark, .english): return "Dark"
        }
    }
}

enum AppCurrency: String, CaseIterable, Identifiable, Codable {
    case cop = "COP"
    case usd = "USD"
    case eur = "EUR"
    case mxn = "MXN"
    case pen = "PEN"
    case clp = "CLP"
    case ars = "ARS"
    case brl = "BRL"
    case gbp = "GBP"

    var id: String { rawValue }

    var isSupportedByExchangeAPI: Bool {
        switch self {
        case .usd, .eur, .mxn, .brl, .gbp:
            return true
        case .cop, .pen, .clp, .ars:
            return false
        }
    }

    func title(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.cop, .spanish): return "Peso colombiano"
        case (.usd, .spanish): return "Dólar estadounidense"
        case (.eur, .spanish): return "Euro"
        case (.mxn, .spanish): return "Peso mexicano"
        case (.pen, .spanish): return "Sol peruano"
        case (.clp, .spanish): return "Peso chileno"
        case (.ars, .spanish): return "Peso argentino"
        case (.brl, .spanish): return "Real brasileño"
        case (.gbp, .spanish): return "Libra esterlina"
        case (.cop, .english): return "Colombian Peso"
        case (.usd, .english): return "US Dollar"
        case (.eur, .english): return "Euro"
        case (.mxn, .english): return "Mexican Peso"
        case (.pen, .english): return "Peruvian Sol"
        case (.clp, .english): return "Chilean Peso"
        case (.ars, .english): return "Argentine Peso"
        case (.brl, .english): return "Brazilian Real"
        case (.gbp, .english): return "British Pound"
        }
    }
}

enum AppCountry: String, CaseIterable, Identifiable, Codable {
    case colombia
    case unitedStates
    case mexico
    case spain
    case peru
    case chile
    case argentina
    case brazil

    var id: String { rawValue }

    var regionCode: String {
        switch self {
        case .colombia: return "CO"
        case .unitedStates: return "US"
        case .mexico: return "MX"
        case .spain: return "ES"
        case .peru: return "PE"
        case .chile: return "CL"
        case .argentina: return "AR"
        case .brazil: return "BR"
        }
    }

    var flag: String {
        switch self {
        case .colombia: return "🇨🇴"
        case .unitedStates: return "🇺🇸"
        case .mexico: return "🇲🇽"
        case .spain: return "🇪🇸"
        case .peru: return "🇵🇪"
        case .chile: return "🇨🇱"
        case .argentina: return "🇦🇷"
        case .brazil: return "🇧🇷"
        }
    }

    var defaultCurrency: AppCurrency {
        switch self {
        case .colombia: return .cop
        case .unitedStates: return .usd
        case .mexico: return .mxn
        case .spain: return .eur
        case .peru: return .pen
        case .chile: return .clp
        case .argentina: return .ars
        case .brazil: return .brl
        }
    }

    func title(for language: AppLanguage) -> String {
        switch (self, language) {
        case (.colombia, .spanish): return "Colombia"
        case (.unitedStates, .spanish): return "Estados Unidos"
        case (.mexico, .spanish): return "México"
        case (.spain, .spanish): return "España"
        case (.peru, .spanish): return "Perú"
        case (.chile, .spanish): return "Chile"
        case (.argentina, .spanish): return "Argentina"
        case (.brazil, .spanish): return "Brasil"
        case (.colombia, .english): return "Colombia"
        case (.unitedStates, .english): return "United States"
        case (.mexico, .english): return "Mexico"
        case (.spain, .english): return "Spain"
        case (.peru, .english): return "Peru"
        case (.chile, .english): return "Chile"
        case (.argentina, .english): return "Argentina"
        case (.brazil, .english): return "Brazil"
        }
    }
}

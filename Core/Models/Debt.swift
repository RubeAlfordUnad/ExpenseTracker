import Foundation

enum CardBrand: String, CaseIterable, Codable, Identifiable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case other = "Otra"

    var id: String { rawValue }

    var logoName: String {
        switch self {
        case .visa:
            return "visa_logo"
        case .mastercard:
            return "mastercard_logo"
        case .amex:
            return "amex_logo"
        case .other:
            return "creditcard"
        }
    }

    var systemImageName: String {
        switch self {
        case .visa:
            return "creditcard.fill"
        case .mastercard:
            return "creditcard.and.123"
        case .amex:
            return "creditcard.trianglebadge.exclamationmark"
        case .other:
            return "creditcard"
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.visa, _):
            return "Visa"
        case (.mastercard, .spanish):
            return "Mastercard"
        case (.mastercard, .english):
            return "Mastercard"
        case (.amex, .spanish):
            return "American Express"
        case (.amex, .english):
            return "American Express"
        case (.other, .spanish):
            return "Otra"
        case (.other, .english):
            return "Other"
        }
    }
}

struct Debt: Identifiable, Codable, Equatable {
    var id = UUID()
    var cardName: String
    var brand: CardBrand
    var totalLimit: Double
    var remainingDebt: Double
    
    var availableCredit: Double {
        let value = totalLimit - remainingDebt
        guard value.isFinite else { return 0 }
        return max(value, 0)
    }
    
    var utilization: Double {
        guard totalLimit.isFinite,
              remainingDebt.isFinite,
              totalLimit > 0 else {
            return 0
        }
        
        let raw = remainingDebt / totalLimit
        guard raw.isFinite else { return 0 }
        
        return min(max(raw, 0), 1)
    }
    
    var utilizationPercentage: Int {
        Int((utilization * 100).rounded())
    }
}

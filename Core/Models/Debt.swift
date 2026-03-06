//
//  debt.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//

import Foundation

enum CardBrand: String, CaseIterable, Codable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case other = "Otra"
    
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
}

struct Debt: Identifiable, Codable, Equatable {
    var id = UUID()
    var cardName: String
    var brand: CardBrand
    var totalLimit: Double
    var remainingDebt: Double
}

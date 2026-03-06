//
//  Expense.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 26/02/26.
//

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
}

struct Expense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var date: Date
    var category: Category
}

//
//  debt.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//

import Foundation

struct Debt: Identifiable, Codable {
    var id = UUID()
    var name: String
    var totalAmount: Double
    var remainingAmount: Double
}

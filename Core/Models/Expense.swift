//
//  Expense.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 26/02/26.
//

import Foundation

enum Category: String, CaseIterable, Codable {
    case food = "Food"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case bills = "Bills"
    case other = "Other"
}

struct Expense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var date: Date
    var category: Category
}

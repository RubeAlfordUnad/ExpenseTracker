//
//  DataManager.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//

import Foundation
import SwiftUI

class DataManager {
    
    
    static let shared = DataManager()
    
    private init() {}
    
    private let expensesKey = "expenses"
    private let debtsKey = "debts"
    
    // MARK: EXPENSES
    
    func saveExpenses(_ expenses: [Expense]) {
        if let encoded = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(encoded, forKey: expensesKey)
        }
    }
    
    func loadExpenses() -> [Expense] {
        if let data = UserDefaults.standard.data(forKey: expensesKey),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            return decoded
        }
        return []
    }
    
    // MARK: DEBTS
    
    func saveDebts(_ debts: [Debt]) {
        if let encoded = try? JSONEncoder().encode(debts) {
            UserDefaults.standard.set(encoded, forKey: debtsKey)
        }
    }
    
    func loadDebts() -> [Debt] {
        if let data = UserDefaults.standard.data(forKey: debtsKey),
           let decoded = try? JSONDecoder().decode([Debt].self, from: data) {
            return decoded
        }
        return []
    }
}

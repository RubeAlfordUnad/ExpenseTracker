//
//  DataManager.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 1/03/26.
//

import Foundation

class DataManager {
    
    static let shared = DataManager()
    
    private init() {}
    
    // MARK: - Keys
    private func expensesKey(for user: String) -> String {
        "expenses_\(user)"
    }
    
    private func debtsKey(for user: String) -> String {
        "debts_\(user)"
    }
    
    private func recurringPaymentsKey(for user: String) -> String {
        "recurringPayments_\(user)"
    }
    
    private func budgetKey(for user: String) -> String {
        "monthlyBudget_\(user)"
    }
    
    // MARK: - Expenses
    func saveExpenses(_ expenses: [Expense], user: String) {
        if let encoded = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(encoded, forKey: expensesKey(for: user))
        }
    }
    
    func loadExpenses(user: String) -> [Expense] {
        guard let data = UserDefaults.standard.data(forKey: expensesKey(for: user)),
              let decoded = try? JSONDecoder().decode([Expense].self, from: data) else {
            return []
        }
        return decoded
    }
    
    // MARK: - Debts
    func saveDebts(_ debts: [Debt], user: String) {
        if let encoded = try? JSONEncoder().encode(debts) {
            UserDefaults.standard.set(encoded, forKey: debtsKey(for: user))
        }
    }
    
    func loadDebts(user: String) -> [Debt] {
        guard let data = UserDefaults.standard.data(forKey: debtsKey(for: user)),
              let decoded = try? JSONDecoder().decode([Debt].self, from: data) else {
            return []
        }
        return decoded
    }
    
    // MARK: - Recurring Payments
    func saveRecurringPayments(_ payments: [RecurringPayment], user: String) {
        if let encoded = try? JSONEncoder().encode(payments) {
            UserDefaults.standard.set(encoded, forKey: recurringPaymentsKey(for: user))
        }
    }
    
    func loadRecurringPayments(user: String) -> [RecurringPayment] {
        guard let data = UserDefaults.standard.data(forKey: recurringPaymentsKey(for: user)),
              let decoded = try? JSONDecoder().decode([RecurringPayment].self, from: data) else {
            return []
        }
        return decoded
    }
    
    // MARK: - Monthly Budget
    func saveMonthlyBudget(_ budget: MonthlyBudget, user: String) {
        if let encoded = try? JSONEncoder().encode(budget) {
            UserDefaults.standard.set(encoded, forKey: budgetKey(for: user))
        }
    }
    
    func loadMonthlyBudget(user: String) -> MonthlyBudget? {
        guard let data = UserDefaults.standard.data(forKey: budgetKey(for: user)),
              let decoded = try? JSONDecoder().decode(MonthlyBudget.self, from: data) else {
            return nil
        }
        return decoded
    }
}

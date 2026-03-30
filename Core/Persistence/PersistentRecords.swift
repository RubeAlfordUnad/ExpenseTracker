//
//  PersistentRecords.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 21/03/26.
//

import Foundation
import SwiftData

@Model
final class StoredExpense {
    @Attribute(.unique) var id: UUID
    var user: String
    var title: String
    var amount: Double
    var date: Date
    var categoryRawValue: String

    init(expense: Expense, user: String) {
        self.id = expense.id
        self.user = user
        self.title = expense.title
        self.amount = expense.amount
        self.date = expense.date
        self.categoryRawValue = expense.category.rawValue
    }

    func toExpense() -> Expense {
        Expense(
            id: id,
            title: title,
            amount: amount,
            date: date,
            category: Category(rawValue: categoryRawValue) ?? .other
        )
    }
}

@Model
final class StoredDebt {
    @Attribute(.unique) var id: UUID
    var user: String
    var cardName: String
    var brandRawValue: String
    var totalLimit: Double
    var remainingDebt: Double

    init(debt: Debt, user: String) {
        self.id = debt.id
        self.user = user
        self.cardName = debt.cardName
        self.brandRawValue = debt.brand.rawValue
        self.totalLimit = debt.totalLimit
        self.remainingDebt = debt.remainingDebt
    }

    func toDebt() -> Debt {
        Debt(
            id: id,
            cardName: cardName,
            brand: CardBrand(rawValue: brandRawValue) ?? .other,
            totalLimit: totalLimit,
            remainingDebt: remainingDebt
        )
    }
}

@Model
final class StoredRecurringPayment {
    @Attribute(.unique) var id: UUID
    var user: String
    var title: String
    var amount: Double
    var dueDay: Int
    var categoryRawValue: String
    var isActive: Bool
    var lastPaidMonth: Int?
    var lastPaidYear: Int?

    init(payment: RecurringPayment, user: String) {
        self.id = payment.id
        self.user = user
        self.title = payment.title
        self.amount = payment.amount
        self.dueDay = payment.dueDay
        self.categoryRawValue = payment.category.rawValue
        self.isActive = payment.isActive
        self.lastPaidMonth = payment.lastPaidMonth
        self.lastPaidYear = payment.lastPaidYear
    }

    func toRecurringPayment() -> RecurringPayment {
        RecurringPayment(
            id: id,
            title: title,
            amount: amount,
            dueDay: dueDay,
            category: RecurringPaymentCategory(rawValue: categoryRawValue) ?? .other,
            isActive: isActive,
            lastPaidMonth: lastPaidMonth,
            lastPaidYear: lastPaidYear
        )
    }
}

@Model
final class StoredMonthlyBudget {
    @Attribute(.unique) var user: String
    var amount: Double

    init(user: String, amount: Double) {
        self.user = user
        self.amount = amount
    }

    func toMonthlyBudget() -> MonthlyBudget {
        MonthlyBudget(amount: amount)
    }
}

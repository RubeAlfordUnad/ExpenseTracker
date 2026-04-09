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
    var moneyAccountId: UUID?

    init(expense: Expense, user: String) {
        self.id = expense.id
        self.user = user
        self.title = expense.title
        self.amount = expense.amount
        self.date = expense.date
        self.categoryRawValue = expense.category.rawValue
        self.moneyAccountId = expense.moneyAccountId
    }

    func toExpense() -> Expense {
        Expense(
            id: id,
            title: title,
            amount: amount,
            date: date,
            category: Category(rawValue: categoryRawValue) ?? .other,
            moneyAccountId: moneyAccountId
        )
    }
}

@Model
final class StoredIncome {
    @Attribute(.unique) var id: UUID
    var user: String
    var title: String
    var amount: Double
    var date: Date
    var categoryRawValue: String
    var moneyAccountId: UUID?

    init(income: Income, user: String) {
        self.id = income.id
        self.user = user
        self.title = income.title
        self.amount = income.amount
        self.date = income.date
        self.categoryRawValue = income.category.rawValue
        self.moneyAccountId = income.moneyAccountId
    }

    func toIncome() -> Income {
        Income(
            id: id,
            title: title,
            amount: amount,
            date: date,
            category: IncomeCategory(rawValue: categoryRawValue) ?? .other,
            moneyAccountId: moneyAccountId
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
final class StoredMoneyAccount {
    @Attribute(.unique) var id: UUID
    var user: String
    var name: String
    var balance: Double
    var kindRawValue: String
    var customCategoryName: String?
    var includeInAvailableTotal: Bool

    init(account: MoneyAccount, user: String) {
        self.id = account.id
        self.user = user
        self.name = account.name
        self.balance = account.balance
        self.kindRawValue = account.kind.rawValue
        self.customCategoryName = account.customCategoryName
        self.includeInAvailableTotal = account.includeInAvailableTotal
    }

    func toMoneyAccount() -> MoneyAccount {
        MoneyAccount(
            id: id,
            name: name,
            balance: balance,
            kind: MoneyAccountKind(rawValue: kindRawValue) ?? .other,
            customCategoryName: customCategoryName,
            includeInAvailableTotal: includeInAvailableTotal
        )
    }
}

@Model
final class StoredAccountTransfer {
    @Attribute(.unique) var id: UUID
    var user: String
    var fromAccountId: UUID
    var toAccountId: UUID
    var amount: Double
    var date: Date
    var note: String?

    init(transfer: AccountTransfer, user: String) {
        self.id = transfer.id
        self.user = user
        self.fromAccountId = transfer.fromAccountId
        self.toAccountId = transfer.toAccountId
        self.amount = transfer.amount
        self.date = transfer.date
        self.note = transfer.note
    }

    func toAccountTransfer() -> AccountTransfer {
        AccountTransfer(
            id: id,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: amount,
            date: date,
            note: note
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

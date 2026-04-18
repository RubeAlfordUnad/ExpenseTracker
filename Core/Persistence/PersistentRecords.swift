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
    var customCategoryName: String?
    var isActive: Bool
    var lastPaidMonth: Int?
    var lastPaidYear: Int?
    var lastPaidExpenseId: UUID?

    init(payment: RecurringPayment, user: String) {
        self.id = payment.id
        self.user = user
        self.title = payment.title
        self.amount = payment.amount
        self.dueDay = payment.dueDay
        self.categoryRawValue = payment.category.rawValue
        self.customCategoryName = payment.customCategoryName
        self.isActive = payment.isActive
        self.lastPaidMonth = payment.lastPaidMonth
        self.lastPaidYear = payment.lastPaidYear
        self.lastPaidExpenseId = payment.lastPaidExpenseId
    }

    func toRecurringPayment() -> RecurringPayment {
        RecurringPayment(
            id: id,
            title: title,
            amount: amount,
            dueDay: dueDay,
            category: RecurringPaymentCategory(rawValue: categoryRawValue) ?? .other,
            customCategoryName: customCategoryName,
            isActive: isActive,
            lastPaidMonth: lastPaidMonth,
            lastPaidYear: lastPaidYear,
            lastPaidExpenseId: lastPaidExpenseId
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
    var openingBalance: Double?
    var openingBalanceDate: Date?

    init(account: MoneyAccount, user: String) {
        self.id = account.id
        self.user = user
        self.name = account.name
        self.balance = account.balance
        self.kindRawValue = account.kind.rawValue
        self.customCategoryName = account.customCategoryName
        self.includeInAvailableTotal = account.includeInAvailableTotal
        self.openingBalance = account.openingBalance
        self.openingBalanceDate = account.openingBalanceDate
    }

    func toMoneyAccount() -> MoneyAccount {
        MoneyAccount(
            id: id,
            name: name,
            balance: balance,
            kind: MoneyAccountKind(rawValue: kindRawValue) ?? .other,
            customCategoryName: customCategoryName,
            includeInAvailableTotal: includeInAvailableTotal,
            openingBalance: openingBalance,
            openingBalanceDate: openingBalanceDate
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
final class StoredAccountBalanceAdjustment {
    @Attribute(.unique) var id: UUID
    var user: String
    var moneyAccountId: UUID
    var amount: Double
    var date: Date
    var reason: String?
    var createdAt: Date

    init(adjustment: AccountBalanceAdjustment, user: String) {
        self.id = adjustment.id
        self.user = user
        self.moneyAccountId = adjustment.moneyAccountId
        self.amount = adjustment.amount
        self.date = adjustment.date
        self.reason = adjustment.reason
        self.createdAt = adjustment.createdAt
    }

    func toAccountBalanceAdjustment() -> AccountBalanceAdjustment {
        AccountBalanceAdjustment(
            id: id,
            moneyAccountId: moneyAccountId,
            amount: amount,
            date: date,
            reason: reason,
            createdAt: createdAt
        )
    }
}

@Model
final class StoredAuditLogEntry {
    @Attribute(.unique) var id: UUID
    var user: String
    var timestamp: Date
    var entityRawValue: String
    var entityId: UUID?
    var actionRawValue: String
    var title: String
    var detail: String
    var originalValue: String?
    var originalTimestamp: Date?
    var previousValue: String?
    var previousTimestamp: Date?
    var newValue: String?
    var newTimestamp: Date?
    var note: String?

    init(entry: AuditLogEntry, user: String) {
        self.id = entry.id
        self.user = user
        self.timestamp = entry.timestamp
        self.entityRawValue = entry.entity.rawValue
        self.entityId = entry.entityId
        self.actionRawValue = entry.action.rawValue
        self.title = entry.title
        self.detail = entry.detail
        self.originalValue = entry.originalValue
        self.originalTimestamp = entry.originalTimestamp
        self.previousValue = entry.previousValue
        self.previousTimestamp = entry.previousTimestamp
        self.newValue = entry.newValue
        self.newTimestamp = entry.newTimestamp
        self.note = entry.note
    }

    func toAuditLogEntry() -> AuditLogEntry {
        AuditLogEntry(
            id: id,
            timestamp: timestamp,
            entity: AuditLogEntity(rawValue: entityRawValue) ?? .expense,
            entityId: entityId,
            action: AuditLogAction(rawValue: actionRawValue) ?? .updated,
            title: title,
            detail: detail,
            originalValue: originalValue,
            originalTimestamp: originalTimestamp,
            previousValue: previousValue,
            previousTimestamp: previousTimestamp,
            newValue: newValue,
            newTimestamp: newTimestamp,
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

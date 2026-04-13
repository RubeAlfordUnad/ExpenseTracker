import Foundation

enum CustomCategoryMode: String, CaseIterable, Identifiable {
    case expense
    case income
    case moneyAccount
    case recurringPayment

    var id: String { rawValue }
}

struct CustomExpenseCategory: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var style: Category

    init(id: UUID = UUID(), name: String, style: Category) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.style = style
    }
}

struct CustomIncomeCategory: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var style: IncomeCategory

    init(id: UUID = UUID(), name: String, style: IncomeCategory) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.style = style
    }
}

struct CustomMoneyAccountCategory: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var style: MoneyAccountKind

    init(id: UUID = UUID(), name: String, style: MoneyAccountKind) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.style = style
    }
}

struct CustomRecurringPaymentCategory: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var style: RecurringPaymentCategory

    init(id: UUID = UUID(), name: String, style: RecurringPaymentCategory) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.style = style
    }
}

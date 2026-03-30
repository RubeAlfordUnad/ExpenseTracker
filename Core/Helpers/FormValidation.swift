import Foundation

enum FormValidationError: Identifiable, Equatable {
    case emptyExpenseTitle
    case invalidExpenseAmount

    case emptyRecurringTitle
    case invalidRecurringAmount
    case invalidRecurringDay

    case emptyCardName
    case invalidCardLimit
    case invalidCurrentDebt
    case debtExceedsLimit

    case invalidDebtPayment
    case paymentExceedsBalance

    case invalidBudget

    var id: String { String(describing: self) }

    func title(language: AppLanguage) -> String {
        switch language {
        case .spanish:
            return "Datos inválidos"
        case .english:
            return "Invalid data"
        }
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .emptyExpenseTitle:
            return language == .spanish
            ? "Escribe un título para el gasto."
            : "Enter a title for the expense."

        case .invalidExpenseAmount:
            return language == .spanish
            ? "Ingresa un monto válido mayor que cero."
            : "Enter a valid amount greater than zero."

        case .emptyRecurringTitle:
            return language == .spanish
            ? "Escribe un nombre para el pago fijo."
            : "Enter a name for the recurring payment."

        case .invalidRecurringAmount:
            return language == .spanish
            ? "Ingresa un monto válido para el pago fijo."
            : "Enter a valid recurring payment amount."

        case .invalidRecurringDay:
            return language == .spanish
            ? "El día de pago debe estar entre 1 y 31."
            : "Payment day must be between 1 and 31."

        case .emptyCardName:
            return language == .spanish
            ? "Escribe un nombre para la tarjeta."
            : "Enter a card name."

        case .invalidCardLimit:
            return language == .spanish
            ? "El cupo total debe ser mayor que cero."
            : "The total limit must be greater than zero."

        case .invalidCurrentDebt:
            return language == .spanish
            ? "La deuda actual no puede ser negativa."
            : "Current debt cannot be negative."

        case .debtExceedsLimit:
            return language == .spanish
            ? "La deuda actual no puede superar el cupo total."
            : "Current debt cannot exceed the total limit."

        case .invalidDebtPayment:
            return language == .spanish
            ? "Ingresa un pago válido mayor que cero."
            : "Enter a valid payment greater than zero."

        case .paymentExceedsBalance:
            return language == .spanish
            ? "El pago no puede superar el saldo pendiente."
            : "Payment cannot exceed the remaining balance."

        case .invalidBudget:
            return language == .spanish
            ? "Ingresa un presupuesto válido mayor que cero."
            : "Enter a valid budget greater than zero."
        }
    }
}

enum FormValidator {

    static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedPositiveAmount(from text: String) -> Double? {
        let cleaned = normalizedNumericString(from: text)

        guard let value = Double(cleaned), value > 0 else {
            return nil
        }

        return value
    }

    static func normalizedNonNegativeAmount(from text: String) -> Double? {
        let cleaned = normalizedNumericString(from: text)

        guard let value = Double(cleaned), value >= 0 else {
            return nil
        }

        return value
    }

    static func validateExpense(title: String, amount: String) -> FormValidationError? {
        if trim(title).isEmpty {
            return .emptyExpenseTitle
        }

        if normalizedPositiveAmount(from: amount) == nil {
            return .invalidExpenseAmount
        }

        return nil
    }

    static func validateRecurringPayment(title: String, amount: String, dueDay: Int) -> FormValidationError? {
        if trim(title).isEmpty {
            return .emptyRecurringTitle
        }

        if normalizedPositiveAmount(from: amount) == nil {
            return .invalidRecurringAmount
        }

        if !(1...31).contains(dueDay) {
            return .invalidRecurringDay
        }

        return nil
    }

    static func validateDebt(cardName: String, totalLimit: String, currentDebt: String) -> FormValidationError? {
        if trim(cardName).isEmpty {
            return .emptyCardName
        }

        guard let limit = normalizedPositiveAmount(from: totalLimit) else {
            return .invalidCardLimit
        }

        guard let debt = normalizedNonNegativeAmount(from: currentDebt) else {
            return .invalidCurrentDebt
        }

        if debt > limit {
            return .debtExceedsLimit
        }

        return nil
    }

    static func validateDebtPayment(payment: String, remainingDebt: Double) -> FormValidationError? {
        guard let value = normalizedPositiveAmount(from: payment) else {
            return .invalidDebtPayment
        }

        if value > remainingDebt {
            return .paymentExceedsBalance
        }

        return nil
    }

    static func validateBudget(_ budget: String) -> FormValidationError? {
        normalizedPositiveAmount(from: budget) == nil ? .invalidBudget : nil
    }

    private static func normalizedNumericString(from text: String) -> String {
        trim(text)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
    }
}

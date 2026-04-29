import Foundation

enum AuditLogEntity: String, Codable, CaseIterable {
    case expense
    case income
    case transfer
    case moneyAccount
    case debt
    case recurringPayment
    case budget

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.expense, .spanish): return "Gasto"
        case (.expense, .english): return "Expense"
        case (.income, .spanish): return "Ingreso"
        case (.income, .english): return "Income"
        case (.transfer, .spanish): return "Transferencia"
        case (.transfer, .english): return "Transfer"
        case (.moneyAccount, .spanish): return "Cuenta"
        case (.moneyAccount, .english): return "Account"
        case (.debt, .spanish): return "Deuda"
        case (.debt, .english): return "Debt"
        case (.recurringPayment, .spanish): return "Pago fijo"
        case (.recurringPayment, .english): return "Recurring payment"
        case (.budget, .spanish): return "Presupuesto"
        case (.budget, .english): return "Budget"
        }
    }

    var icon: String {
        switch self {
        case .expense: return "arrow.up.circle"
        case .income: return "arrow.down.circle"
        case .transfer: return "arrow.left.arrow.right"
        case .moneyAccount: return "building.columns"
        case .debt: return "creditcard.and.123"
        case .recurringPayment: return "calendar.badge.clock"
        case .budget: return "chart.pie"
        }
    }
}

enum AuditLogAction: String, Codable, CaseIterable {
    case created
    case updated
    case deleted
    case markedPaid
    case markedUnpaid
    case paymentApplied

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.created, .spanish): return "Creado"
        case (.created, .english): return "Created"
        case (.updated, .spanish): return "Actualizado"
        case (.updated, .english): return "Updated"
        case (.deleted, .spanish): return "Eliminado"
        case (.deleted, .english): return "Deleted"
        case (.markedPaid, .spanish): return "Marcado como pagado"
        case (.markedPaid, .english): return "Marked as paid"
        case (.markedUnpaid, .spanish): return "Marcado como no pagado"
        case (.markedUnpaid, .english): return "Marked as unpaid"
        case (.paymentApplied, .spanish): return "Pago aplicado"
        case (.paymentApplied, .english): return "Payment applied"
        }
    }
}

struct AuditLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let entity: AuditLogEntity
    let entityId: UUID?
    let action: AuditLogAction
    let title: String
    let detail: String

    let originalValue: String?
    let originalTimestamp: Date?

    let previousValue: String?
    let previousTimestamp: Date?

    let newValue: String?
    let newTimestamp: Date?

    let note: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        entity: AuditLogEntity,
        entityId: UUID? = nil,
        action: AuditLogAction,
        title: String,
        detail: String,
        originalValue: String? = nil,
        originalTimestamp: Date? = nil,
        previousValue: String? = nil,
        previousTimestamp: Date? = nil,
        newValue: String? = nil,
        newTimestamp: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.entity = entity
        self.entityId = entityId
        self.action = action
        self.title = title
        self.detail = detail

        self.originalValue = originalValue
        self.originalTimestamp = originalTimestamp

        self.previousValue = previousValue
        self.previousTimestamp = previousTimestamp

        self.newValue = newValue
        self.newTimestamp = newTimestamp

        self.note = note
    }
}

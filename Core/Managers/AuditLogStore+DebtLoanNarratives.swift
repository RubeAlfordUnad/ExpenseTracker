import Foundation

enum DebtAuditSource {
    case debtPaymentSheet
    case linkedRecurringPayment
    case debtEditor
    case debtModule

    var title: String {
        switch self {
        case .debtPaymentSheet:
            return "Registro manual desde Deudas"
        case .linkedRecurringPayment:
            return "Pago fijo vinculado"
        case .debtEditor:
            return "Edición manual de deuda"
        case .debtModule:
            return "Módulo de Deudas"
        }
    }
}

extension AuditLogStore {

    func logDebtPaymentApplied(
        from oldDebt: Debt,
        to newDebt: Debt,
        amount: Double,
        fromAccountName: String,
        source: DebtAuditSource,
        user: String
    ) {
        let eventTime = Date()
        let debtType = newDebt.isLoan ? "Préstamo" : "Tarjeta de crédito"

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .debt,
                entityId: newDebt.id,
                action: .paymentApplied,
                title: newDebt.cardName,
                detail: """
                Tipo: \(debtType)
                Origen del registro: \(source.title)
                Monto pagado: \(auditAmountString(amount))
                Cuenta usada: \(fromAccountName)
                """,
                previousValue: debtPaymentPreviousValue(oldDebt),
                previousTimestamp: eventTime,
                newValue: debtPaymentNewValue(newDebt),
                newTimestamp: eventTime,
                note: newDebt.isFullyPaid
                ? "La deuda quedó con saldo pendiente en cero."
                : "La deuda sigue activa con saldo pendiente."
            ),
            user: user
        )
    }

    func logDebtMovedToPaid(
        from oldDebt: Debt,
        to newDebt: Debt,
        trigger: DebtAuditSource,
        removedRecurringPayment: RecurringPayment?,
        user: String
    ) {
        let eventTime = Date()
        let debtType = newDebt.isLoan ? "Préstamo" : "Tarjeta de crédito"
        let recurringText: String

        if let removedRecurringPayment {
            recurringText = """
            Pago fijo eliminado: \(removedRecurringPayment.title)
            Valor del pago fijo: \(auditAmountString(removedRecurringPayment.amount))
            """
        } else {
            recurringText = "Pago fijo eliminado: No aplica"
        }

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .debt,
                entityId: newDebt.id,
                action: .updated,
                title: newDebt.cardName,
                detail: """
                \(debtType) movido a Deudas pagadas.
                Origen del cierre: \(trigger.title)
                \(recurringText)
                """,
                previousValue: debtArchivePreviousValue(oldDebt),
                previousTimestamp: eventTime,
                newValue: debtArchiveNewValue(newDebt),
                newTimestamp: eventTime,
                note: "La deuda fue cerrada y archivada como pagada."
            ),
            user: user
        )
    }

    func logDebtKeptActiveAtZero(
        _ debt: Debt,
        source: DebtAuditSource,
        user: String
    ) {
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .debt,
                entityId: debt.id,
                action: .updated,
                title: debt.cardName,
                detail: """
                La deuda quedó con saldo pendiente en cero, pero se mantuvo activa.
                Origen de la decisión: \(source.title)
                """,
                previousValue: debtArchiveNewValue(debt),
                previousTimestamp: eventTime,
                newValue: debtArchiveNewValue(debt),
                newTimestamp: eventTime,
                note: "El usuario decidió no mover esta deuda a Pagadas todavía."
            ),
            user: user
        )
    }

    func logLoanRecurringPaymentLinked(
        loan: Debt,
        payment: RecurringPayment,
        user: String
    ) {
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .recurringPayment,
                entityId: payment.id,
                action: .updated,
                title: payment.title,
                detail: """
                Pago fijo vinculado a préstamo.
                Préstamo: \(loan.cardName)
                Cuota mensual: \(auditAmountString(payment.amount))
                Día de cobro: \(payment.dueDay)
                """,
                originalValue: "Préstamo: \(loan.cardName)",
                originalTimestamp: eventTime,
                newValue: """
                Pago fijo: \(payment.title)
                Vinculado a préstamo: Sí
                ID deuda: \(loan.id.uuidString)
                """,
                newTimestamp: eventTime,
                note: "Este pago fijo actualizará el préstamo cuando se marque como pagado."
            ),
            user: user
        )
    }

    func logLoanRecurringPaymentUnlinked(
        loan: Debt,
        payment: RecurringPayment,
        user: String
    ) {
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .recurringPayment,
                entityId: payment.id,
                action: .deleted,
                title: payment.title,
                detail: """
                Pago fijo desvinculado de préstamo.
                Préstamo: \(loan.cardName)
                Valor anterior: \(auditAmountString(payment.amount))
                Día de cobro anterior: \(payment.dueDay)
                """,
                previousValue: """
                Vinculado a préstamo: Sí
                ID deuda: \(loan.id.uuidString)
                """,
                previousTimestamp: eventTime,
                newValue: "Pago fijo eliminado o desvinculado.",
                newTimestamp: eventTime,
                note: "El préstamo queda sin pago fijo conectado."
            ),
            user: user
        )
    }

    func logLinkedLoanRecurringPaymentReverted(
        from oldDebt: Debt,
        to newDebt: Debt,
        payment: RecurringPayment,
        user: String
    ) {
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .debt,
                entityId: newDebt.id,
                action: .markedUnpaid,
                title: newDebt.cardName,
                detail: """
                Pago fijo desmarcado.
                Pago fijo: \(payment.title)
                Monto restaurado al préstamo: \(auditAmountString(payment.amount))
                """,
                previousValue: debtPaymentPreviousValue(oldDebt),
                previousTimestamp: eventTime,
                newValue: debtPaymentNewValue(newDebt),
                newTimestamp: eventTime,
                note: "Se restauró el saldo del préstamo porque el pago fijo dejó de estar marcado como pagado."
            ),
            user: user
        )
    }

    func logLoanRecurringPaymentRemovedAfterDebtArchive(
        loan: Debt,
        payment: RecurringPayment,
        user: String
    ) {
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .recurringPayment,
                entityId: payment.id,
                action: .deleted,
                title: payment.title,
                detail: """
                Pago fijo eliminado por cierre de préstamo.
                Préstamo cerrado: \(loan.cardName)
                Valor mensual: \(auditAmountString(payment.amount))
                """,
                previousValue: """
                Pago fijo activo: \(payment.isActive ? "Sí" : "No")
                Vinculado a préstamo: Sí
                """,
                previousTimestamp: eventTime,
                newValue: "Pago fijo eliminado después de mover el préstamo a Pagadas.",
                newTimestamp: eventTime,
                note: "El préstamo ya fue cerrado; el pago fijo dejó de ser necesario."
            ),
            user: user
        )
    }

    private func debtPaymentPreviousValue(_ debt: Debt) -> String {
        if debt.isLoan {
            return """
            Saldo antes: \(auditAmountString(debt.remainingDebt))
            Cuotas pagadas antes: \(debt.paymentsMade)
            Estado antes: \(debt.status == .paid ? "Pagada" : "Activa")
            """
        }

        return """
        Deuda antes: \(auditAmountString(debt.remainingDebt))
        Disponible antes: \(auditAmountString(debt.availableCredit))
        Uso antes: \(debt.utilizationPercentage)%
        Estado antes: \(debt.status == .paid ? "Pagada" : "Activa")
        """
    }

    private func debtPaymentNewValue(_ debt: Debt) -> String {
        if debt.isLoan {
            let installmentCount = debt.installmentCount.map(String.init) ?? "Sin cuotas"
            let remainingInstallments = debt.remainingInstallments.map(String.init) ?? "Sin dato"

            return """
            Saldo después: \(auditAmountString(debt.remainingDebt))
            Cuotas pagadas después: \(debt.paymentsMade)/\(installmentCount)
            Cuotas restantes: \(remainingInstallments)
            Estado después: \(debt.status == .paid ? "Pagada" : "Activa")
            """
        }

        return """
        Deuda después: \(auditAmountString(debt.remainingDebt))
        Disponible después: \(auditAmountString(debt.availableCredit))
        Uso después: \(debt.utilizationPercentage)%
        Estado después: \(debt.status == .paid ? "Pagada" : "Activa")
        """
    }

    private func debtArchivePreviousValue(_ debt: Debt) -> String {
        """
        Estado antes: \(debt.status == .paid ? "Pagada" : "Activa")
        Saldo antes: \(auditAmountString(debt.remainingDebt))
        Pago fijo vinculado antes: \(debt.linkedRecurringPaymentId == nil ? "No" : "Sí")
        """
    }

    private func debtArchiveNewValue(_ debt: Debt) -> String {
        """
        Estado después: \(debt.status == .paid ? "Pagada" : "Activa")
        Saldo después: \(auditAmountString(debt.remainingDebt))
        Monto pagado: \(auditAmountString(debt.paidAmount))
        Pago fijo vinculado después: \(debt.linkedRecurringPaymentId == nil ? "No" : "Sí")
        """
    }

    private func auditAmountString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "COP"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale(identifier: "es_CO")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

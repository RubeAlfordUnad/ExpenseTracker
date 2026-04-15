import Foundation

final class AuditLogStore {

    static let shared = AuditLogStore()

    private init() {}

    private let defaults = UserDefaults.standard
    private let maxEntries = 600

    private func logsKey(for user: String) -> String {
        "audit_logs_\(user)"
    }

    private func sanitizeUser(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadEntries(user: String) -> [AuditLogEntry] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        guard let data = defaults.data(forKey: logsKey(for: cleanUser)),
              let decoded = try? JSONDecoder().decode([AuditLogEntry].self, from: data) else {
            return []
        }

        return decoded.sorted(by: { lhs, rhs in
            lhs.timestamp > rhs.timestamp
        })
    }

    func append(_ entry: AuditLogEntry, user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        var entries = loadEntries(user: cleanUser)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: logsKey(for: cleanUser))
        }
    }

    func clear(user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }
        defaults.removeObject(forKey: logsKey(for: cleanUser))
    }

    // MARK: - Logging helpers

    func logExpenseCreated(_ expense: Expense, user: String, note: String? = nil) {
        let summary = expenseSummary(expense)
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .expense,
                action: .created,
                title: expense.title,
                detail: summary,
                originalValue: summary,
                originalTimestamp: eventTime,
                newValue: summary,
                newTimestamp: eventTime,
                note: note
            ),
            user: user
        )
    }

    func logExpenseUpdated(from old: Expense, to new: Expense, user: String, note: String? = nil) {
        let oldSummary = expenseSummary(old)
        let newSummary = expenseSummary(new)
        let eventTime = Date()

        let original = latestOriginalValue(for: new.title, entity: .expense, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.title, entity: .expense, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.title, entity: .expense, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .expense,
                action: .updated,
                title: new.title,
                detail: newSummary,
                originalValue: original,
                originalTimestamp: originalTime,
                previousValue: oldSummary,
                previousTimestamp: previousTime,
                newValue: newSummary,
                newTimestamp: eventTime,
                note: note
            ),
            user: user
        )
    }

    func logExpenseDeleted(_ expense: Expense, user: String, note: String? = nil) {
        let summary = expenseSummary(expense)
        let original = latestOriginalValue(for: expense.title, entity: .expense, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .expense,
                action: .deleted,
                title: expense.title,
                detail: summary,
                originalValue: original,
                previousValue: summary,
                note: note
            ),
            user: user
        )
    }

    func logIncomeCreated(_ income: Income, user: String, note: String? = nil) {
        let summary = incomeSummary(income)
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .income,
                action: .created,
                title: income.title,
                detail: summary,
                originalValue: summary,
                originalTimestamp: eventTime,
                newValue: summary,
                newTimestamp: eventTime,
                note: note
            ),
            user: user
        )
    }

    func logIncomeUpdated(from old: Income, to new: Income, user: String, note: String? = nil) {
        let oldSummary = incomeSummary(old)
        let newSummary = incomeSummary(new)
        let eventTime = Date()

        let original = latestOriginalValue(for: new.title, entity: .income, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.title, entity: .income, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.title, entity: .income, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .income,
                action: .updated,
                title: new.title,
                detail: newSummary,
                originalValue: original,
                originalTimestamp: originalTime,
                previousValue: oldSummary,
                previousTimestamp: previousTime,
                newValue: newSummary,
                newTimestamp: eventTime,
                note: note
            ),
            user: user
        )
    }

    func logIncomeDeleted(_ income: Income, user: String, note: String? = nil) {
        let summary = incomeSummary(income)
        let original = latestOriginalValue(for: income.title, entity: .income, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .income,
                action: .deleted,
                title: income.title,
                detail: summary,
                originalValue: original,
                previousValue: summary,
                note: note
            ),
            user: user
        )
    }

    func logTransferCreated(_ transfer: AccountTransfer, fromName: String, toName: String, user: String) {
        let summary = transferSummary(transfer, fromName: fromName, toName: toName)
        let title = "\(fromName) → \(toName)"
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .transfer,
                action: .created,
                title: title,
                detail: summary,
                originalValue: summary,
                originalTimestamp: eventTime,
                newValue: summary,
                newTimestamp: eventTime
            ),
            user: user
        )
    }

    func logTransferUpdated(
        _ old: AccountTransfer,
        new: AccountTransfer,
        fromOldName: String,
        toOldName: String,
        fromNewName: String,
        toNewName: String,
        user: String
    ) {
        let oldSummary = transferSummary(old, fromName: fromOldName, toName: toOldName)
        let newSummary = transferSummary(new, fromName: fromNewName, toName: toNewName)
        let title = "\(fromNewName) → \(toNewName)"
        let eventTime = Date()

        let original = latestOriginalValue(for: title, entity: .transfer, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: title, entity: .transfer, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: title, entity: .transfer, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .transfer,
                action: .updated,
                title: title,
                detail: newSummary,
                originalValue: original,
                originalTimestamp: originalTime,
                previousValue: oldSummary,
                previousTimestamp: previousTime,
                newValue: newSummary,
                newTimestamp: eventTime
            ),
            user: user
        )
    }

    func logTransferDeleted(_ transfer: AccountTransfer, fromName: String, toName: String, user: String) {
        let summary = transferSummary(transfer, fromName: fromName, toName: toName)
        let title = "\(fromName) → \(toName)"
        let original = latestOriginalValue(for: title, entity: .transfer, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .transfer,
                action: .deleted,
                title: title,
                detail: summary,
                originalValue: original,
                previousValue: summary
            ),
            user: user
        )
    }

    func logMoneyAccountCreated(_ account: MoneyAccount, user: String) {
        let summary = moneyAccountSummary(account)
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .moneyAccount,
                action: .created,
                title: account.name,
                detail: summary,
                originalValue: summary,
                originalTimestamp: eventTime,
                newValue: summary,
                newTimestamp: eventTime
            ),
            user: user
        )
    }

    func logMoneyAccountUpdated(from old: MoneyAccount, to new: MoneyAccount, user: String) {
        let oldSummary = moneyAccountSummary(old)
        let newSummary = moneyAccountSummary(new)
        let eventTime = Date()

        let original = latestOriginalValue(for: new.name, entity: .moneyAccount, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.name, entity: .moneyAccount, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.name, entity: .moneyAccount, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .moneyAccount,
                action: .updated,
                title: new.name,
                detail: newSummary,
                originalValue: original,
                originalTimestamp: originalTime,
                previousValue: oldSummary,
                previousTimestamp: previousTime,
                newValue: newSummary,
                newTimestamp: eventTime
            ),
            user: user
        )
    }

    func logMoneyAccountDeleted(_ account: MoneyAccount, user: String) {
        let summary = moneyAccountSummary(account)
        let original = latestOriginalValue(for: account.name, entity: .moneyAccount, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .moneyAccount,
                action: .deleted,
                title: account.name,
                detail: summary,
                originalValue: original,
                previousValue: summary
            ),
            user: user
        )
    }

    func logDebtCreated(_ debt: Debt, user: String) {
        let summary = debtSummary(debt)
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .debt,
                action: .created,
                title: debt.cardName,
                detail: summary,
                originalValue: summary,
                originalTimestamp: eventTime,
                newValue: summary,
                newTimestamp: eventTime
            ),
            user: user
        )
    }

    func logDebtUpdated(from old: Debt, to new: Debt, user: String, note: String? = nil) {
        let oldSummary = debtSummary(old)
        let newSummary = debtSummary(new)
        let eventTime = Date()

        let original = latestOriginalValue(for: new.cardName, entity: .debt, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.cardName, entity: .debt, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.cardName, entity: .debt, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .debt,
                action: .updated,
                title: new.cardName,
                detail: newSummary,
                originalValue: original,
                originalTimestamp: originalTime,
                previousValue: oldSummary,
                previousTimestamp: previousTime,
                newValue: newSummary,
                newTimestamp: eventTime,
                note: note
            ),
            user: user
        )
    }

    func logDebtDeleted(_ debt: Debt, user: String) {
        let summary = debtSummary(debt)
        let original = latestOriginalValue(for: debt.cardName, entity: .debt, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .debt,
                action: .deleted,
                title: debt.cardName,
                detail: summary,
                originalValue: original,
                previousValue: summary
            ),
            user: user
        )
    }

    func logDebtPayment(
        cardName: String,
        amount: Double,
        fromAccountName: String,
        remainingDebtBefore: Double,
        remainingDebtAfter: Double,
        user: String
    ) {
        append(
            AuditLogEntry(
                entity: .debt,
                action: .paymentApplied,
                title: cardName,
                detail: """
                Monto pagado: \(amountString(amount))
                Cuenta origen: \(fromAccountName)
                """,
                previousValue: "Deuda antes: \(amountString(remainingDebtBefore))",
                newValue: "Deuda después: \(amountString(remainingDebtAfter))"
            ),
            user: user
        )
    }

    func logRecurringPaymentCreated(_ payment: RecurringPayment, user: String) {
        let summary = recurringPaymentSummary(payment)
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .recurringPayment,
                action: .created,
                title: payment.title,
                detail: summary,
                originalValue: summary,
                originalTimestamp: eventTime,
                newValue: summary,
                newTimestamp: eventTime
            ),
            user: user
        )
    }

    func logRecurringPaymentUpdated(from old: RecurringPayment, to new: RecurringPayment, user: String) {
        let oldSummary = recurringPaymentSummary(old)
        let newSummary = recurringPaymentSummary(new)
        let eventTime = Date()

        let original = latestOriginalValue(for: new.title, entity: .recurringPayment, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.title, entity: .recurringPayment, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.title, entity: .recurringPayment, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .recurringPayment,
                action: .updated,
                title: new.title,
                detail: newSummary,
                originalValue: original,
                originalTimestamp: originalTime,
                previousValue: oldSummary,
                previousTimestamp: previousTime,
                newValue: newSummary,
                newTimestamp: eventTime
            ),
            user: user
        )
    }

    func logRecurringPaymentDeleted(_ payment: RecurringPayment, user: String) {
        let summary = recurringPaymentSummary(payment)
        let original = latestOriginalValue(for: payment.title, entity: .recurringPayment, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .deleted,
                title: payment.title,
                detail: summary,
                originalValue: original,
                previousValue: summary
            ),
            user: user
        )
    }

    func logRecurringPaymentMarkedPaid(_ payment: RecurringPayment, fromAccountName: String, user: String) {
        let summary = recurringPaymentSummary(payment)
        let original = latestOriginalValue(for: payment.title, entity: .recurringPayment, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .markedPaid,
                title: payment.title,
                detail: summary,
                originalValue: original,
                newValue: """
                \(summary)
                Cuenta usada: \(fromAccountName)
                """
            ),
            user: user
        )
    }

    func logRecurringPaymentMarkedUnpaid(_ payment: RecurringPayment, user: String) {
        let summary = recurringPaymentSummary(payment)
        let original = latestOriginalValue(for: payment.title, entity: .recurringPayment, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .markedUnpaid,
                title: payment.title,
                detail: summary,
                originalValue: original,
                previousValue: summary
            ),
            user: user
        )
    }

    func logBudgetUpdated(previousAmount: Double?, newAmount: Double, user: String) {
        append(
            AuditLogEntry(
                entity: .budget,
                action: .updated,
                title: "Monthly budget",
                detail: "Presupuesto actual: \(amountString(newAmount))",
                originalValue: previousAmount.map { "Presupuesto original: \(amountString($0))" },
                previousValue: previousAmount.map { "Antes: \(amountString($0))" },
                newValue: "Después: \(amountString(newAmount))"
            ),
            user: user
        )
    }

    private func latestOriginalValue(
        for title: String,
        entity: AuditLogEntity,
        user: String
    ) -> String? {
        loadEntries(user: user)
            .first(where: { $0.title == title && $0.entity == entity })?
            .originalValue
    }
    
    private func latestOriginalTimestamp(
        for title: String,
        entity: AuditLogEntity,
        user: String
    ) -> Date? {
        loadEntries(user: user)
            .first(where: { $0.title == title && $0.entity == entity })?
            .originalTimestamp
    }

    private func latestNewTimestamp(
        for title: String,
        entity: AuditLogEntity,
        user: String
    ) -> Date? {
        loadEntries(user: user)
            .first(where: { $0.title == title && $0.entity == entity })?
            .newTimestamp
    }

    // MARK: - Summaries

    private func expenseSummary(_ expense: Expense) -> String {
        let funding: String
        if expense.creditCardId != nil {
            funding = "Tarjeta"
        } else if expense.moneyAccountId != nil {
            funding = "Cuenta"
        } else {
            funding = "Sin origen"
        }

        let custom = expense.customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = (custom?.isEmpty == false) ? custom! : expense.category.rawValue

        return """
        Monto: \(amountString(expense.amount))
        Fecha del movimiento: \(dayString(expense.date))
        Categoría: \(category)
        Origen: \(funding)
        """
    }

    private func incomeSummary(_ income: Income) -> String {
        let custom = income.customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = (custom?.isEmpty == false) ? custom! : income.category.rawValue
        let funding = income.moneyAccountId != nil ? "Cuenta vinculada" : "Sin cuenta"

        return """
        Monto: \(amountString(income.amount))
        Fecha del movimiento: \(dayString(income.date))
        Categoría: \(category)
        Destino: \(funding)
        """
    }

    private func transferSummary(_ transfer: AccountTransfer, fromName: String, toName: String) -> String {
        """
        Monto: \(amountString(transfer.amount))
        Fecha del movimiento: \(dayString(transfer.date))
        Desde: \(fromName)
        Hacia: \(toName)
        """
    }

    private func moneyAccountSummary(_ account: MoneyAccount) -> String {
        let custom = account.customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = (custom?.isEmpty == false) ? custom! : account.kind.rawValue

        return """
        Saldo: \(amountString(account.balance))
        Tipo: \(kind)
        Incluida en fondos disponibles: \(account.includeInAvailableTotal ? "Sí" : "No")
        """
    }

    private func debtSummary(_ debt: Debt) -> String {
        """
        Cupo total: \(amountString(debt.totalLimit))
        Deuda actual: \(amountString(debt.remainingDebt))
        Disponible: \(amountString(debt.availableCredit))
        """
    }

    private func recurringPaymentSummary(_ payment: RecurringPayment) -> String {
        let custom = payment.customCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = (custom?.isEmpty == false) ? custom! : payment.category.rawValue

        return """
        Monto: \(amountString(payment.amount))
        Día de cobro: \(payment.dueDay)
        Categoría: \(category)
        Activo: \(payment.isActive ? "Sí" : "No")
        """
    }

    private func amountString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "COP"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_CO")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

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
        
        return decoded.sorted { $0.timestamp > $1.timestamp }
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
    
    // MARK: - Helpers
    
    func logExpenseCreated(_ expense: Expense, user: String, note: String? = nil) {
        append(
            AuditLogEntry(
                entity: .expense,
                action: .created,
                title: expense.title,
                detail: expenseSummary(expense),
                newValue: expenseSummary(expense),
                note: note
            ),
            user: user
        )
    }
    
    func logExpenseUpdated(from old: Expense, to new: Expense, user: String, note: String? = nil) {
        append(
            AuditLogEntry(
                entity: .expense,
                action: .updated,
                title: new.title,
                detail: expenseSummary(new),
                previousValue: expenseSummary(old),
                newValue: expenseSummary(new),
                note: note
            ),
            user: user
        )
    }
    
    func logExpenseDeleted(_ expense: Expense, user: String, note: String? = nil) {
        append(
            AuditLogEntry(
                entity: .expense,
                action: .deleted,
                title: expense.title,
                detail: expenseSummary(expense),
                previousValue: expenseSummary(expense),
                note: note
            ),
            user: user
        )
    }
    
    func logIncomeCreated(_ income: Income, user: String, note: String? = nil) {
        append(
            AuditLogEntry(
                entity: .income,
                action: .created,
                title: income.title,
                detail: incomeSummary(income),
                newValue: incomeSummary(income),
                note: note
            ),
            user: user
        )
    }
    
    func logIncomeUpdated(from old: Income, to new: Income, user: String, note: String? = nil) {
        append(
            AuditLogEntry(
                entity: .income,
                action: .updated,
                title: new.title,
                detail: incomeSummary(new),
                previousValue: incomeSummary(old),
                newValue: incomeSummary(new),
                note: note
            ),
            user: user
        )
    }
    
    func logIncomeDeleted(_ income: Income, user: String, note: String? = nil) {
        append(
            AuditLogEntry(
                entity: .income,
                action: .deleted,
                title: income.title,
                detail: incomeSummary(income),
                previousValue: incomeSummary(income),
                note: note
            ),
            user: user
        )
    }
    
    func logTransferCreated(_ transfer: AccountTransfer, fromName: String, toName: String, user: String) {
        append(
            AuditLogEntry(
                entity: .transfer,
                action: .created,
                title: "\(fromName) → \(toName)",
                detail: transferSummary(transfer, fromName: fromName, toName: toName),
                newValue: transferSummary(transfer, fromName: fromName, toName: toName)
            ),
            user: user
        )
    }
    
    func logTransferUpdated(_ old: AccountTransfer, new: AccountTransfer, fromOldName: String, toOldName: String, fromNewName: String, toNewName: String, user: String) {
        append(
            AuditLogEntry(
                entity: .transfer,
                action: .updated,
                title: "\(fromNewName) → \(toNewName)",
                detail: transferSummary(new, fromName: fromNewName, toName: toNewName),
                previousValue: transferSummary(old, fromName: fromOldName, toName: toOldName),
                newValue: transferSummary(new, fromName: fromNewName, toName: toNewName)
            ),
            user: user
        )
    }
    
    func logTransferDeleted(_ transfer: AccountTransfer, fromName: String, toName: String, user: String) {
        append(
            AuditLogEntry(
                entity: .transfer,
                action: .deleted,
                title: "\(fromName) → \(toName)",
                detail: transferSummary(transfer, fromName: fromName, toName: toName),
                previousValue: transferSummary(transfer, fromName: fromName, toName: toName)
            ),
            user: user
        )
    }
    
    func logMoneyAccountCreated(_ account: MoneyAccount, user: String) {
        append(
            AuditLogEntry(
                entity: .moneyAccount,
                action: .created,
                title: account.name,
                detail: moneyAccountSummary(account),
                newValue: moneyAccountSummary(account)
            ),
            user: user
        )
    }
    
    func logMoneyAccountUpdated(from old: MoneyAccount, to new: MoneyAccount, user: String) {
        append(
            AuditLogEntry(
                entity: .moneyAccount,
                action: .updated,
                title: new.name,
                detail: moneyAccountSummary(new),
                previousValue: moneyAccountSummary(old),
                newValue: moneyAccountSummary(new)
            ),
            user: user
        )
    }
    
    func logMoneyAccountDeleted(_ account: MoneyAccount, user: String) {
        append(
            AuditLogEntry(
                entity: .moneyAccount,
                action: .deleted,
                title: account.name,
                detail: moneyAccountSummary(account),
                previousValue: moneyAccountSummary(account)
            ),
            user: user
        )
    }
    
    func logDebtCreated(_ debt: Debt, user: String) {
        append(
            AuditLogEntry(
                entity: .debt,
                action: .created,
                title: debt.cardName,
                detail: debtSummary(debt),
                newValue: debtSummary(debt)
            ),
            user: user
        )
    }
    
    func logDebtUpdated(from old: Debt, to new: Debt, user: String, note: String? = nil) {
        append(
            AuditLogEntry(
                entity: .debt,
                action: .updated,
                title: new.cardName,
                detail: debtSummary(new),
                previousValue: debtSummary(old),
                newValue: debtSummary(new),
                note: note
            ),
            user: user
        )
    }
    
    func logDebtDeleted(_ debt: Debt, user: String) {
        append(
            AuditLogEntry(
                entity: .debt,
                action: .deleted,
                title: debt.cardName,
                detail: debtSummary(debt),
                previousValue: debtSummary(debt)
            ),
            user: user
        )
    }
    
    func logDebtPayment(cardName: String, amount: Double, fromAccountName: String, remainingDebtBefore: Double, remainingDebtAfter: Double, user: String) {
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
        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .created,
                title: payment.title,
                detail: recurringPaymentSummary(payment),
                newValue: recurringPaymentSummary(payment)
            ),
            user: user
        )
    }
    
    func logRecurringPaymentUpdated(from old: RecurringPayment, to new: RecurringPayment, user: String) {
        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .updated,
                title: new.title,
                detail: recurringPaymentSummary(new),
                previousValue: recurringPaymentSummary(old),
                newValue: recurringPaymentSummary(new)
            ),
            user: user
        )
    }
    
    func logRecurringPaymentDeleted(_ payment: RecurringPayment, user: String) {
        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .deleted,
                title: payment.title,
                detail: recurringPaymentSummary(payment),
                previousValue: recurringPaymentSummary(payment)
            ),
            user: user
        )
    }
    
    func logRecurringPaymentMarkedPaid(_ payment: RecurringPayment, fromAccountName: String, user: String) {
        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .markedPaid,
                title: payment.title,
                detail: recurringPaymentSummary(payment),
                newValue: "source=\(fromAccountName)"
            ),
            user: user
        )
    }
    
    func logRecurringPaymentMarkedUnpaid(_ payment: RecurringPayment, user: String) {
        append(
            AuditLogEntry(
                entity: .recurringPayment,
                action: .markedUnpaid,
                title: payment.title,
                detail: recurringPaymentSummary(payment)
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
                detail: "budget=\(amountString(newAmount))",
                previousValue: previousAmount.map { "budget=\(amountString($0))" },
                newValue: "budget=\(amountString(newAmount))"
            ),
            user: user
        )
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
        Fecha: \(dayString(expense.date))
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
        Fecha: \(dayString(income.date))
        Categoría: \(category)
        Destino: \(funding)
        """
    }
    
    private func transferSummary(_ transfer: AccountTransfer, fromName: String, toName: String) -> String {
        return """
        Monto: \(amountString(transfer.amount))
        Fecha: \(dayString(transfer.date))
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
        return """
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
        formatter.dateFormat = "dd/MM/yyyy, h:mm a"
        return formatter.string(from: date)
    }
}

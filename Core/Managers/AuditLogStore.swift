import Foundation
import SwiftData

final class AuditLogStore {

    static let shared = AuditLogStore()

    private init() {}

    private let defaults = UserDefaults.standard
    private let maxEntries = 5_000
    private let migrationPrefix = "audit_logs_swiftdata_migrated_v1_"

    private func logsKey(for user: String) -> String {
        "audit_logs_\(user)"
    }

    private func migrationFlagKey(for user: String) -> String {
        "\(migrationPrefix)\(user)"
    }

    private func sanitizeUser(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadEntries(user: String) -> [AuditLogEntry] {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return [] }

        migrateLegacyEntriesIfNeeded(user: cleanUser)

        do {
            let context = makeContext()
            let targetUser = cleanUser

            let descriptor = FetchDescriptor<StoredAuditLogEntry>(
                predicate: #Predicate { $0.user == targetUser },
                sortBy: [SortDescriptor(\StoredAuditLogEntry.timestamp, order: .reverse)]
            )

            return try context.fetch(descriptor).map { $0.toAuditLogEntry() }
        } catch {
            return loadLegacyEntries(user: cleanUser)
        }
    }

    func append(_ entry: AuditLogEntry, user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        migrateLegacyEntriesIfNeeded(user: cleanUser)

        do {
            let context = makeContext()
            context.insert(StoredAuditLogEntry(entry: entry, user: cleanUser))
            try trimStoredEntriesIfNeeded(user: cleanUser, context: context)
            try context.save()
        } catch {
            appendLegacy(entry, user: cleanUser)
        }
    }

    func clear(user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        do {
            let context = makeContext()
            try deleteStoredEntries(user: cleanUser, context: context)
            try context.save()
        } catch {
            // si SwiftData falla, igual limpiamos el fallback viejo
        }

        defaults.removeObject(forKey: logsKey(for: cleanUser))
        defaults.removeObject(forKey: migrationFlagKey(for: cleanUser))
    }

    func replaceEntries(_ entries: [AuditLogEntry], user: String) {
        let cleanUser = sanitizeUser(user)
        guard !cleanUser.isEmpty else { return }

        migrateLegacyEntriesIfNeeded(user: cleanUser)

        let trimmed = Array(entries.sorted { $0.timestamp > $1.timestamp }.prefix(maxEntries))

        do {
            let context = makeContext()
            try deleteStoredEntries(user: cleanUser, context: context)

            for entry in trimmed {
                context.insert(StoredAuditLogEntry(entry: entry, user: cleanUser))
            }

            try context.save()
            defaults.removeObject(forKey: logsKey(for: cleanUser))
        } catch {
            defaults.removeObject(forKey: logsKey(for: cleanUser))
            if let data = try? JSONEncoder().encode(trimmed) {
                defaults.set(data, forKey: logsKey(for: cleanUser))
            }
        }
    }

    // MARK: - Logging helpers

    func logExpenseCreated(_ expense: Expense, user: String, note: String? = nil) {
        let summary = expenseSummary(expense)
        let eventTime = Date()

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .expense,
                entityId: expense.id,
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

        let original = latestOriginalValue(for: new.title, entity: .expense, entityId: new.id, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.title, entity: .expense, entityId: new.id, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.title, entity: .expense, entityId: new.id, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .expense,
                entityId: new.id,
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
        let original = latestOriginalValue(for: expense.title, entity: .expense, entityId: expense.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .expense,
                entityId: expense.id,
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
                entityId: income.id,
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

        let original = latestOriginalValue(for: new.title, entity: .income, entityId: new.id, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.title, entity: .income, entityId: new.id, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.title, entity: .income, entityId: new.id, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .income,
                entityId: new.id,
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
        let original = latestOriginalValue(for: income.title, entity: .income, entityId: income.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .income,
                entityId: income.id,
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
                entityId: transfer.id,
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

        let original = latestOriginalValue(for: title, entity: .transfer, entityId: new.id, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: title, entity: .transfer, entityId: new.id, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: title, entity: .transfer, entityId: new.id, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .transfer,
                entityId: new.id,
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
        let original = latestOriginalValue(for: title, entity: .transfer, entityId: transfer.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .transfer,
                entityId: transfer.id,
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
                entityId: account.id,
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

        let original = latestOriginalValue(for: new.name, entity: .moneyAccount, entityId: new.id, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.name, entity: .moneyAccount, entityId: new.id, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.name, entity: .moneyAccount, entityId: new.id, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .moneyAccount,
                entityId: new.id,
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
        let original = latestOriginalValue(for: account.name, entity: .moneyAccount, entityId: account.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .moneyAccount,
                entityId: account.id,
                action: .deleted,
                title: account.name,
                detail: summary,
                originalValue: original,
                previousValue: summary
            ),
            user: user
        )
    }

    func logMoneyAccountBalanceAdjusted(
        accountName: String,
        previousBalance: Double,
        newBalance: Double,
        adjustment: AccountBalanceAdjustment,
        user: String
    ) {
        let eventTime = Date()
        let signedAdjustment = signedAmountString(adjustment.amount)

        let reasonText: String
        if let reason = adjustment.normalizedReason {
            reasonText = reason
        } else {
            reasonText = "Sin motivo especificado"
        }

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .moneyAccount,
                entityId: adjustment.moneyAccountId,
                action: .updated,
                title: accountName,
                detail: """
                Ajuste de saldo registrado
                Fecha efectiva: \(dayString(adjustment.date))
                Monto del ajuste: \(signedAdjustment)
                """,
                previousValue: "Saldo antes: \(amountString(previousBalance))",
                previousTimestamp: adjustment.date,
                newValue: "Saldo después: \(amountString(newBalance))",
                newTimestamp: adjustment.date,
                note: """
                Motivo: \(reasonText)
                Ajuste aplicado: \(signedAdjustment)
                """
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
                entityId: debt.id,
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

        let original = latestOriginalValue(for: new.cardName, entity: .debt, entityId: new.id, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.cardName, entity: .debt, entityId: new.id, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.cardName, entity: .debt, entityId: new.id, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .debt,
                entityId: new.id,
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
        let original = latestOriginalValue(for: debt.cardName, entity: .debt, entityId: debt.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .debt,
                entityId: debt.id,
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
                entityId: payment.id,
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

        let original = latestOriginalValue(for: new.title, entity: .recurringPayment, entityId: new.id, user: user) ?? oldSummary
        let originalTime = latestOriginalTimestamp(for: new.title, entity: .recurringPayment, entityId: new.id, user: user) ?? eventTime
        let previousTime = latestNewTimestamp(for: new.title, entity: .recurringPayment, entityId: new.id, user: user) ?? eventTime

        append(
            AuditLogEntry(
                timestamp: eventTime,
                entity: .recurringPayment,
                entityId: new.id,
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
        let original = latestOriginalValue(for: payment.title, entity: .recurringPayment, entityId: payment.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .recurringPayment,
                entityId: payment.id,
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
        let original = latestOriginalValue(for: payment.title, entity: .recurringPayment, entityId: payment.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .recurringPayment,
                entityId: payment.id,
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
        let original = latestOriginalValue(for: payment.title, entity: .recurringPayment, entityId: payment.id, user: user) ?? summary

        append(
            AuditLogEntry(
                entity: .recurringPayment,
                entityId: payment.id,
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
        entityId: UUID?,
        user: String
    ) -> String? {
        loadEntries(user: user)
            .first(where: { matches($0, entity: entity, title: title, entityId: entityId) })?
            .originalValue
    }

    private func latestOriginalTimestamp(
        for title: String,
        entity: AuditLogEntity,
        entityId: UUID?,
        user: String
    ) -> Date? {
        loadEntries(user: user)
            .first(where: { matches($0, entity: entity, title: title, entityId: entityId) })?
            .originalTimestamp
    }

    private func latestNewTimestamp(
        for title: String,
        entity: AuditLogEntity,
        entityId: UUID?,
        user: String
    ) -> Date? {
        loadEntries(user: user)
            .first(where: { matches($0, entity: entity, title: title, entityId: entityId) })?
            .newTimestamp
    }

    private func matches(
        _ entry: AuditLogEntry,
        entity: AuditLogEntity,
        title: String,
        entityId: UUID?
    ) -> Bool {
        guard entry.entity == entity else { return false }

        if let entityId {
            return entry.entityId == entityId || (entry.entityId == nil && entry.title == title)
        }

        return entry.title == title
    }

    // MARK: - Legacy migration / fallback

    private func migrateLegacyEntriesIfNeeded(user: String) {
        guard !defaults.bool(forKey: migrationFlagKey(for: user)) else { return }

        let legacyEntries = loadLegacyEntries(user: user)
        guard !legacyEntries.isEmpty else {
            defaults.set(true, forKey: migrationFlagKey(for: user))
            return
        }

        do {
            let context = makeContext()
            try deleteStoredEntries(user: user, context: context)

            for entry in legacyEntries.prefix(maxEntries) {
                context.insert(StoredAuditLogEntry(entry: entry, user: user))
            }

            try context.save()
            defaults.removeObject(forKey: logsKey(for: user))
            defaults.set(true, forKey: migrationFlagKey(for: user))
        } catch {
            // si falla, seguimos operando en legacy sin marcar migrado
        }
    }

    private func appendLegacy(_ entry: AuditLogEntry, user: String) {
        var entries = loadLegacyEntries(user: user)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: logsKey(for: user))
        }
    }

    private func loadLegacyEntries(user: String) -> [AuditLogEntry] {
        guard let data = defaults.data(forKey: logsKey(for: user)),
              let decoded = try? JSONDecoder().decode([AuditLogEntry].self, from: data) else {
            return []
        }

        return decoded.sorted { $0.timestamp > $1.timestamp }
    }

    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController.shared.container)
    }

    private func trimStoredEntriesIfNeeded(user: String, context: ModelContext) throws {
        let targetUser = user
        let descriptor = FetchDescriptor<StoredAuditLogEntry>(
            predicate: #Predicate { $0.user == targetUser },
            sortBy: [SortDescriptor(\StoredAuditLogEntry.timestamp, order: .reverse)]
        )

        let entries = try context.fetch(descriptor)
        guard entries.count > maxEntries else { return }

        for entry in entries.dropFirst(maxEntries) {
            context.delete(entry)
        }
    }

    private func deleteStoredEntries(user: String, context: ModelContext) throws {
        let targetUser = user
        let descriptor = FetchDescriptor<StoredAuditLogEntry>(
            predicate: #Predicate { $0.user == targetUser }
        )

        try context.fetch(descriptor).forEach { context.delete($0) }
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

    private func signedAmountString(_ value: Double) -> String {
        let absolute = amountString(abs(value))
        return value >= 0 ? "+\(absolute)" : "-\(absolute)"
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

import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - loan debt backup metadata")
struct RegressionLoanDebtBackupMetadataTests {

    @Test("Financial sanitizer preserves loan, card and recurring payment metadata")
    func financialSanitizer_preserves_loan_card_and_recurring_payment_metadata() throws {
        let loanId = UUID()
        let cardId = UUID()
        let recurringId = UUID()
        let firstPaymentDate = makeDate(year: 2026, month: 4, day: 5)

        let loan = Debt(
            id: loanId,
            cardName: "Ortodoncia",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 500_000,
            kind: .loan,
            status: .active,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 4,
            firstPaymentDate: firstPaymentDate,
            linkedRecurringPaymentId: recurringId,
            managementFee: 0,
            minimumPaymentRate: 0.05,
            minimumPaymentFixedAmount: nil,
            statementClosingDay: nil,
            minimumPaymentDueDay: nil
        )

        let card = Debt(
            id: cardId,
            cardName: "Visa Bancolombia",
            brand: .visa,
            totalLimit: 5_000_000,
            remainingDebt: 1_200_000,
            kind: .creditCard,
            status: .active,
            monthlyPayment: nil,
            installmentCount: nil,
            paymentsMade: 0,
            firstPaymentDate: nil,
            linkedRecurringPaymentId: nil,
            managementFee: 15_000,
            minimumPaymentRate: 0.05,
            minimumPaymentFixedAmount: 50_000,
            statementClosingDay: 10,
            minimumPaymentDueDay: 25
        )

        let recurringPayment = RecurringPayment(
            id: recurringId,
            title: "Ortodoncia",
            amount: 100_000,
            dueDay: 5,
            category: .loans,
            customCategoryName: "Préstamo",
            isActive: true,
            lastPaidMonth: nil,
            lastPaidYear: nil,
            lastPaidExpenseId: nil,
            linkedDebtId: loanId
        )

        let logEntry = AuditLogEntry(
            timestamp: makeDate(year: 2026, month: 4, day: 5),
            entity: .debt,
            entityId: loanId,
            action: .updated,
            title: "Ortodoncia",
            detail: "Préstamo actualizado",
            previousValue: "Saldo anterior: 600000",
            newValue: "Saldo nuevo: 500000"
        )

        let snapshot = makeSnapshot(
            debts: [loan, card],
            recurringPayments: [recurringPayment],
            auditLogEntries: [logEntry]
        )

        let sanitized = try AppBackupFinancialStateSanitizer().sanitize(snapshot)

        guard let sanitizedLoan = sanitized.debts.first(where: { $0.id == loanId }) else {
            Issue.record("Expected sanitized loan")
            return
        }

        guard let sanitizedCard = sanitized.debts.first(where: { $0.id == cardId }) else {
            Issue.record("Expected sanitized card")
            return
        }

        guard let sanitizedRecurringPayment = sanitized.recurringPayments.first(where: { $0.id == recurringId }) else {
            Issue.record("Expected sanitized recurring payment")
            return
        }

        #expect(sanitizedLoan.kind == .loan)
        #expect(sanitizedLoan.status == .active)
        #expect(sanitizedLoan.monthlyPayment == 100_000)
        #expect(sanitizedLoan.installmentCount == 9)
        #expect(sanitizedLoan.paymentsMade == 4)
        #expect(sanitizedLoan.firstPaymentDate == firstPaymentDate)
        #expect(sanitizedLoan.linkedRecurringPaymentId == recurringId)
        #expect(sanitizedLoan.remainingDebt == 500_000)

        #expect(sanitizedCard.kind == .creditCard)
        #expect(sanitizedCard.status == .active)
        #expect(sanitizedCard.brand == .visa)
        #expect(sanitizedCard.managementFee == 15_000)
        #expect(sanitizedCard.minimumPaymentRate == 0.05)
        #expect(sanitizedCard.minimumPaymentFixedAmount == 50_000)
        #expect(sanitizedCard.statementClosingDay == 10)
        #expect(sanitizedCard.minimumPaymentDueDay == 25)

        #expect(sanitizedRecurringPayment.linkedDebtId == loanId)
        #expect(sanitizedRecurringPayment.category == .loans)
        #expect(sanitized.auditLogEntries.count == 1)
        #expect(sanitized.auditLogEntries[0].entityId == loanId)
    }

    @Test("Reference sanitizer keeps valid debt recurring links and clears invalid ones")
    func referenceSanitizer_keeps_valid_debt_recurring_links_and_clears_invalid_ones() {
        let loanId = UUID()
        let recurringId = UUID()
        let orphanDebtId = UUID()
        let orphanRecurringId = UUID()

        let loan = Debt(
            id: loanId,
            cardName: "Ortodoncia",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 300_000,
            kind: .loan,
            status: .active,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 6,
            firstPaymentDate: makeDate(year: 2026, month: 4, day: 5),
            linkedRecurringPaymentId: recurringId
        )

        let validRecurringPayment = RecurringPayment(
            id: recurringId,
            title: "Ortodoncia",
            amount: 100_000,
            dueDay: 5,
            category: .loans,
            customCategoryName: "Préstamo",
            isActive: true,
            linkedDebtId: loanId
        )

        let orphanRecurringPayment = RecurringPayment(
            id: orphanRecurringId,
            title: "Préstamo huérfano",
            amount: 80_000,
            dueDay: 8,
            category: .loans,
            customCategoryName: "Préstamo",
            isActive: true,
            linkedDebtId: orphanDebtId
        )

        let debtLog = AuditLogEntry(
            entity: .debt,
            entityId: loanId,
            action: .updated,
            title: "Ortodoncia",
            detail: "Saldo actualizado"
        )

        let snapshot = makeSnapshot(
            debts: [loan],
            recurringPayments: [validRecurringPayment, orphanRecurringPayment],
            auditLogEntries: [debtLog]
        )

        let sanitized = AppBackupReferenceSanitizer().sanitize(snapshot)

        guard let sanitizedLoan = sanitized.debts.first(where: { $0.id == loanId }) else {
            Issue.record("Expected sanitized loan")
            return
        }

        guard let sanitizedValidRecurring = sanitized.recurringPayments.first(where: { $0.id == recurringId }) else {
            Issue.record("Expected valid recurring payment")
            return
        }

        guard let sanitizedOrphanRecurring = sanitized.recurringPayments.first(where: { $0.id == orphanRecurringId }) else {
            Issue.record("Expected orphan recurring payment")
            return
        }

        #expect(sanitizedLoan.linkedRecurringPaymentId == recurringId)
        #expect(sanitizedValidRecurring.linkedDebtId == loanId)
        #expect(sanitizedOrphanRecurring.linkedDebtId == nil)
        #expect(sanitized.auditLogEntries[0].entityId == loanId)
    }

    @Test("Identity remapper keeps loan and recurring payment links consistent")
    func identityRemapper_keeps_loan_and_recurring_payment_links_consistent() {
        let loanId = UUID()
        let recurringId = UUID()

        let loan = Debt(
            id: loanId,
            cardName: "Ortodoncia",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 200_000,
            kind: .loan,
            status: .active,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 7,
            firstPaymentDate: makeDate(year: 2026, month: 4, day: 5),
            linkedRecurringPaymentId: recurringId
        )

        let recurringPayment = RecurringPayment(
            id: recurringId,
            title: "Ortodoncia",
            amount: 100_000,
            dueDay: 5,
            category: .loans,
            customCategoryName: "Préstamo",
            isActive: true,
            linkedDebtId: loanId
        )

        let debtLog = AuditLogEntry(
            entity: .debt,
            entityId: loanId,
            action: .updated,
            title: "Ortodoncia",
            detail: "Pago aplicado"
        )

        let snapshot = makeSnapshot(
            debts: [loan],
            recurringPayments: [recurringPayment],
            auditLogEntries: [debtLog]
        )

        let remapped = AppBackupIdentityRemapper().remap(snapshot)

        guard let remappedLoan = remapped.debts.first(where: { $0.cardName == "Ortodoncia" }) else {
            Issue.record("Expected remapped loan")
            return
        }

        guard let remappedRecurringPayment = remapped.recurringPayments.first(where: { $0.title == "Ortodoncia" }) else {
            Issue.record("Expected remapped recurring payment")
            return
        }

        #expect(remappedLoan.id != loanId)
        #expect(remappedRecurringPayment.id != recurringId)

        #expect(remappedLoan.kind == .loan)
        #expect(remappedLoan.monthlyPayment == 100_000)
        #expect(remappedLoan.installmentCount == 9)
        #expect(remappedLoan.paymentsMade == 7)

        #expect(remappedLoan.linkedRecurringPaymentId == remappedRecurringPayment.id)
        #expect(remappedRecurringPayment.linkedDebtId == remappedLoan.id)
        #expect(remapped.auditLogEntries.first?.entityId == remappedLoan.id)
    }

    @Test("Backup import preserves new loan and card fields")
    func backupImport_preserves_new_loan_and_card_fields() throws {
        let loanId = UUID()
        let cardId = UUID()
        let recurringId = UUID()

        let loan = Debt(
            id: loanId,
            cardName: "Ortodoncia",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 100_000,
            kind: .loan,
            status: .active,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 8,
            firstPaymentDate: makeDate(year: 2026, month: 4, day: 5),
            linkedRecurringPaymentId: recurringId
        )

        let card = Debt(
            id: cardId,
            cardName: "Visa Bancolombia",
            brand: .visa,
            totalLimit: 5_000_000,
            remainingDebt: 1_000_000,
            kind: .creditCard,
            status: .active,
            managementFee: 15_000,
            minimumPaymentRate: 0.05,
            minimumPaymentFixedAmount: 60_000,
            statementClosingDay: 10,
            minimumPaymentDueDay: 25
        )

        let recurringPayment = RecurringPayment(
            id: recurringId,
            title: "Ortodoncia",
            amount: 100_000,
            dueDay: 5,
            category: .loans,
            customCategoryName: "Préstamo",
            isActive: true,
            linkedDebtId: loanId
        )

        let debtLog = AuditLogEntry(
            entity: .debt,
            entityId: loanId,
            action: .paymentApplied,
            title: "Ortodoncia",
            detail: "Pago aplicado al préstamo"
        )

        let snapshot = makeSnapshot(
            debts: [loan, card],
            recurringPayments: [recurringPayment],
            auditLogEntries: [debtLog]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let imported = try AppBackupService().importSnapshot(from: data)

        guard let importedLoan = imported.debts.first(where: { $0.id == loanId }) else {
            Issue.record("Expected imported loan")
            return
        }

        guard let importedCard = imported.debts.first(where: { $0.id == cardId }) else {
            Issue.record("Expected imported card")
            return
        }

        guard let importedRecurringPayment = imported.recurringPayments.first(where: { $0.id == recurringId }) else {
            Issue.record("Expected imported recurring payment")
            return
        }

        #expect(importedLoan.kind == .loan)
        #expect(importedLoan.status == .active)
        #expect(importedLoan.monthlyPayment == 100_000)
        #expect(importedLoan.installmentCount == 9)
        #expect(importedLoan.paymentsMade == 8)
        #expect(importedLoan.linkedRecurringPaymentId == recurringId)

        #expect(importedCard.kind == .creditCard)
        #expect(importedCard.brand == .visa)
        #expect(importedCard.managementFee == 15_000)
        #expect(importedCard.minimumPaymentRate == 0.05)
        #expect(importedCard.minimumPaymentFixedAmount == 60_000)
        #expect(importedCard.statementClosingDay == 10)
        #expect(importedCard.minimumPaymentDueDay == 25)

        #expect(importedRecurringPayment.linkedDebtId == loanId)
        #expect(imported.auditLogEntries.first?.entityId == loanId)
    }

    @Test("Paid debt remains paid after import")
    func paidDebt_remains_paid_after_import() throws {
        let paidLoanId = UUID()

        let paidLoan = Debt(
            id: paidLoanId,
            cardName: "Ortodoncia pagada",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 0,
            kind: .loan,
            status: .paid,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 9,
            firstPaymentDate: makeDate(year: 2026, month: 4, day: 5),
            linkedRecurringPaymentId: nil
        )

        let snapshot = makeSnapshot(
            debts: [paidLoan],
            recurringPayments: [],
            auditLogEntries: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let imported = try AppBackupService().importSnapshot(from: data)

        guard let importedLoan = imported.debts.first(where: { $0.id == paidLoanId }) else {
            Issue.record("Expected imported paid loan")
            return
        }

        #expect(importedLoan.kind == .loan)
        #expect(importedLoan.status == .paid)
        #expect(importedLoan.remainingDebt == 0)
        #expect(importedLoan.paymentsMade == 9)
        #expect(importedLoan.remainingInstallments == 0)
    }

    private func makeSnapshot(
        debts: [Debt],
        recurringPayments: [RecurringPayment],
        auditLogEntries: [AuditLogEntry]
    ) -> AppBackupSnapshot {
        AppBackupSnapshot(
            version: 7,
            exportedAt: makeDate(year: 2026, month: 4, day: 27),
            sourceUser: "test_user",
            expenses: [],
            incomes: [],
            debts: debts,
            recurringPayments: recurringPayments,
            moneyAccounts: [],
            accountTransfers: [],
            accountBalanceAdjustments: [],
            monthlyBudget: nil,
            notificationPreferences: NotificationPreferences(),
            expenseCustomCategories: [],
            incomeCustomCategories: [],
            moneyAccountCustomCategories: [],
            recurringPaymentCustomCategories: [],
            auditLogEntries: auditLogEntries,
            profileImageData: nil,
            profileDisplayName: nil
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        components.second = 0

        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}

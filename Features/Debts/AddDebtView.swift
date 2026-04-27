import SwiftUI

struct AddDebtView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var settings: AppSettings

    @State private var selectedKind: DebtKind
    @State private var cardName: String
    @State private var selectedBrand: CardBrand
    @State private var totalLimit: String
    @State private var currentDebt: String

    @State private var monthlyPayment: String
    @State private var installmentCount: String
    @State private var firstPaymentDate: Date
    @State private var shouldCreateRecurringPayment: Bool

    @State private var managementFee: String
    @State private var minimumPaymentRatePercent: String
    @State private var minimumPaymentFixedAmount: String
    @State private var statementClosingDay: Int
    @State private var minimumPaymentDueDay: Int

    @State private var showValidationAlert = false

    let existingDebt: Debt?
    var onSave: (Debt) -> Void

    init(existingDebt: Debt? = nil, onSave: @escaping (Debt) -> Void) {
        self.existingDebt = existingDebt
        self.onSave = onSave

        let debtKind = existingDebt?.kind ?? .creditCard

        _selectedKind = State(initialValue: debtKind)
        _cardName = State(initialValue: existingDebt?.cardName ?? "")
        _selectedBrand = State(initialValue: existingDebt?.brand ?? .visa)
        _totalLimit = State(initialValue: existingDebt.map { Self.makeAmountText($0.totalLimit) } ?? "")
        _currentDebt = State(initialValue: existingDebt.map { Self.makeAmountText($0.remainingDebt) } ?? "")

        _monthlyPayment = State(initialValue: existingDebt?.monthlyPayment.map { Self.makeAmountText($0) } ?? "")
        _installmentCount = State(initialValue: existingDebt?.installmentCount.map { String($0) } ?? "")
        _firstPaymentDate = State(initialValue: existingDebt?.firstPaymentDate ?? Date())
        _shouldCreateRecurringPayment = State(initialValue: existingDebt?.linkedRecurringPaymentId != nil)

        _managementFee = State(initialValue: Self.makeAmountText(existingDebt?.managementFee ?? 0))
        _minimumPaymentRatePercent = State(
            initialValue: Self.makePercentText((existingDebt?.minimumPaymentRate ?? 0.05) * 100)
        )
        _minimumPaymentFixedAmount = State(
            initialValue: existingDebt?.minimumPaymentFixedAmount.map { Self.makeAmountText($0) } ?? ""
        )
        _statementClosingDay = State(initialValue: existingDebt?.statementClosingDay ?? 1)
        _minimumPaymentDueDay = State(initialValue: existingDebt?.minimumPaymentDueDay ?? 1)
    }

    private var isEditing: Bool {
        existingDebt != nil
    }

    private var validationMessage: String? {
        let trimmedName = FormValidator.trim(cardName)

        if trimmedName.isEmpty {
            return selectedKind == .loan
            ? localized("Escribe un nombre para el préstamo.", "Enter a loan name.")
            : localized("Escribe un nombre para la tarjeta.", "Enter a card name.")
        }

        guard let principal = FormValidator.normalizedPositiveAmount(from: totalLimit) else {
            return selectedKind == .loan
            ? localized("El monto total del préstamo debe ser mayor que cero.", "Loan total amount must be greater than zero.")
            : localized("El cupo total debe ser mayor que cero.", "The total limit must be greater than zero.")
        }

        guard let pending = FormValidator.normalizedNonNegativeAmount(from: currentDebt) else {
            return selectedKind == .loan
            ? localized("El saldo pendiente del préstamo no puede ser negativo.", "Loan balance cannot be negative.")
            : localized("La deuda actual no puede ser negativa.", "Current debt cannot be negative.")
        }

        if pending > principal {
            return selectedKind == .loan
            ? localized("El saldo pendiente no puede superar el monto total del préstamo.", "Loan balance cannot exceed the total loan amount.")
            : localized("La deuda actual no puede superar el cupo total.", "Current debt cannot exceed the total limit.")
        }

        if selectedKind == .loan {
            guard FormValidator.normalizedPositiveAmount(from: monthlyPayment) != nil else {
                return localized("La cuota mensual debe ser mayor que cero.", "Monthly payment must be greater than zero.")
            }

            guard let installments = normalizedInstallmentCount, installments > 0 else {
                return localized("El número de cuotas debe ser mayor que cero.", "Installment count must be greater than zero.")
            }
        }

        if selectedKind == .creditCard {
            if !managementFee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               FormValidator.normalizedNonNegativeAmount(from: managementFee) == nil {
                return localized("La cuota de manejo no puede ser negativa.", "Management fee cannot be negative.")
            }

            guard let rate = FormValidator.normalizedNonNegativeAmount(from: minimumPaymentRatePercent),
                  rate <= 100 else {
                return localized("El porcentaje de pago mínimo debe estar entre 0 y 100.", "Minimum payment percentage must be between 0 and 100.")
            }

            if !minimumPaymentFixedAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               FormValidator.normalizedNonNegativeAmount(from: minimumPaymentFixedAmount) == nil {
                return localized("El monto mínimo fijo no puede ser negativo.", "Fixed minimum amount cannot be negative.")
            }
        }

        return nil
    }

    private var validationAlertTitle: String {
        settings.language == .spanish ? "Datos inválidos" : "Invalid data"
    }

    private var normalizedInstallmentCount: Int? {
        let trimmed = installmentCount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    private var firstPaymentDay: Int {
        Calendar.current.component(.day, from: firstPaymentDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(typePickerTitle, selection: $selectedKind) {
                        ForEach(DebtKind.allCases) { kind in
                            Label(
                                kind.title(language: settings.language),
                                systemImage: kind.icon
                            )
                            .tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEditing)
                } footer: {
                    if isEditing {
                        Text(
                            selectedKind == .loan
                            ? localized("El tipo no se puede cambiar después de crear el préstamo.", "The type cannot be changed after creating the loan.")
                            : localized("El tipo no se puede cambiar después de crear la tarjeta.", "The type cannot be changed after creating the card.")
                        )
                    }
                }

                Section(header: Text(generalSectionTitle)) {
                    TextField(nameFieldTitle, text: $cardName)
                        .textInputAutocapitalization(.words)

                    if selectedKind == .creditCard {
                        Picker(settings.t("debts.brand"), selection: $selectedBrand) {
                            ForEach(CardBrand.allCases, id: \.self) { brand in
                                Text(brand.displayName(language: settings.language))
                                    .tag(brand)
                            }
                        }
                    }

                    MoneyTextField(
                        title: principalFieldTitle,
                        text: $totalLimit,
                        accessibilityIdentifier: "debt.limit.field"
                    )

                    MoneyTextField(
                        title: pendingFieldTitle,
                        text: $currentDebt,
                        accessibilityIdentifier: "debt.balance.field"
                    )
                }

                if selectedKind == .loan {
                    loanSection
                    recurringPaymentSection
                }

                if selectedKind == .creditCard {
                    creditCardPaymentSection
                    creditCardCalendarSection
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.t("common.save")) {
                        saveDebt()
                    }
                    .disabled(validationMessage != nil)
                }
            }
            .alert(validationAlertTitle, isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage ?? "")
            }
        }
    }

    private var loanSection: some View {
        Section {
            MoneyTextField(
                title: localized("Cuota mensual", "Monthly payment"),
                text: $monthlyPayment,
                accessibilityIdentifier: "loan.monthlyPayment.field"
            )

            TextField(localized("Número de cuotas", "Installment count"), text: $installmentCount)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("loan.installments.field")

            DatePicker(
                localized("Primer pago", "First payment"),
                selection: $firstPaymentDate,
                displayedComponents: .date
            )

            if let preview = loanPreviewText {
                Text(preview)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(localized("Plan de pago", "Payment plan"))
        } footer: {
            Text(
                localized(
                    "La app usará estos datos para calcular cuánto llevas pagado, cuánto falta y cuándo termina el préstamo.",
                    "The app will use this data to calculate how much has been paid, how much remains and when the loan ends."
                )
            )
        }
    }

    private var recurringPaymentSection: some View {
        Section {
            Toggle(
                localized("Agregar también a pagos fijos", "Also add to recurring payments"),
                isOn: $shouldCreateRecurringPayment
            )

            if shouldCreateRecurringPayment {
                HStack {
                    Text(localized("Categoría", "Category"))
                    Spacer()
                    Text(RecurringPaymentCategory.loans.displayName(language: settings.language))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(localized("Día de cobro", "Due day"))
                    Spacer()
                    Text("\(firstPaymentDay)")
                        .foregroundColor(.secondary)
                }

                if let amount = FormValidator.normalizedPositiveAmount(from: monthlyPayment) {
                    HStack {
                        Text(localized("Valor mensual", "Monthly value"))
                        Spacer()
                        Text(settings.secureCurrency(amount))
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text(localized("Vínculo con pagos fijos", "Recurring payment link"))
        } footer: {
            Text(
                localized(
                    "Si activas esta opción, se creará o actualizará un pago fijo conectado a este préstamo.",
                    "If enabled, a recurring payment connected to this loan will be created or updated."
                )
            )
        }
    }

    private var creditCardPaymentSection: some View {
        Section {
            MoneyTextField(
                title: localized("Cuota de manejo mensual", "Monthly management fee"),
                text: $managementFee,
                accessibilityIdentifier: "card.managementFee.field"
            )

            MoneyTextField(
                title: localized("Pago mínimo (%)", "Minimum payment (%)"),
                text: $minimumPaymentRatePercent,
                accessibilityIdentifier: "card.minimumRate.field"
            )

            MoneyTextField(
                title: localized("Pago mínimo fijo opcional", "Optional fixed minimum payment"),
                text: $minimumPaymentFixedAmount,
                accessibilityIdentifier: "card.minimumFixed.field"
            )

            if let preview = creditCardMinimumPaymentPreview {
                Text(preview)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(localized("Pago mínimo estimado", "Estimated minimum payment"))
        } footer: {
            Text(
                localized(
                    "El pago estimado combina el porcentaje mínimo, el mínimo fijo si aplica y la cuota de manejo.",
                    "The estimated payment combines the minimum percentage, the fixed minimum when present and the management fee."
                )
            )
        }
    }

    private var creditCardCalendarSection: some View {
        Section {
            Stepper(value: $statementClosingDay, in: 1...31) {
                HStack {
                    Text(localized("Día de corte", "Statement closing day"))
                    Spacer()
                    Text("\(statementClosingDay)")
                        .foregroundColor(.secondary)
                }
            }

            Stepper(value: $minimumPaymentDueDay, in: 1...31) {
                HStack {
                    Text(localized("Día de pago mínimo", "Minimum payment day"))
                    Spacer()
                    Text("\(minimumPaymentDueDay)")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text(localized("Calendario de tarjeta", "Card calendar"))
        } footer: {
            Text(
                localized(
                    "Estos días se usarán en el siguiente bloque para pintar el calendario de deudas con puntos de colores.",
                    "These days will be used in the next block to draw the debt calendar with colored dots."
                )
            )
        }
    }

    private var loanPreviewText: String? {
        guard let principal = FormValidator.normalizedPositiveAmount(from: totalLimit),
              let pending = FormValidator.normalizedNonNegativeAmount(from: currentDebt),
              let monthly = FormValidator.normalizedPositiveAmount(from: monthlyPayment),
              let installments = normalizedInstallmentCount else {
            return nil
        }

        let paid = max(principal - pending, 0)
        let remainingInstallments = min(Int(ceil(pending / monthly)), installments)

        if settings.language == .spanish {
            return "Pagado: \(settings.secureCurrency(paid)) · Pendiente: \(settings.secureCurrency(pending)) · Cuotas restantes aprox.: \(remainingInstallments)"
        }

        return "Paid: \(settings.secureCurrency(paid)) · Remaining: \(settings.secureCurrency(pending)) · Approx. remaining installments: \(remainingInstallments)"
    }

    private var creditCardMinimumPaymentPreview: String? {
        guard let pending = FormValidator.normalizedNonNegativeAmount(from: currentDebt),
              let rate = FormValidator.normalizedNonNegativeAmount(from: minimumPaymentRatePercent) else {
            return nil
        }

        let fee = FormValidator.normalizedNonNegativeAmount(from: managementFee) ?? 0
        let fixedMinimum = FormValidator.normalizedNonNegativeAmount(from: minimumPaymentFixedAmount) ?? 0
        let percentageMinimum = pending * (rate / 100)
        let baseMinimum = min(max(percentageMinimum, fixedMinimum), pending)
        let estimatedTotal = baseMinimum + fee

        if settings.language == .spanish {
            return "Pago mínimo estimado: \(settings.secureCurrency(baseMinimum)) · Con cuota de manejo: \(settings.secureCurrency(estimatedTotal))"
        }

        return "Estimated minimum payment: \(settings.secureCurrency(baseMinimum)) · With management fee: \(settings.secureCurrency(estimatedTotal))"
    }

    private func saveDebt() {
        guard validationMessage == nil else {
            showValidationAlert = true
            return
        }

        guard let principal = FormValidator.normalizedPositiveAmount(from: totalLimit),
              let pending = FormValidator.normalizedNonNegativeAmount(from: currentDebt) else {
            showValidationAlert = true
            return
        }

        let trimmedName = FormValidator.trim(cardName)
        let debtId = existingDebt?.id ?? UUID()

        var savedDebt: Debt

        switch selectedKind {
        case .creditCard:
            let parsedRate = FormValidator.normalizedNonNegativeAmount(from: minimumPaymentRatePercent) ?? 5
            let parsedManagementFee = FormValidator.normalizedNonNegativeAmount(from: managementFee) ?? 0
            let parsedFixedMinimum = FormValidator.normalizedNonNegativeAmount(from: minimumPaymentFixedAmount)

            savedDebt = Debt(
                id: debtId,
                cardName: trimmedName,
                brand: selectedBrand,
                totalLimit: principal,
                remainingDebt: pending,
                kind: .creditCard,
                status: existingDebt?.status ?? .active,
                monthlyPayment: nil,
                installmentCount: nil,
                paymentsMade: 0,
                firstPaymentDate: nil,
                linkedRecurringPaymentId: nil,
                managementFee: parsedManagementFee,
                minimumPaymentRate: parsedRate / 100,
                minimumPaymentFixedAmount: parsedFixedMinimum,
                statementClosingDay: statementClosingDay,
                minimumPaymentDueDay: minimumPaymentDueDay
            )

            removeLinkedRecurringPaymentIfNeeded(for: existingDebt)

        case .loan:
            guard let parsedMonthlyPayment = FormValidator.normalizedPositiveAmount(from: monthlyPayment),
                  let parsedInstallmentCount = normalizedInstallmentCount else {
                showValidationAlert = true
                return
            }

            let paidAmount = max(principal - pending, 0)
            let estimatedPaymentsMade = min(
                Int(floor(paidAmount / parsedMonthlyPayment)),
                parsedInstallmentCount
            )

            savedDebt = Debt(
                id: debtId,
                cardName: trimmedName,
                brand: .other,
                totalLimit: principal,
                remainingDebt: pending,
                kind: .loan,
                status: pending <= 0 ? .paid : .active,
                monthlyPayment: parsedMonthlyPayment,
                installmentCount: parsedInstallmentCount,
                paymentsMade: existingDebt?.paymentsMade ?? estimatedPaymentsMade,
                firstPaymentDate: firstPaymentDate,
                linkedRecurringPaymentId: existingDebt?.linkedRecurringPaymentId,
                managementFee: 0,
                minimumPaymentRate: 0.05,
                minimumPaymentFixedAmount: nil,
                statementClosingDay: nil,
                minimumPaymentDueDay: nil
            )

            syncRecurringPaymentIfNeeded(for: &savedDebt)
        }

        onSave(savedDebt)
        dismiss()
    }

    private func syncRecurringPaymentIfNeeded(for debt: inout Debt) {
        guard selectedKind == .loan else { return }

        guard shouldCreateRecurringPayment,
              let parsedMonthlyPayment = FormValidator.normalizedPositiveAmount(from: monthlyPayment) else {
            removeLinkedRecurringPaymentIfNeeded(for: debt)
            debt.linkedRecurringPaymentId = nil
            return
        }

        var payments = DataManager.shared.loadRecurringPayments(user: auth.currentUser)
        let recurringId = debt.linkedRecurringPaymentId ?? UUID()

        if let index = payments.firstIndex(where: { $0.id == recurringId || $0.linkedDebtId == debt.id }) {
            let existingPayment = payments[index]

            payments[index] = RecurringPayment(
                id: existingPayment.id,
                title: debt.cardName,
                amount: parsedMonthlyPayment,
                dueDay: firstPaymentDay,
                category: .loans,
                customCategoryName: localized("Préstamo", "Loan"),
                isActive: debt.status == .active,
                lastPaidMonth: existingPayment.lastPaidMonth,
                lastPaidYear: existingPayment.lastPaidYear,
                lastPaidExpenseId: existingPayment.lastPaidExpenseId,
                linkedDebtId: debt.id
            )

            debt.linkedRecurringPaymentId = existingPayment.id
        } else {
            let newPayment = RecurringPayment(
                id: recurringId,
                title: debt.cardName,
                amount: parsedMonthlyPayment,
                dueDay: firstPaymentDay,
                category: .loans,
                customCategoryName: localized("Préstamo", "Loan"),
                isActive: debt.status == .active,
                linkedDebtId: debt.id
            )

            payments.append(newPayment)
            debt.linkedRecurringPaymentId = recurringId
        }

        DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
    }

    private func removeLinkedRecurringPaymentIfNeeded(for debt: Debt?) {
        guard let debt else { return }

        var payments = DataManager.shared.loadRecurringPayments(user: auth.currentUser)
        let originalCount = payments.count

        payments.removeAll { payment in
            payment.id == debt.linkedRecurringPaymentId || payment.linkedDebtId == debt.id
        }

        if payments.count != originalCount {
            DataManager.shared.saveRecurringPayments(payments, user: auth.currentUser)
        }
    }

    private var navigationTitle: String {
        if isEditing {
            return selectedKind == .loan
            ? localized("Editar préstamo", "Edit loan")
            : localized("Editar tarjeta", "Edit card")
        }

        return selectedKind == .loan
        ? localized("Nuevo préstamo", "New loan")
        : settings.t("debts.newCard")
    }

    private var typePickerTitle: String {
        localized("Tipo de deuda", "Debt type")
    }

    private var generalSectionTitle: String {
        selectedKind == .loan
        ? localized("Información del préstamo", "Loan information")
        : localized("Información de la tarjeta", "Card information")
    }

    private var nameFieldTitle: String {
        selectedKind == .loan
        ? localized("Nombre del préstamo", "Loan name")
        : settings.t("debts.cardName")
    }

    private var principalFieldTitle: String {
        selectedKind == .loan
        ? localized("Monto total del préstamo", "Total loan amount")
        : settings.t("debts.totalLimit")
    }

    private var pendingFieldTitle: String {
        selectedKind == .loan
        ? localized("Saldo pendiente", "Remaining balance")
        : settings.t("debts.currentDebt")
    }

    private func localized(_ spanish: String, _ english: String) -> String {
        settings.language == .spanish ? spanish : english
    }

    private static func makeAmountText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(
            .number.precision(.fractionLength(0...2))
        )
    }

    private static func makePercentText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(
            .number.precision(.fractionLength(0...2))
        )
    }
}

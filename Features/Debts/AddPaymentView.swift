import SwiftUI

struct AddPaymentView: View {

    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    @Binding var debt: Debt

    @State private var payment = ""
    @State private var selectedMoneyAccountId: UUID?
    @State private var showValidationAlert = false
    @State private var showFinalPaymentAlert = false

    private let moneyAccounts: [MoneyAccount]
    let onApplyPayment: (Double, UUID) -> Void
    let onMarkDebtAsPaid: (Debt) -> Void

    private let moneyAccountFundsGuard = MoneyAccountFundsGuard()

    init(
        debt: Binding<Debt>,
        moneyAccounts: [MoneyAccount],
        onApplyPayment: @escaping (Double, UUID) -> Void,
        onMarkDebtAsPaid: @escaping (Debt) -> Void
    ) {
        self._debt = debt

        let sortedAccounts = moneyAccounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        self.moneyAccounts = sortedAccounts
        self.onApplyPayment = onApplyPayment
        self.onMarkDebtAsPaid = onMarkDebtAsPaid
        _selectedMoneyAccountId = State(initialValue: sortedAccounts.first?.id)
    }

    private var validationError: FormValidationError? {
        FormValidator.validateDebtPayment(
            payment: payment,
            remainingDebt: debt.remainingDebt
        )
    }

    private var accountValidationMessage: String? {
        if moneyAccounts.isEmpty {
            return settings.language == .spanish
            ? "Debes crear al menos una cuenta de dinero antes de registrar este pago."
            : "You need to create at least one money account before registering this payment."
        }

        if selectedMoneyAccountId == nil {
            return settings.language == .spanish
            ? "Selecciona la cuenta desde donde saldrá este pago."
            : "Select the account this payment will come from."
        }

        return nil
    }

    private var moneyAccountLimitImpact: MoneyAccountFundsImpact? {
        guard let parsedAmount = FormValidator.normalizedPositiveAmount(from: payment) else {
            return nil
        }

        return moneyAccountFundsGuard.debtPaymentImpact(
            requestedAmount: parsedAmount,
            selectedAccountId: selectedMoneyAccountId,
            accounts: moneyAccounts
        )
    }

    private var balanceValidationMessage: String? {
        guard let impact = moneyAccountLimitImpact, impact.wouldGoNegative else {
            return nil
        }

        if settings.language == .spanish {
            return "Este pago dejaría en negativo la cuenta \"\(impact.accountName)\". Máximo permitido: \(settings.secureCurrency(impact.allowedAmount)). Saldo actual: \(settings.secureCurrency(impact.availableBalance))."
        } else {
            return "This payment would overdraw the account \"\(impact.accountName)\". Maximum allowed: \(settings.secureCurrency(impact.allowedAmount)). Current balance: \(settings.secureCurrency(impact.availableBalance))."
        }
    }

    private var activeValidationMessage: String? {
        validationError?.message(language: settings.language)
        ?? accountValidationMessage
        ?? balanceValidationMessage
    }

    private var validationAlertTitle: String {
        if let validationError {
            return validationError.title(language: settings.language)
        }

        if accountValidationMessage != nil {
            return settings.language == .spanish
            ? "Cuenta requerida"
            : "Account required"
        }

        if balanceValidationMessage != nil {
            return settings.language == .spanish
            ? "Fondos insuficientes"
            : "Insufficient funds"
        }

        return settings.language == .spanish
        ? "Validación pendiente"
        : "Pending validation"
    }

    private var screenTitle: String {
        if debt.isLoan {
            return settings.language == .spanish ? "Pagar préstamo" : "Pay loan"
        }

        return settings.t("debts.registerPayment")
    }

    private var pendingBalanceText: String {
        if debt.isLoan {
            return settings.language == .spanish
            ? "Saldo pendiente"
            : "Remaining balance"
        }

        return settings.t("debts.balancePending")
    }

    private var paymentHelpText: String {
        if debt.isLoan {
            return settings.language == .spanish
            ? "Al aplicar el pago, bajará el saldo del préstamo, se descontará de la cuenta seleccionada y se actualizarán las cuotas pagadas."
            : "When applied, this payment will reduce the loan balance, deduct the selected account and update paid installments."
        }

        return settings.language == .spanish
        ? "Al aplicar el pago, bajará la deuda de la tarjeta y también se descontará el saldo de la cuenta seleccionada."
        : "When you apply this payment, the card debt will go down and the selected account balance will also be deducted."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(pendingBalanceText): \(settings.formatCurrency(debt.remainingDebt, decimals: 2))")
                        .fontWeight(.semibold)

                    if debt.isLoan {
                        loanProgressPreview
                    }

                    MoneyTextField(
                        title: settings.t("debts.paymentAmount"),
                        text: $payment,
                        accessibilityIdentifier: "debt.payment.field"
                    )

                    if let preview = paymentPreviewText {
                        Text(preview)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section(
                    header: Text(settings.language == .spanish ? "Origen del dinero" : "Money source")
                ) {
                    if moneyAccounts.isEmpty {
                        Text(
                            settings.language == .spanish
                            ? "No tienes cuentas disponibles. Crea una cuenta de dinero primero."
                            : "You do not have any available accounts. Create a money account first."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    } else {
                        Picker(
                            settings.language == .spanish ? "Cuenta de salida" : "Source account",
                            selection: $selectedMoneyAccountId
                        ) {
                            Text(settings.language == .spanish ? "Selecciona una cuenta" : "Select an account")
                                .tag(nil as UUID?)

                            ForEach(moneyAccounts) { account in
                                Text("\(account.name) · \(settings.secureCurrency(account.balance))")
                                    .tag(account.id as UUID?)
                            }
                        }
                        .accessibilityIdentifier("debt.payment.account.picker")

                        Text(paymentHelpText)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                if let activeValidationMessage {
                    Section {
                        Text(activeValidationMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(screenTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.t("debts.apply")) {
                        applyPayment()
                    }
                    .disabled(activeValidationMessage != nil)
                }
            }
            .alert(
                validationAlertTitle,
                isPresented: $showValidationAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(activeValidationMessage ?? "")
            }
            .alert(
                settings.language == .spanish ? "Deuda pagada" : "Debt paid",
                isPresented: $showFinalPaymentAlert
            ) {
                Button(
                    settings.language == .spanish ? "Mover a pagadas" : "Move to paid"
                ) {
                    var paidDebt = debt
                    paidDebt.markAsPaid()
                    onMarkDebtAsPaid(paidDebt)
                    dismiss()
                }

                Button(
                    settings.language == .spanish ? "Mantener activa" : "Keep active",
                    role: .cancel
                ) {
                    dismiss()
                }
            } message: {
                Text(
                    settings.language == .spanish
                    ? "Este fue el último pago de \"\(debt.cardName)\". ¿Quieres mover esta deuda a la sección de pagadas y quitar su pago fijo vinculado?"
                    : "This was the final payment for \"\(debt.cardName)\". Do you want to move this debt to paid and remove its linked recurring payment?"
                )
            }
        }
    }

    private var loanProgressPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(settings.language == .spanish ? "Cuotas pagadas" : "Paid installments")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(installmentText)
                    .font(.caption.bold())
            }

            ProgressView(value: debt.progress)
                .tint(BrandPalette.primary)
        }
        .padding(.vertical, 4)
    }

    private var paymentPreviewText: String? {
        guard let value = FormValidator.normalizedPositiveAmount(from: payment) else {
            return nil
        }

        let remainingAfterPayment = max(debt.remainingDebt - value, 0)

        if debt.isLoan {
            if settings.language == .spanish {
                return "Después de este pago quedaría pendiente \(settings.secureCurrency(remainingAfterPayment))."
            }

            return "After this payment, \(settings.secureCurrency(remainingAfterPayment)) would remain."
        }

        if settings.language == .spanish {
            return "Después de este pago la deuda de la tarjeta quedaría en \(settings.secureCurrency(remainingAfterPayment))."
        }

        return "After this payment, the card debt would be \(settings.secureCurrency(remainingAfterPayment))."
    }

    private var installmentText: String {
        guard let installmentCount = debt.installmentCount else {
            return settings.language == .spanish ? "Sin cuotas" : "No installments"
        }

        return "\(debt.paymentsMade)/\(installmentCount)"
    }

    private func applyPayment() {
        guard validationError == nil,
              accountValidationMessage == nil,
              balanceValidationMessage == nil else {
            showValidationAlert = true
            return
        }

        guard let value = FormValidator.normalizedPositiveAmount(from: payment) else {
            showValidationAlert = true
            return
        }

        guard let selectedMoneyAccountId else {
            showValidationAlert = true
            return
        }

        let previousDebt = debt
        debt.applyPayment(value)

        onApplyPayment(value, selectedMoneyAccountId)

        let accountName = moneyAccounts.first(where: { $0.id == selectedMoneyAccountId })?.name ?? "Unknown"

        AuditLogStore.shared.logDebtPaymentApplied(
            from: previousDebt,
            to: debt,
            amount: value,
            fromAccountName: accountName,
            source: .debtPaymentSheet,
            user: auth.currentUser
        )

        if debt.isFullyPaid {
            showFinalPaymentAlert = true
        } else {
            dismiss()
        }
    }
}

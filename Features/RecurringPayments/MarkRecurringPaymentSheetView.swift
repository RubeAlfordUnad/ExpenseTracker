import SwiftUI

struct MarkRecurringPaymentSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings

    let payment: RecurringPayment
    let moneyAccounts: [MoneyAccount]
    let onConfirm: (UUID) -> Void
    
    private let moneyAccountFundsGuard = MoneyAccountFundsGuard()

    @State private var selectedMoneyAccountId: UUID?
    @State private var showValidationAlert = false
    
    init(
        payment: RecurringPayment,
        moneyAccounts: [MoneyAccount],
        onConfirm: @escaping (UUID) -> Void
    ) {
        self.payment = payment

        let sortedAccounts = moneyAccounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        self.moneyAccounts = sortedAccounts
        self.onConfirm = onConfirm
        _selectedMoneyAccountId = State(initialValue: sortedAccounts.first?.id)
    }

    private var baseValidationMessage: String? {
        if moneyAccounts.isEmpty {
            return settings.language == .spanish
                ? "Debes crear una cuenta de dinero antes de marcar este pago como pagado."
                : "You need to create a money account before marking this payment as paid."
        }

        if selectedMoneyAccountId == nil {
            return settings.language == .spanish
                ? "Selecciona la cuenta desde donde saldrá este pago."
                : "Select the account this payment will come from."
        }

        return nil
    }

    private var moneyAccountLimitImpact: MoneyAccountFundsImpact? {
        guard baseValidationMessage == nil else { return nil }

        return moneyAccountFundsGuard.recurringPaymentImpact(
            paymentAmount: payment.amount,
            selectedAccountId: selectedMoneyAccountId,
            accounts: moneyAccounts
        )
    }

    private var balanceValidationMessage: String? {
        guard let impact = moneyAccountLimitImpact, impact.wouldGoNegative else {
            return nil
        }

        if settings.language == .spanish {
            return "Este pago fijo dejaría en negativo la cuenta \"\(impact.accountName)\". Máximo permitido: \(settings.secureCurrency(impact.allowedAmount)). Saldo actual: \(settings.secureCurrency(impact.availableBalance))."
        } else {
            return "This recurring payment would overdraw the account \"\(impact.accountName)\". Maximum allowed: \(settings.secureCurrency(impact.allowedAmount)). Current balance: \(settings.secureCurrency(impact.availableBalance))."
        }
    }

    private var validationMessage: String? {
        baseValidationMessage ?? balanceValidationMessage
    }

    private var validationAlertTitle: String {
        if balanceValidationMessage != nil {
            return settings.language == .spanish
                ? "Fondos insuficientes"
                : "Insufficient funds"
        }

        return settings.language == .spanish
            ? "Cuenta requerida"
            : "Account required"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(payment.title)
                            .font(.headline)

                        Text(settings.language == .spanish ? "Monto" : "Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(settings.secureCurrency(payment.amount))
                            .font(.title3.bold())
                            .foregroundColor(BrandPalette.primary)
                    }
                }
                .alert(
                    validationAlertTitle,
                    isPresented: $showValidationAlert
                ) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(validationMessage ?? "")
                }

                Section(
                    header: Text(settings.language == .spanish ? "Cuenta de salida" : "Source account")
                ) {
                    if moneyAccounts.isEmpty {
                        Text(
                            settings.language == .spanish
                                ? "No tienes cuentas disponibles. Crea una cuenta primero."
                                : "You do not have any available accounts. Create an account first."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    } else {
                        Picker(
                            settings.language == .spanish ? "Cuenta" : "Account",
                            selection: $selectedMoneyAccountId
                        ) {
                            Text(settings.language == .spanish ? "Selecciona una cuenta" : "Select an account")
                                .tag(nil as UUID?)

                            ForEach(moneyAccounts) { account in
                                Text("\(account.name) · \(settings.secureCurrency(account.balance))")
                                    .tag(account.id as UUID?)
                            }
                        }
                        .accessibilityIdentifier("recurring.payment.account.picker")

                        Text(
                            settings.language == .spanish
                                ? "Al confirmar, este pago fijo se marcará como pagado, se descontará de la cuenta seleccionada y se registrará como gasto en el historial."
                                : "When you confirm, this recurring payment will be marked as paid, deducted from the selected account, and recorded as an expense in history."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(settings.language == .spanish ? "Marcar como pagado" : "Mark as paid")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.language == .spanish ? "Confirmar" : "Confirm") {
                        confirm()
                    }
                    .disabled(validationMessage != nil)
                }
            }
        }
    }

    private func confirm() {
        guard validationMessage == nil else {
            showValidationAlert = true
            return
        }

        guard let selectedMoneyAccountId else {
            showValidationAlert = true
            return
        }

        onConfirm(selectedMoneyAccountId)
        dismiss()
    }
}

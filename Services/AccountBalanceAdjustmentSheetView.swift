import SwiftUI

struct AccountBalanceAdjustmentSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @State private var targetBalanceText: String
    @State private var date: Date
    @State private var reason: String = ""
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    let account: MoneyAccount
    let onSave: (AccountBalanceAdjustment) -> Void

    private let adjustmentSync = AccountBalanceAdjustmentSync()

    init(
        account: MoneyAccount,
        onSave: @escaping (AccountBalanceAdjustment) -> Void
    ) {
        self.account = account
        self.onSave = onSave
        _targetBalanceText = State(initialValue: Self.makeAmountText(account.balance))
        _date = State(initialValue: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(settings.language == .spanish ? "Cuenta" : "Account")
                        Spacer()
                        Text(account.name)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(settings.language == .spanish ? "Saldo actual" : "Current balance")
                        Spacer()
                        Text(settings.secureCurrency(account.balance))
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    MoneyTextField(
                        title: settings.language == .spanish ? "Saldo real" : "Actual balance",
                        text: $targetBalanceText,
                        accessibilityIdentifier: "moneyAccounts.adjustment.targetBalance"
                    )

                    DatePicker(
                        settings.language == .spanish ? "Fecha del ajuste" : "Adjustment date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("moneyAccounts.adjustment.date")

                    TextField(
                        settings.language == .spanish ? "Motivo (opcional)" : "Reason (optional)",
                        text: $reason,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .accessibilityIdentifier("moneyAccounts.adjustment.reason")
                } header: {
                    Text(settings.language == .spanish ? "Nuevo saldo" : "New balance")
                } footer: {
                    Text(
                        settings.language == .spanish
                        ? "Esto no edita la cuenta en silencio. Se guardará un ajuste real para explicar la diferencia entre el saldo de la app y el saldo real."
                        : "This does not silently edit the account. A real adjustment will be saved to explain the difference between the app balance and the real balance."
                    )
                }

                if let targetBalance = parsedTargetBalance,
                   let delta = adjustmentSync.deltaNeeded(currentBalance: account.balance, targetBalance: targetBalance) {
                    Section(settings.language == .spanish ? "Vista previa" : "Preview") {
                        HStack {
                            Text(settings.language == .spanish ? "Saldo final" : "Final balance")
                            Spacer()
                            Text(settings.secureCurrency(targetBalance))
                        }

                        HStack {
                            Text(settings.language == .spanish ? "Movimiento del ajuste" : "Adjustment movement")
                            Spacer()
                            Text(formattedSignedCurrency(delta))
                                .foregroundColor(delta >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle(settings.language == .spanish ? "Ajustar saldo" : "Adjust balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("common.save")) {
                        save()
                    }
                }
            }
            .alert(
                settings.language == .spanish ? "Datos inválidos" : "Invalid data",
                isPresented: $showValidationAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }

    private var parsedTargetBalance: Double? {
        FormValidator.normalizedNonNegativeAmount(from: targetBalanceText)
    }

    private func save() {
        guard let targetBalance = parsedTargetBalance else {
            validationMessage = settings.language == .spanish
            ? "Ingresa un saldo real válido igual o mayor que cero."
            : "Enter a valid actual balance equal to or greater than zero."
            showValidationAlert = true
            return
        }

        guard date <= Date() else {
            validationMessage = settings.language == .spanish
            ? "La fecha del ajuste no puede estar en el futuro."
            : "The adjustment date cannot be in the future."
            showValidationAlert = true
            return
        }

        guard let delta = adjustmentSync.deltaNeeded(currentBalance: account.balance, targetBalance: targetBalance) else {
            validationMessage = settings.language == .spanish
            ? "No hay diferencia entre el saldo actual y el saldo real."
            : "There is no difference between the current balance and the actual balance."
            showValidationAlert = true
            return
        }

        let adjustment = AccountBalanceAdjustment(
            moneyAccountId: account.id,
            amount: delta,
            date: date,
            reason: reason
        )

        onSave(adjustment)
        dismiss()
    }

    private func formattedSignedCurrency(_ value: Double) -> String {
        let absolute = settings.secureCurrency(abs(value))
        return value >= 0 ? "+\(absolute)" : "-\(absolute)"
    }

    private static func makeAmountText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
    }
}

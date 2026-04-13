import SwiftUI

struct AddTransferView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @State private var fromAccountId: UUID?
    @State private var toAccountId: UUID?
    @State private var amount: String
    @State private var transferDate: Date
    @State private var note: String
    @State private var showValidationAlert = false

    let existingTransfer: AccountTransfer?
    let moneyAccounts: [MoneyAccount]
    let onSave: (AccountTransfer) -> Void
    
    private let moneyAccountFundsGuard = MoneyAccountFundsGuard()
    init(
        existingTransfer: AccountTransfer? = nil,
        moneyAccounts: [MoneyAccount],
        onSave: @escaping (AccountTransfer) -> Void
    ) {
        let sortedAccounts = moneyAccounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        self.existingTransfer = existingTransfer
        self.moneyAccounts = sortedAccounts
        self.onSave = onSave

        func validAccountId(_ id: UUID?) -> UUID? {
            guard let id else { return nil }
            return sortedAccounts.contains(where: { $0.id == id }) ? id : nil
        }

        let initialFrom = validAccountId(existingTransfer?.fromAccountId) ?? sortedAccounts.first?.id
        let initialTo: UUID? = {
            let candidate = validAccountId(existingTransfer?.toAccountId)
            if let candidate, candidate != initialFrom {
                return candidate
            }

            return sortedAccounts.first(where: { $0.id != initialFrom })?.id
        }()

        _fromAccountId = State(initialValue: initialFrom)
        _toAccountId = State(initialValue: initialTo)
        _amount = State(initialValue: existingTransfer.map { Self.makeAmountText($0.amount) } ?? "")
        _transferDate = State(initialValue: existingTransfer?.date ?? Date())
        _note = State(initialValue: existingTransfer?.note ?? "")
    }

    private var isEditing: Bool {
        existingTransfer != nil
    }

    private var baseValidationMessage: String? {
        guard moneyAccounts.count >= 2 else {
            return settings.language == .spanish
            ? "Necesitas al menos dos cuentas para registrar una transferencia."
            : "You need at least two accounts to record a transfer."
        }

        guard fromAccountId != nil, toAccountId != nil else {
            return settings.language == .spanish
            ? "Selecciona cuenta origen y cuenta destino."
            : "Select both source and destination accounts."
        }

        guard fromAccountId != toAccountId else {
            return settings.language == .spanish
            ? "La cuenta origen y destino no pueden ser la misma."
            : "Source and destination accounts cannot be the same."
        }

        guard FormValidator.normalizedPositiveAmount(from: amount) != nil else {
            return settings.language == .spanish
            ? "Ingresa un monto válido mayor que cero."
            : "Enter a valid amount greater than zero."
        }

        return nil
    }

    private var moneyAccountLimitImpact: MoneyAccountFundsImpact? {
        guard baseValidationMessage == nil,
              let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount) else {
            return nil
        }

        return moneyAccountFundsGuard.transferImpact(
            requestedAmount: parsedAmount,
            fromAccountId: fromAccountId,
            existingTransfer: existingTransfer,
            accounts: moneyAccounts
        )
    }

    private var balanceValidationMessage: String? {
        guard let impact = moneyAccountLimitImpact, impact.wouldGoNegative else {
            return nil
        }

        if settings.language == .spanish {
            return "Esta transferencia dejaría en negativo la cuenta \"\(impact.accountName)\". Máximo permitido: \(settings.secureCurrency(impact.allowedAmount)). Saldo actual: \(settings.secureCurrency(impact.availableBalance))."
        } else {
            return "This transfer would overdraw the account \"\(impact.accountName)\". Maximum allowed: \(settings.secureCurrency(impact.allowedAmount)). Current balance: \(settings.secureCurrency(impact.availableBalance))."
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
        ? "Datos inválidos"
        : "Invalid data"
    }

    var body: some View {
        Form {
            if moneyAccounts.count < 2 {
                Section {
                    Text(
                        settings.language == .spanish
                        ? "Primero crea al menos dos cuentas en “Dónde está tu dinero”."
                        : "First create at least two accounts in “Where your money is”."
                    )
                    .foregroundColor(.secondary)
                }
            } else {
                Section {
                    Picker(
                        settings.language == .spanish ? "Sale de" : "Comes from",
                        selection: $fromAccountId
                    ) {
                        ForEach(moneyAccounts) { account in
                            Text("\(account.name) · \(settings.secureCurrency(account.balance))")
                                .tag(account.id as UUID?)
                        }
                    }
                    .accessibilityIdentifier("transfer.from.picker")

                    Picker(
                        settings.language == .spanish ? "Entra a" : "Goes to",
                        selection: $toAccountId
                    ) {
                        ForEach(moneyAccounts) { account in
                            Text("\(account.name) · \(settings.secureCurrency(account.balance))")
                                .tag(account.id as UUID?)
                        }
                    }
                    .accessibilityIdentifier("transfer.to.picker")

                    MoneyTextField(
                        title: settings.language == .spanish ? "Monto" : "Amount",
                        text: $amount,
                        accessibilityIdentifier: "transfer.amount.field"
                    )

                    DatePicker(
                        settings.language == .spanish ? "Fecha" : "Date",
                        selection: $transferDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("transfer.date.field")
                } header: {
                    Text(settings.language == .spanish ? "Transferencia" : "Transfer")
                }

                Section {
                    TextField(
                        settings.language == .spanish ? "Nota (opcional)" : "Note (optional)",
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .accessibilityIdentifier("transfer.note.field")
                } header: {
                    Text(settings.language == .spanish ? "Nota" : "Note")
                }

                Section {
                    Text(
                        settings.language == .spanish
                        ? "Esta acción solo mueve dinero entre cuentas. No cambia tu presupuesto, ni crea gasto, ni crea ingreso."
                        : "This only moves money between accounts. It does not change your budget or create an expense or income."
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
        .navigationTitle(
            isEditing
            ? (settings.language == .spanish ? "Editar transferencia" : "Edit transfer")
            : (settings.language == .spanish ? "Nueva transferencia" : "New transfer")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(settings.t("common.cancel")) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(settings.t("common.save")) {
                    saveTransfer()
                }
                .disabled(validationMessage != nil)
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
        .onChange(of: fromAccountId) { _, newValue in
            guard let newValue else { return }
            if newValue == toAccountId {
                toAccountId = moneyAccounts.first(where: { $0.id != newValue })?.id
            }
        }
        .onChange(of: toAccountId) { _, newValue in
            guard let newValue else { return }
            if newValue == fromAccountId {
                fromAccountId = moneyAccounts.first(where: { $0.id != newValue })?.id
            }
        }
    }

    private func saveTransfer() {
        guard validationMessage == nil else {
            showValidationAlert = true
            return
        }

        guard let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount),
              let fromAccountId,
              let toAccountId else {
            showValidationAlert = true
            return
        }

        let transfer = AccountTransfer(
            id: existingTransfer?.id ?? UUID(),
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: parsedAmount,
            date: transferDate,
            note: note
        )

        onSave(transfer)
        dismiss()
    }

    private static func makeAmountText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(
            .number.precision(.fractionLength(0...2))
        )
    }
}

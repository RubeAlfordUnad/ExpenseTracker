import SwiftUI

struct AddDebtView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var cardName: String
    @State private var selectedBrand: CardBrand
    @State private var totalLimit: String
    @State private var currentDebt: String
    @State private var showValidationAlert = false

    let existingDebt: Debt?
    var onSave: (Debt) -> Void

    init(existingDebt: Debt? = nil, onSave: @escaping (Debt) -> Void) {
        self.existingDebt = existingDebt
        self.onSave = onSave

        _cardName = State(initialValue: existingDebt?.cardName ?? "")
        _selectedBrand = State(initialValue: existingDebt?.brand ?? .visa)
        _totalLimit = State(initialValue: existingDebt.map { Self.makeAmountText($0.totalLimit) } ?? "")
        _currentDebt = State(initialValue: existingDebt.map { Self.makeAmountText($0.remainingDebt) } ?? "")
    }

    private var validationError: FormValidationError? {
        FormValidator.validateDebt(
            cardName: cardName,
            totalLimit: totalLimit,
            currentDebt: currentDebt
        )
    }

    private var isEditing: Bool {
        existingDebt != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(settings.t("debts.cardName"), text: $cardName)

                Picker(settings.t("debts.brand"), selection: $selectedBrand) {
                    ForEach(CardBrand.allCases, id: \.self) { brand in
                        Text(brand.displayName(language: settings.language))
                    }
                }

                TextField(settings.t("debts.totalLimit"), text: $totalLimit)
                    .keyboardType(.decimalPad)

                TextField(settings.t("debts.currentDebt"), text: $currentDebt)
                    .keyboardType(.decimalPad)

                if let validationError {
                    Section {
                        Text(validationError.message(language: settings.language))
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(
                isEditing
                ? (settings.language == .spanish ? "Editar tarjeta" : "Edit card")
                : settings.t("debts.newCard")
            )
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
                    .disabled(validationError != nil)
                }
            }
            .alert(
                validationError?.title(language: settings.language) ?? "",
                isPresented: $showValidationAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationError?.message(language: settings.language) ?? "")
            }
        }
    }

    private func saveDebt() {
        guard validationError == nil else {
            showValidationAlert = true
            return
        }

        guard let limit = FormValidator.normalizedPositiveAmount(from: totalLimit),
              let debt = FormValidator.normalizedNonNegativeAmount(from: currentDebt) else {
            showValidationAlert = true
            return
        }

        let savedDebt = Debt(
            id: existingDebt?.id ?? UUID(),
            cardName: FormValidator.trim(cardName),
            brand: selectedBrand,
            totalLimit: limit,
            remainingDebt: debt
        )

        onSave(savedDebt)
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

import SwiftUI

struct AddRecurringPaymentView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var title: String
    @State private var amount: String
    @State private var dueDay: Int
    @State private var category: RecurringPaymentCategory
    @State private var isActive: Bool
    @State private var showValidationAlert = false

    let existingPayment: RecurringPayment?
    var onSave: (RecurringPayment) -> Void

    init(
        existingPayment: RecurringPayment? = nil,
        onSave: @escaping (RecurringPayment) -> Void
    ) {
        self.existingPayment = existingPayment
        self.onSave = onSave

        _title = State(initialValue: existingPayment?.title ?? "")
        _amount = State(
            initialValue: existingPayment.map { Self.makeAmountText($0.amount) } ?? ""
        )
        _dueDay = State(initialValue: existingPayment?.dueDay ?? 1)
        _category = State(initialValue: existingPayment?.category ?? .other)
        _isActive = State(initialValue: existingPayment?.isActive ?? true)
    }

    private var validationError: FormValidationError? {
        FormValidator.validateRecurringPayment(
            title: title,
            amount: amount,
            dueDay: dueDay
        )
    }

    private var isEditing: Bool {
        existingPayment != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(settings.t("recurring.form.name"), text: $title)
                    .accessibilityIdentifier("recurring.title.field")

                TextField(settings.t("expense.amount"), text: $amount)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("recurring.amount.field")

                Stepper(
                    settings.tr("recurring.form.day", dueDay),
                    value: $dueDay,
                    in: 1...31
                )
                .accessibilityIdentifier("recurring.day.stepper")

                Picker(settings.t("expense.category"), selection: $category) {
                    ForEach(RecurringPaymentCategory.allCases, id: \.self) { item in
                        Text(item.displayName(language: settings.language))
                    }
                }
                .accessibilityIdentifier("recurring.category.picker")

                Toggle(
                    settings.language == .spanish ? "Activo" : "Active",
                    isOn: $isActive
                )
                .accessibilityIdentifier("recurring.active.toggle")

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
                ? (settings.language == .spanish ? "Editar pago fijo" : "Edit recurring payment")
                : settings.t("recurring.form.new")
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("recurring.cancel.button")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.t("common.save")) {
                        saveRecurringPayment()
                    }
                    .disabled(validationError != nil)
                    .accessibilityIdentifier("recurring.save.button")
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
        .accessibilityIdentifier("recurring.sheet")
    }

    private func saveRecurringPayment() {
        guard validationError == nil else {
            showValidationAlert = true
            return
        }

        guard let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount) else {
            showValidationAlert = true
            return
        }

        let payment = RecurringPayment(
            id: existingPayment?.id ?? UUID(),
            title: FormValidator.trim(title),
            amount: parsedAmount,
            dueDay: dueDay,
            category: category,
            isActive: isActive,
            lastPaidMonth: existingPayment?.lastPaidMonth,
            lastPaidYear: existingPayment?.lastPaidYear
        )

        onSave(payment)
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

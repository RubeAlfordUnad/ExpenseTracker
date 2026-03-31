import SwiftUI

struct AddIncomeView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var title: String
    @State private var amount: String
    @State private var category: IncomeCategory
    @State private var incomeDate: Date
    @State private var showValidationAlert = false

    let existingIncome: Income?
    var onSave: (Income) -> Void

    init(existingIncome: Income? = nil, onSave: @escaping (Income) -> Void) {
        self.existingIncome = existingIncome
        self.onSave = onSave

        _title = State(initialValue: existingIncome?.title ?? "")
        _amount = State(initialValue: existingIncome.map { Self.makeAmountText($0.amount) } ?? "")
        _category = State(initialValue: existingIncome?.category ?? .other)
        _incomeDate = State(initialValue: existingIncome?.date ?? Date())
    }

    private var validationError: FormValidationError? {
        FormValidator.validateIncome(title: title, amount: amount)
    }

    private var isEditing: Bool {
        existingIncome != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(
                    settings.language == .spanish ? "Título" : "Title",
                    text: $title
                )
                .accessibilityIdentifier("income.title.field")

                TextField(
                    settings.language == .spanish ? "Monto" : "Amount",
                    text: $amount
                )
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("income.amount.field")

                DatePicker(
                    settings.language == .spanish ? "Fecha" : "Date",
                    selection: $incomeDate,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("income.date.field")

                Picker(
                    settings.language == .spanish ? "Categoría" : "Category",
                    selection: $category
                ) {
                    ForEach(IncomeCategory.allCases, id: \.self) { item in
                        Text(item.displayName(language: settings.language))
                    }
                }
                .accessibilityIdentifier("income.category.picker")

                if let validationError {
                    Section {
                        Text(validationError.message(language: settings.language))
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .accessibilityIdentifier("income.form")
            .navigationTitle(
                isEditing
                ? (settings.language == .spanish ? "Editar ingreso" : "Edit income")
                : (settings.language == .spanish ? "Nuevo ingreso" : "New income")
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("common.save")) {
                        saveIncome()
                    }
                    .disabled(validationError != nil)
                    .accessibilityIdentifier("income.save.button")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("income.cancel.button")
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
        .accessibilityIdentifier("income.sheet")
    }

    private func saveIncome() {
        guard validationError == nil else {
            showValidationAlert = true
            return
        }

        guard let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount) else {
            showValidationAlert = true
            return
        }

        let savedIncome = Income(
            id: existingIncome?.id ?? UUID(),
            title: FormValidator.trim(title),
            amount: parsedAmount,
            date: incomeDate,
            category: category
        )

        onSave(savedIncome)
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

import SwiftUI

struct AddExpenseView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var title: String
    @State private var amount: String
    @State private var category: Category
    @State private var expenseDate: Date
    @State private var showValidationAlert = false

    let existingExpense: Expense?
    var onSave: (Expense) -> Void

    init(existingExpense: Expense? = nil, onSave: @escaping (Expense) -> Void) {
        self.existingExpense = existingExpense
        self.onSave = onSave

        _title = State(initialValue: existingExpense?.title ?? "")
        _amount = State(initialValue: existingExpense.map { Self.makeAmountText($0.amount) } ?? "")
        _category = State(initialValue: existingExpense?.category ?? .other)
        _expenseDate = State(initialValue: existingExpense?.date ?? Date())
    }

    private var validationError: FormValidationError? {
        FormValidator.validateExpense(title: title, amount: amount)
    }

    private var isEditing: Bool {
        existingExpense != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(settings.t("expense.title"), text: $title)
                    .accessibilityIdentifier("expense.title.field")

                TextField(settings.t("expense.amount"), text: $amount)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("expense.amount.field")

                DatePicker(
                    settings.language == .spanish ? "Fecha" : "Date",
                    selection: $expenseDate,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("expense.date.field")

                Picker(settings.t("expense.category"), selection: $category) {
                    ForEach(Category.allCases, id: \.self) { item in
                        Text(item.displayName(language: settings.language))
                    }
                }
                .accessibilityIdentifier("expense.category.picker")

                if let validationError {
                    Section {
                        Text(validationError.message(language: settings.language))
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .accessibilityIdentifier("expense.form")
            .navigationTitle(
                isEditing
                ? (settings.language == .spanish ? "Editar gasto" : "Edit expense")
                : settings.t("expense.new")
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("common.save")) {
                        saveExpense()
                    }
                    .disabled(validationError != nil)
                    .accessibilityIdentifier("expense.save.button")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("expense.cancel.button")
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
        .accessibilityIdentifier("expense.sheet")
    }

    private func saveExpense() {
        guard validationError == nil else {
            showValidationAlert = true
            return
        }

        guard let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount) else {
            showValidationAlert = true
            return
        }

        let savedExpense = Expense(
            id: existingExpense?.id ?? UUID(),
            title: FormValidator.trim(title),
            amount: parsedAmount,
            date: expenseDate,
            category: category
        )

        onSave(savedExpense)
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

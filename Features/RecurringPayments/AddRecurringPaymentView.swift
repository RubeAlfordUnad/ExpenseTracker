import SwiftUI

struct AddRecurringPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var title: String
    @State private var amount: String
    @State private var dueDay: Int
    @State private var category: RecurringPaymentCategory
    @State private var isActive: Bool

    @State private var showValidationAlert = false
    @State private var showDayPickerSheet = false

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
                Section {
                    TextField(settings.t("recurring.form.name"), text: $title)
                        .accessibilityIdentifier("recurring.title.field")

                    MoneyTextField(
                        title: settings.t("expense.amount"),
                        text: $amount,
                        accessibilityIdentifier: "recurring.amount.field"
                    )
                    .accessibilityIdentifier("recurring.amount.field")

                    Button {
                        showDayPickerSheet = true
                    } label: {
                        HStack {
                            Text(recurringDayLabel)
                                .foregroundColor(.primary)

                            Spacer()

                            Text("\(dueDay)")
                                .foregroundColor(.secondary)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recurring.day.button")

                    Picker(settings.t("expense.category"), selection: $category) {
                        ForEach(RecurringPaymentCategory.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                        }
                    }
                    .accessibilityIdentifier("recurring.category.picker")

                    Toggle(activeToggleTitle, isOn: $isActive)
                        .accessibilityIdentifier("recurring.active.toggle")
                }

                if let validationError {
                    Section {
                        Text(validationError.message(language: settings.language))
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
            .sheet(isPresented: $showDayPickerSheet) {
                recurringDayPickerSheet
            }
        }
        .accessibilityIdentifier("recurring.sheet")
    }

    private var recurringDayPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(recurringDayLabel, selection: $dueDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text(dayTitle(for: day)).tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle(recurringDayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        showDayPickerSheet = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.t("common.save")) {
                        showDayPickerSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
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

    private var navigationTitle: String {
        if isEditing {
            return settings.language == .spanish
                ? "Editar pago fijo"
                : "Edit recurring payment"
        }
        return settings.t("recurring.form.new")
    }

    private var recurringDayLabel: String {
        settings.language == .spanish ? "Día de cobro" : "Due day"
    }

    private var activeToggleTitle: String {
        settings.language == .spanish ? "Activo" : "Active"
    }

    private func dayTitle(for day: Int) -> String {
        if settings.language == .spanish {
            return "Día \(day)"
        }
        return "Day \(day)"
    }

    private static func makeAmountText(_ value: Double) -> String {
        let rounded = value.rounded()
        if rounded == value {
            return String(Int(value))
        }
        return String(value)
    }
}

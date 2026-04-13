import SwiftUI

struct AddRecurringPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var title: String
    @State private var amount: String
    @State private var dueDay: Int
    @State private var category: RecurringPaymentCategory
    @State private var customCategoryName: String
    @State private var isActive: Bool

    @State private var customCategories: [CustomRecurringPaymentCategory] = []
    @State private var showManageCategories = false
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
        _customCategoryName = State(initialValue: existingPayment?.customCategoryName ?? "")
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
                                .tag(item)
                        }
                    }
                    .accessibilityIdentifier("recurring.category.picker")

                    Toggle(activeToggleTitle, isOn: $isActive)
                        .accessibilityIdentifier("recurring.active.toggle")
                }

                Section {
                    TextField(
                        settings.language == .spanish ? "Categoría personalizada (opcional)" : "Custom category (optional)",
                        text: $customCategoryName
                    )
                    .accessibilityIdentifier("recurring.customCategory")

                    if !customCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(customCategories) { item in
                                    Button {
                                        customCategoryName = item.name
                                        category = item.style
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: item.style.icon)
                                            Text(item.name)
                                        }
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(item.style.color)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(item.style.color.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button {
                        saveReusableCustomCategory()
                    } label: {
                        Label(
                            settings.language == .spanish ? "Guardar categoría personalizada" : "Save custom category",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(FormValidator.trim(customCategoryName).isEmpty)

                    Button {
                        showManageCategories = true
                    } label: {
                        Label(
                            settings.language == .spanish ? "Gestionar categorías guardadas" : "Manage saved categories",
                            systemImage: "slider.horizontal.3"
                        )
                    }
                } header: {
                    Text(settings.language == .spanish ? "Categorías" : "Categories")
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
            .sheet(isPresented: $showManageCategories) {
                NavigationStack {
                    CustomCategoriesSettingsView(mode: .recurringPayment)
                        .environmentObject(auth)
                        .environmentObject(settings)
                }
            }
            .onAppear {
                reloadCustomCategories()
            }
            .onChange(of: showManageCategories) { _, isPresented in
                if !isPresented {
                    reloadCustomCategories()
                }
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

    private func reloadCustomCategories() {
        customCategories = TransactionCustomizationStore.shared.loadRecurringPaymentCustomCategories(user: auth.currentUser)
    }

    private func saveReusableCustomCategory() {
        let trimmed = FormValidator.trim(customCategoryName)
        guard !trimmed.isEmpty else { return }

        var items = TransactionCustomizationStore.shared.loadRecurringPaymentCustomCategories(user: auth.currentUser)

        if let index = items.firstIndex(where: { $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
            items[index] = CustomRecurringPaymentCategory(id: items[index].id, name: trimmed, style: category)
        } else {
            items.append(CustomRecurringPaymentCategory(name: trimmed, style: category))
        }

        TransactionCustomizationStore.shared.saveRecurringPaymentCustomCategories(items, user: auth.currentUser)
        reloadCustomCategories()
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
            customCategoryName: FormValidator.trim(customCategoryName).isEmpty ? nil : FormValidator.trim(customCategoryName),
            isActive: isActive,
            lastPaidMonth: existingPayment?.lastPaidMonth,
            lastPaidYear: existingPayment?.lastPaidYear,
            lastPaidExpenseId: existingPayment?.lastPaidExpenseId
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

import SwiftUI

struct AddExpenseView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var auth: AuthManager

    @State private var title: String
    @State private var amount: String
    @State private var category: Category
    @State private var customCategoryName: String
    @State private var comment: String
    @State private var expenseDate: Date
    @State private var customCategories: [CustomExpenseCategory] = []
    @State private var showValidationAlert = false
    @State private var showManageCategories = false
    @State private var selectedMoneyAccountId: UUID?

    let existingExpense: Expense?
    let moneyAccounts: [MoneyAccount]
    let onSave: (Expense) -> Void

    init(
        existingExpense: Expense? = nil,
        moneyAccounts: [MoneyAccount] = [],
        onSave: @escaping (Expense) -> Void
    ) {
        self.existingExpense = existingExpense
        self.moneyAccounts = moneyAccounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        self.onSave = onSave

        let validExistingAccountId = existingExpense?.moneyAccountId.flatMap { existingId in
            moneyAccounts.contains(where: { $0.id == existingId }) ? existingId : nil
        }

        _title = State(initialValue: existingExpense?.title ?? "")
        _amount = State(initialValue: existingExpense.map { Self.makeAmountText($0.amount) } ?? "")
        _category = State(initialValue: existingExpense?.category ?? .other)
        _customCategoryName = State(initialValue: existingExpense?.customCategoryName ?? "")
        _comment = State(initialValue: existingExpense?.comment ?? "")
        _expenseDate = State(initialValue: existingExpense?.date ?? Date())
        _selectedMoneyAccountId = State(initialValue: validExistingAccountId)
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
                Section {
                    TextField(settings.t("expense.title"), text: $title)
                        .accessibilityIdentifier("expense.title.field")

                    MoneyTextField(
                        title: settings.t("expense.amount"),
                        text: $amount,
                        accessibilityIdentifier: "expense.amount.field"
                    )

                    DatePicker(
                        settings.language == .spanish ? "Fecha" : "Date",
                        selection: $expenseDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("expense.date.field")
                }

                Section {
                    Picker(settings.language == .spanish ? "Estilo visual base" : "Base visual style", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                                .tag(item)
                        }
                    }
                    .accessibilityIdentifier("expense.category.picker")

                    TextField(
                        settings.language == .spanish ? "Categoría personalizada (opcional)" : "Custom category (optional)",
                        text: $customCategoryName
                    )
                    .accessibilityIdentifier("expense.customCategory.field")

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
                    .disabled(customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        showManageCategories = true
                    } label: {
                        Label(
                            settings.language == .spanish ? "Gestionar categorías guardadas" : "Manage saved categories",
                            systemImage: "slider.horizontal.3"
                        )
                    }
                } header: {
                    Text(settings.t("expense.category"))
                }

                if !moneyAccounts.isEmpty {
                    Section {
                        Picker(
                            settings.language == .spanish ? "Sale de" : "Comes from",
                            selection: $selectedMoneyAccountId
                        ) {
                            Text(settings.language == .spanish ? "Sin cuenta" : "No account")
                                .tag(nil as UUID?)

                            ForEach(moneyAccounts) { account in
                                Text("\(account.name) · \(settings.secureCurrency(account.balance))")
                                    .tag(account.id as UUID?)
                            }
                        }
                        .accessibilityIdentifier("expense.account.picker")

                        Text(
                            settings.language == .spanish
                            ? "Si eliges una cuenta, al guardar el gasto se descontará automáticamente de ese saldo."
                            : "If you choose an account, saving the expense will automatically deduct it from that balance."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    } header: {
                        Text(settings.language == .spanish ? "Cuenta de salida" : "Source account")
                    }
                }

                Section {
                    TextField(
                        settings.language == .spanish ? "Comentario (opcional)" : "Comment (optional)",
                        text: $comment,
                        axis: .vertical
                    )
                    .lineLimit(3...5)
                    .accessibilityIdentifier("expense.comment.field")
                } header: {
                    Text(settings.language == .spanish ? "Comentario" : "Comment")
                }

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
            .sheet(isPresented: $showManageCategories) {
                NavigationStack {
                    CustomCategoriesSettingsView(mode: .expense)
                        .environmentObject(auth)
                        .environmentObject(settings)
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
            .onAppear {
                reloadCustomCategories()
            }
        }
        .accessibilityIdentifier("expense.sheet")
    }

    private func reloadCustomCategories() {
        customCategories = TransactionCustomizationStore.shared.loadExpenseCustomCategories(user: auth.currentUser)
    }

    private func saveReusableCustomCategory() {
        let trimmed = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var items = TransactionCustomizationStore.shared.loadExpenseCustomCategories(user: auth.currentUser)

        if let index = items.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            items[index] = CustomExpenseCategory(id: items[index].id, name: trimmed, style: category)
        } else {
            items.append(CustomExpenseCategory(name: trimmed, style: category))
        }

        TransactionCustomizationStore.shared.saveExpenseCustomCategories(items, user: auth.currentUser)
        reloadCustomCategories()
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
            category: category,
            customCategoryName: customCategoryName,
            moneyAccountId: selectedMoneyAccountId,
            comment: comment
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

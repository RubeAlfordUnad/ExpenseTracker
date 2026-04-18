import SwiftUI

struct AddIncomeView: View {

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var auth: AuthManager

    @State private var title: String
    @State private var amount: String
    @State private var category: IncomeCategory
    @State private var customCategoryName: String
    @State private var comment: String
    @State private var incomeDate: Date
    @State private var customCategories: [CustomIncomeCategory] = []
    @State private var showValidationAlert = false
    @State private var showManageCategories = false
    @State private var selectedMoneyAccountId: UUID?

    let existingIncome: Income?
    let moneyAccounts: [MoneyAccount]
    let onSave: (Income) -> Void

    init(
        existingIncome: Income? = nil,
        moneyAccounts: [MoneyAccount] = [],
        onSave: @escaping (Income) -> Void
    ) {
        self.existingIncome = existingIncome
        self.moneyAccounts = moneyAccounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        self.onSave = onSave

        let validExistingAccountId = existingIncome?.moneyAccountId.flatMap { existingId in
            moneyAccounts.contains(where: { $0.id == existingId }) ? existingId : nil
        }

        _title = State(initialValue: existingIncome?.title ?? "")
        _amount = State(initialValue: existingIncome.map { Self.makeAmountText($0.amount) } ?? "")
        _category = State(initialValue: existingIncome?.category ?? .other)
        _customCategoryName = State(initialValue: existingIncome?.customCategoryName ?? "")
        _comment = State(initialValue: existingIncome?.comment ?? "")
        let initialIncomeDate = min(existingIncome?.date ?? Date(), Date())
        _incomeDate = State(initialValue: initialIncomeDate)
        _selectedMoneyAccountId = State(initialValue: validExistingAccountId ?? moneyAccounts.first?.id)
    }

    private var validationError: FormValidationError? {
        FormValidator.validateIncome(title: title, amount: amount)
    }

    private var dateValidationMessage: String? {
        guard incomeDate <= Date() else {
            return settings.language == .spanish
            ? "La fecha del ingreso no puede estar en el futuro."
            : "The income date cannot be in the future."
        }

        return nil
    }

    private var accountValidationMessage: String? {
        if moneyAccounts.isEmpty {
            return settings.language == .spanish
            ? "Debes crear al menos una cuenta antes de registrar este ingreso."
            : "You need to create at least one account before registering this income."
        }

        if selectedMoneyAccountId == nil {
            return settings.language == .spanish
            ? "Selecciona la cuenta donde entró este ingreso."
            : "Select the account this income went into."
        }

        return nil
    }

    private var activeValidationMessage: String? {
        validationError?.message(language: settings.language)
        ?? dateValidationMessage
        ?? accountValidationMessage
    }

    private var validationAlertTitle: String {
        if let validationError {
            return validationError.title(language: settings.language)
        }

        if dateValidationMessage != nil {
            return settings.language == .spanish ? "Fecha inválida" : "Invalid date"
        }

        if accountValidationMessage != nil {
            return settings.language == .spanish ? "Cuenta requerida" : "Account required"
        }

        return settings.language == .spanish ? "Datos inválidos" : "Invalid data"
    }

    private var isEditing: Bool {
        existingIncome != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        settings.language == .spanish ? "Título" : "Title",
                        text: $title
                    )
                    .accessibilityIdentifier("income.title.field")

                    MoneyTextField(
                        title: settings.language == .spanish ? "Monto" : "Amount",
                        text: $amount,
                        accessibilityIdentifier: "income.amount.field"
                    )

                    DatePicker(
                        settings.language == .spanish ? "Fecha" : "Date",
                        selection: $incomeDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("income.date.field")
                }

                Section {
                    Picker(
                        settings.language == .spanish ? "Estilo visual base" : "Base visual style",
                        selection: $category
                    ) {
                        ForEach(IncomeCategory.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                                .tag(item)
                        }
                    }
                    .accessibilityIdentifier("income.category.picker")

                    TextField(
                        settings.language == .spanish ? "Categoría personalizada (opcional)" : "Custom category (optional)",
                        text: $customCategoryName
                    )
                    .accessibilityIdentifier("income.customCategory.field")

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
                    Text(settings.language == .spanish ? "Categoría" : "Category")
                }

                if !moneyAccounts.isEmpty {
                    Section {
                        Picker(
                            settings.language == .spanish ? "Entra a" : "Goes to",
                            selection: $selectedMoneyAccountId
                        ) {
                            Text(settings.language == .spanish ? "Selecciona una cuenta" : "Select an account")
                                .tag(nil as UUID?)

                            ForEach(moneyAccounts) { account in
                                Text("\(account.name) · \(settings.secureCurrency(account.balance))")
                                    .tag(account.id as UUID?)
                            }
                        }
                        .accessibilityIdentifier("income.account.picker")

                        Text(
                            settings.language == .spanish
                            ? "Si eliges una cuenta, al guardar el ingreso se sumará automáticamente a ese saldo."
                            : "If you choose an account, saving the income will automatically add it to that balance."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    } header: {
                        Text(settings.language == .spanish ? "Cuenta de destino" : "Destination account")
                    }
                }

                Section {
                    TextField(
                        settings.language == .spanish ? "Comentario (opcional)" : "Comment (optional)",
                        text: $comment,
                        axis: .vertical
                    )
                    .lineLimit(3...5)
                    .accessibilityIdentifier("income.comment.field")
                } header: {
                    Text(settings.language == .spanish ? "Comentario" : "Comment")
                }

                if let activeValidationMessage {
                    Section {
                        Text(activeValidationMessage)
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
                    .disabled(
                        validationError != nil
                        || dateValidationMessage != nil
                        || accountValidationMessage != nil
                    )
                    .accessibilityIdentifier("income.save.button")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("income.cancel.button")
                }
            }
            .sheet(isPresented: $showManageCategories) {
                NavigationStack {
                    CustomCategoriesSettingsView(mode: .income)
                        .environmentObject(auth)
                        .environmentObject(settings)
                }
            }
            .alert(
                validationAlertTitle,
                isPresented: $showValidationAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(activeValidationMessage ?? "")
            }
            .onAppear {
                reloadCustomCategories()
            }
        }
        .accessibilityIdentifier("income.sheet")
    }

    private func reloadCustomCategories() {
        customCategories = TransactionCustomizationStore.shared.loadIncomeCustomCategories(user: auth.currentUser)
    }

    private func saveReusableCustomCategory() {
        let trimmed = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var items = TransactionCustomizationStore.shared.loadIncomeCustomCategories(user: auth.currentUser)

        if let index = items.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            items[index] = CustomIncomeCategory(id: items[index].id, name: trimmed, style: category)
        } else {
            items.append(CustomIncomeCategory(name: trimmed, style: category))
        }

        TransactionCustomizationStore.shared.saveIncomeCustomCategories(items, user: auth.currentUser)
        reloadCustomCategories()
    }

    private func saveIncome() {
        guard validationError == nil,
              dateValidationMessage == nil,
              accountValidationMessage == nil else {
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
            category: category,
            customCategoryName: customCategoryName,
            moneyAccountId: selectedMoneyAccountId,
            comment: comment
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

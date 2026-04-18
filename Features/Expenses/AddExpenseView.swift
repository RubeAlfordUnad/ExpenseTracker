import SwiftUI

private enum ExpenseFundingSource: String, CaseIterable, Identifiable {
    case none
    case moneyAccount
    case creditCard

    var id: String { rawValue }
}

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
    @State private var selectedFundingSource: ExpenseFundingSource
    @State private var selectedMoneyAccountId: UUID?
    @State private var selectedCreditCardId: UUID?

    let existingExpense: Expense?
    let moneyAccounts: [MoneyAccount]
    let debts: [Debt]
    let onSave: (Expense) -> Void
    
    private let moneyAccountFundsGuard = MoneyAccountFundsGuard()
    private let debtSpendingGuard = DebtSpendingGuard()

    init(
        existingExpense: Expense? = nil,
        moneyAccounts: [MoneyAccount] = [],
        debts: [Debt] = [],
        preselectedCreditCardId: UUID? = nil,
        onSave: @escaping (Expense) -> Void
    ) {
        self.existingExpense = existingExpense
        self.moneyAccounts = moneyAccounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        self.debts = debts.sorted {
            $0.cardName.localizedCaseInsensitiveCompare($1.cardName) == .orderedAscending
        }
        self.onSave = onSave

        let validExistingAccountId = existingExpense?.moneyAccountId.flatMap { existingId in
            moneyAccounts.contains(where: { $0.id == existingId }) ? existingId : nil
        }

        let preferredCardId = existingExpense?.creditCardId ?? preselectedCreditCardId
        let validExistingCreditCardId = preferredCardId.flatMap { existingId in
            debts.contains(where: { $0.id == existingId }) ? existingId : nil
        }

        let initialFundingSource: ExpenseFundingSource
        if validExistingCreditCardId != nil {
            initialFundingSource = .creditCard
        } else if validExistingAccountId != nil {
            initialFundingSource = .moneyAccount
        } else if !moneyAccounts.isEmpty {
            initialFundingSource = .moneyAccount
        } else if !debts.isEmpty {
            initialFundingSource = .creditCard
        } else {
            initialFundingSource = .none
        }

        _title = State(initialValue: existingExpense?.title ?? "")
        _amount = State(initialValue: existingExpense.map { Self.makeAmountText($0.amount) } ?? "")
        _category = State(initialValue: existingExpense?.category ?? .other)
        _customCategoryName = State(initialValue: existingExpense?.customCategoryName ?? "")
        _comment = State(initialValue: existingExpense?.comment ?? "")
        let initialExpenseDate = min(existingExpense?.date ?? Date(), Date())
        _expenseDate = State(initialValue: initialExpenseDate)
        _selectedFundingSource = State(initialValue: initialFundingSource)
        _selectedMoneyAccountId = State(initialValue: validExistingAccountId ?? moneyAccounts.first?.id)
        _selectedCreditCardId = State(initialValue: validExistingCreditCardId ?? debts.first?.id)
    }

    private var validationError: FormValidationError? {
        FormValidator.validateExpense(title: title, amount: amount)
    }

    private var fundingValidationMessage: String? {
        if moneyAccounts.isEmpty && debts.isEmpty {
            return settings.language == .spanish
            ? "Debes crear al menos una cuenta de dinero o una tarjeta antes de registrar este gasto."
            : "You need to create at least one money account or card before registering this expense."
        }

        switch selectedFundingSource {
        case .none:
            return settings.language == .spanish
            ? "Selecciona de dónde salió este gasto."
            : "Select where this expense came from."
        case .moneyAccount:
            guard selectedMoneyAccountId == nil else { return nil }
            return settings.language == .spanish
            ? "Selecciona la cuenta desde donde salió este gasto."
            : "Select the account this expense came from."
        case .creditCard:
            guard selectedCreditCardId == nil else { return nil }
            return settings.language == .spanish
            ? "Selecciona la tarjeta usada para este gasto."
            : "Select the card used for this expense."
        }
    }
    
    private var moneyAccountLimitImpact: MoneyAccountFundsImpact? {
        guard selectedFundingSource == .moneyAccount,
              let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount) else {
            return nil
        }

        return moneyAccountFundsGuard.expenseImpact(
            requestedAmount: parsedAmount,
            selectedAccountId: selectedMoneyAccountId,
            existingExpense: existingExpense,
            accounts: moneyAccounts
        )
    }

    private var moneyAccountValidationMessage: String? {
        guard let impact = moneyAccountLimitImpact, impact.wouldGoNegative else {
            return nil
        }

        if settings.language == .spanish {
            return "Este gasto dejaría en negativo la cuenta \"\(impact.accountName)\". Máximo permitido para este gasto: \(settings.secureCurrency(impact.allowedAmount)). Saldo actual: \(settings.secureCurrency(impact.availableBalance))."
        } else {
            return "This expense would overdraw the account \"\(impact.accountName)\". Maximum allowed for this expense: \(settings.secureCurrency(impact.allowedAmount)). Current balance: \(settings.secureCurrency(impact.availableBalance))."
        }
    }
    
    private var creditLimitImpact: DebtSpendingImpact? {
        guard selectedFundingSource == .creditCard,
              let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount) else {
            return nil
        }

        return debtSpendingGuard.impact(
            requestedAmount: parsedAmount,
            selectedDebtId: selectedCreditCardId,
            existingExpense: existingExpense,
            debts: debts
        )
    }

    private var creditLimitValidationMessage: String? {
        guard let impact = creditLimitImpact, impact.exceedsLimit else {
            return nil
        }

        if settings.language == .spanish {
            return "Esta compra supera el cupo disponible de \"\(impact.cardName)\". Máximo permitido para este gasto: \(settings.secureCurrency(impact.allowedAmount)). Disponible actual: \(settings.secureCurrency(impact.availableCredit))."
        } else {
            return "This purchase exceeds the available credit on \"\(impact.cardName)\". Maximum allowed for this expense: \(settings.secureCurrency(impact.allowedAmount)). Current available credit: \(settings.secureCurrency(impact.availableCredit))."
        }
    }

    private var dateValidationMessage: String? {
        guard expenseDate <= Date() else {
            return settings.language == .spanish
            ? "La fecha del gasto no puede estar en el futuro."
            : "The expense date cannot be in the future."
        }

        return nil
    }

    private var activeValidationMessage: String? {
        validationError?.message(language: settings.language)
        ?? dateValidationMessage
        ?? fundingValidationMessage
        ?? moneyAccountValidationMessage
        ?? creditLimitValidationMessage
    }

    private var validationAlertTitle: String {
        if let validationError {
            return validationError.title(language: settings.language)
        }

        if dateValidationMessage != nil {
            return settings.language == .spanish ? "Fecha inválida" : "Invalid date"
        }

        if fundingValidationMessage != nil {
            return settings.language == .spanish ? "Origen incompleto" : "Incomplete source"
        }

        if moneyAccountValidationMessage != nil {
            return settings.language == .spanish ? "Fondos insuficientes" : "Insufficient funds"
        }

        if creditLimitValidationMessage != nil {
            return settings.language == .spanish ? "Cupo insuficiente" : "Insufficient credit limit"
        }

        return settings.language == .spanish ? "Validación pendiente" : "Pending validation"
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
                        in: ...Date(),
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

                if !moneyAccounts.isEmpty || !debts.isEmpty {
                    Section {
                        Picker(
                            settings.language == .spanish ? "Sale desde" : "Paid with",
                            selection: $selectedFundingSource
                        ) {
                            Text(settings.language == .spanish ? "Selecciona un origen" : "Select a source")
                                .tag(ExpenseFundingSource.none)

                            if !moneyAccounts.isEmpty {
                                Text(settings.language == .spanish ? "Cuenta" : "Account")
                                    .tag(ExpenseFundingSource.moneyAccount)
                            }

                            if !debts.isEmpty {
                                Text(settings.language == .spanish ? "Tarjeta" : "Card")
                                    .tag(ExpenseFundingSource.creditCard)
                            }
                        }
                        .accessibilityIdentifier("expense.funding.picker")

                        if selectedFundingSource == .moneyAccount, !moneyAccounts.isEmpty {
                            Picker(
                                settings.language == .spanish ? "Cuenta de salida" : "Source account",
                                selection: $selectedMoneyAccountId
                            ) {
                                Text(settings.language == .spanish ? "Selecciona una cuenta" : "Select an account")
                                    .tag(nil as UUID?)

                                ForEach(moneyAccounts) { account in
                                    Text("\(account.name) · \(settings.secureCurrency(account.balance))")
                                        .tag(account.id as UUID?)
                                }
                            }
                            .accessibilityIdentifier("expense.account.picker")

                            Text(
                                settings.language == .spanish
                                ? "Al guardar, este gasto se descontará automáticamente del saldo de la cuenta seleccionada."
                                : "Saving this expense will automatically deduct it from the selected account balance."
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }

                        if selectedFundingSource == .creditCard, !debts.isEmpty {
                            Picker(
                                settings.language == .spanish ? "Tarjeta usada" : "Used card",
                                selection: $selectedCreditCardId
                            ) {
                                Text(settings.language == .spanish ? "Selecciona una tarjeta" : "Select a card")
                                    .tag(nil as UUID?)

                                ForEach(debts) { debt in
                                    Text("\(debt.cardName) · \(settings.secureCurrency(debt.availableCredit))")
                                        .tag(debt.id as UUID?)
                                }
                            }
                            .accessibilityIdentifier("expense.creditcard.picker")

                            Text(
                                settings.language == .spanish
                                ? "Al guardar, este gasto aumentará automáticamente la deuda pendiente de la tarjeta seleccionada."
                                : "Saving this expense will automatically increase the pending balance of the selected card."
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(settings.language == .spanish ? "Origen del gasto" : "Expense source")
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

                if let activeValidationMessage {
                    Section {
                        Text(activeValidationMessage)
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
                    .disabled(
                        validationError != nil
                        || dateValidationMessage != nil
                        || fundingValidationMessage != nil
                        || moneyAccountValidationMessage != nil
                        || creditLimitValidationMessage != nil
                    )
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
            .onChange(of: selectedFundingSource) { _, newValue in
                switch newValue {
                case .none:
                    selectedMoneyAccountId = nil
                    selectedCreditCardId = nil
                case .moneyAccount:
                    selectedCreditCardId = nil
                case .creditCard:
                    selectedMoneyAccountId = nil
                }
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
        guard validationError == nil,
              dateValidationMessage == nil,
              fundingValidationMessage == nil,
              moneyAccountValidationMessage == nil,
              creditLimitValidationMessage == nil else {
            showValidationAlert = true
            return
        }

        guard let parsedAmount = FormValidator.normalizedPositiveAmount(from: amount) else {
            showValidationAlert = true
            return
        }

        let resolvedMoneyAccountId = selectedFundingSource == .moneyAccount ? selectedMoneyAccountId : nil
        let resolvedCreditCardId = selectedFundingSource == .creditCard ? selectedCreditCardId : nil

        let savedExpense = Expense(
            id: existingExpense?.id ?? UUID(),
            title: FormValidator.trim(title),
            amount: parsedAmount,
            date: expenseDate,
            category: category,
            customCategoryName: customCategoryName,
            moneyAccountId: resolvedMoneyAccountId,
            creditCardId: resolvedCreditCardId,
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

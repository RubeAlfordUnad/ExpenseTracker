import SwiftUI

struct MoneyAccountsSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var auth: AuthManager

    @State private var draftAccounts: [MoneyAccount]
    @State private var activeEditor: MoneyAccountEditorRoute?
    @State private var showDeletionBlockedAlert = false
    @State private var deletionBlockedTitle = ""
    @State private var deletionBlockedMessage = ""

    let expenses: [Expense]
    let incomes: [Income]
    let transfers: [AccountTransfer]
    let startInCreateMode: Bool
    let onSave: ([MoneyAccount]) -> Void

    private let deletionGuard = MoneyAccountDeletionGuard()

    init(
        accounts: [MoneyAccount],
        expenses: [Expense],
        incomes: [Income],
        transfers: [AccountTransfer],
        startInCreateMode: Bool = false,
        onSave: @escaping ([MoneyAccount]) -> Void
    ) {
        _draftAccounts = State(initialValue: accounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        })
        self.expenses = expenses
        self.incomes = incomes
        self.transfers = transfers
        self.startInCreateMode = startInCreateMode
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        settings.language == .spanish
                        ? "Usa esta sección para registrar efectivo, ahorros, billeteras digitales u otras cuentas con saldo. Esto no reemplaza el presupuesto mensual: solo muestra dónde está tu dinero."
                        : "Use this section to track cash, savings, digital wallets, or other balances. This does not replace the monthly budget: it only shows where your money is."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Button {
                        activeEditor = .create
                    } label: {
                        Label(
                            settings.language == .spanish ? "Agregar cuenta" : "Add account",
                            systemImage: "plus.circle.fill"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("moneyAccounts.add")
                }

                if draftAccounts.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(settings.language == .spanish ? "Aún no tienes cuentas" : "You do not have accounts yet")
                                .font(.subheadline.bold())

                            Text(
                                settings.language == .spanish
                                ? "Agrega una cuenta para efectivo, ahorros o cualquier otro fondo manual."
                                : "Add an account for cash, savings, or any other manual fund."
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section(settings.language == .spanish ? "Cuentas" : "Accounts") {
                        ForEach(draftAccounts) { account in
                            Button {
                                activeEditor = .edit(account)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: account.kind.icon)
                                        .foregroundColor(account.kind.color)
                                        .frame(width: 22)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(account.name)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(account.categoryDisplayName(language: settings.language))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if account.hasCustomCategory {
                                            Text(account.kind.displayName(language: settings.language))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        if !account.includeInAvailableTotal {
                                            Text(settings.language == .spanish ? "Excluida del total disponible" : "Excluded from available total")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Text(settings.secureCurrency(account.balance))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteAccount(account)
                                } label: {
                                    Label(settings.language == .spanish ? "Eliminar" : "Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Section {
                        HStack {
                            Text(settings.language == .spanish ? "Fondos disponibles" : "Available funds")
                            Spacer()
                            Text(settings.secureCurrency(availableFunds))
                                .font(.headline)
                        }

                        if excludedCount > 0 {
                            HStack {
                                Text(settings.language == .spanish ? "Cuentas excluidas" : "Excluded accounts")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(excludedCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(settings.language == .spanish ? "Cuentas de dinero" : "Money accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("common.save")) {
                        saveAndDismiss()
                    }
                }
            }
            .sheet(item: $activeEditor) { route in
                MoneyAccountFormView(account: route.account) { savedAccount in
                    upsert(savedAccount)
                }
                .environmentObject(auth)
                .environmentObject(settings)
            }
            .alert(deletionBlockedTitle, isPresented: $showDeletionBlockedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deletionBlockedMessage)
            }
            .onAppear {
                guard startInCreateMode, activeEditor == nil else { return }
                activeEditor = .create
            }
        }
    }

    private var availableFunds: Double {
        draftAccounts
            .filter(\.includeInAvailableTotal)
            .reduce(0) { $0 + $1.balance }
    }

    private var excludedCount: Int {
        draftAccounts.filter { !$0.includeInAvailableTotal }.count
    }

    private func upsert(_ account: MoneyAccount) {
        if let index = draftAccounts.firstIndex(where: { $0.id == account.id }) {
            draftAccounts[index] = account
        } else {
            draftAccounts.append(account)
        }

        draftAccounts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func deleteAccount(_ account: MoneyAccount) {
        let impact = deletionGuard.impact(
            for: account.id,
            expenses: expenses,
            incomes: incomes,
            transfers: transfers
        )

        guard !impact.hasLinkedRecords else {
            presentDeletionBlockedAlert(for: account, impact: impact)
            return
        }

        draftAccounts.removeAll { $0.id == account.id }
    }
    
    private func presentDeletionBlockedAlert(for account: MoneyAccount, impact: MoneyAccountDeletionImpact) {
        deletionBlockedTitle = settings.language == .spanish
        ? "No puedes eliminar esta cuenta"
        : "You cannot delete this account"

        let components = [
            localizedCount(
                impact.expenseCount,
                singularSpanish: "gasto",
                pluralSpanish: "gastos",
                singularEnglish: "expense",
                pluralEnglish: "expenses"
            ),
            localizedCount(
                impact.incomeCount,
                singularSpanish: "ingreso",
                pluralSpanish: "ingresos",
                singularEnglish: "income",
                pluralEnglish: "incomes"
            ),
            localizedCount(
                impact.transferCount,
                singularSpanish: "transferencia",
                pluralSpanish: "transferencias",
                singularEnglish: "transfer",
                pluralEnglish: "transfers"
            )
        ]
        .compactMap { $0 }

        let joined = components.joined(separator: settings.language == .spanish ? ", " : ", ")

        deletionBlockedMessage = settings.language == .spanish
        ? "La cuenta \"\(account.name)\" está siendo usada en \(joined). Reasigna o elimina esos movimientos primero."
        : "The account \"\(account.name)\" is currently used in \(joined). Reassign or delete those records first."

        showDeletionBlockedAlert = true
    }

    private func localizedCount(
        _ count: Int,
        singularSpanish: String,
        pluralSpanish: String,
        singularEnglish: String,
        pluralEnglish: String
    ) -> String? {
        guard count > 0 else { return nil }

        if settings.language == .spanish {
            return "\(count) \(count == 1 ? singularSpanish : pluralSpanish)"
        } else {
            return "\(count) \(count == 1 ? singularEnglish : pluralEnglish)"
        }
    }

    private func saveAndDismiss() {
        onSave(draftAccounts)
        dismiss()
    }
}

private enum MoneyAccountEditorRoute: Identifiable {
    case create
    case edit(MoneyAccount)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let account):
            return account.id.uuidString
        }
    }

    var account: MoneyAccount? {
        switch self {
        case .create:
            return nil
        case .edit(let account):
            return account
        }
    }
}

private struct MoneyAccountFormView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var auth: AuthManager

    @State private var name: String
    @State private var amount: String
    @State private var kind: MoneyAccountKind
    @State private var customCategoryName: String
    @State private var includeInAvailableTotal: Bool

    @State private var customCategories: [CustomMoneyAccountCategory] = []
    @State private var showManageCategories = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    let existingAccount: MoneyAccount?
    let onSave: (MoneyAccount) -> Void

    init(account: MoneyAccount?, onSave: @escaping (MoneyAccount) -> Void) {
        self.existingAccount = account
        self.onSave = onSave

        _name = State(initialValue: account?.name ?? "")
        _amount = State(initialValue: account.map { Self.makeAmountText($0.balance) } ?? "")
        _kind = State(initialValue: account?.kind ?? .cash)
        _customCategoryName = State(initialValue: account?.customCategoryName ?? "")
        _includeInAvailableTotal = State(initialValue: account?.includeInAvailableTotal ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        settings.language == .spanish ? "Nombre de la cuenta" : "Account name",
                        text: $name
                    )
                    .accessibilityIdentifier("moneyAccounts.name")

                    Picker(settings.language == .spanish ? "Tipo base" : "Base type", selection: $kind) {
                        ForEach(MoneyAccountKind.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                                .tag(item)
                        }
                    }
                    .accessibilityIdentifier("moneyAccounts.type")

                    MoneyTextField(
                        title: settings.language == .spanish ? "Saldo" : "Balance",
                        text: $amount,
                        accessibilityIdentifier: "moneyAccounts.balance"
                    )
                }

                Section {
                    TextField(
                        settings.language == .spanish ? "Categoría personalizada (opcional)" : "Custom category (optional)",
                        text: $customCategoryName
                    )
                    .accessibilityIdentifier("moneyAccounts.customCategory")

                    if !customCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(customCategories) { item in
                                    Button {
                                        customCategoryName = item.name
                                        kind = item.style
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

                Section {
                    Toggle(
                        settings.language == .spanish ? "Incluir en fondos disponibles" : "Include in available funds",
                        isOn: $includeInAvailableTotal
                    )

                    Text(
                        settings.language == .spanish
                        ? "Desactívalo para cuentas que no quieras sumar al total principal del inicio, como fondos bloqueados o inversiones de largo plazo."
                        : "Turn this off for accounts you do not want to include in the main home total, such as locked funds or long-term investments."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle(
                existingAccount == nil
                ? (settings.language == .spanish ? "Nueva cuenta" : "New account")
                : (settings.language == .spanish ? "Editar cuenta" : "Edit account")
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
                        save()
                    }
                }
            }
            .sheet(isPresented: $showManageCategories) {
                NavigationStack {
                    CustomCategoriesSettingsView(mode: .moneyAccount)
                        .environmentObject(auth)
                        .environmentObject(settings)
                }
            }
            .alert(
                settings.language == .spanish ? "Datos inválidos" : "Invalid data",
                isPresented: $showValidationAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
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
    }

    private func reloadCustomCategories() {
        customCategories = TransactionCustomizationStore.shared.loadMoneyAccountCustomCategories(user: auth.currentUser)
    }

    private func saveReusableCustomCategory() {
        let trimmed = FormValidator.trim(customCategoryName)
        guard !trimmed.isEmpty else { return }

        var items = TransactionCustomizationStore.shared.loadMoneyAccountCustomCategories(user: auth.currentUser)

        if let index = items.firstIndex(where: { $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
            items[index] = CustomMoneyAccountCategory(id: items[index].id, name: trimmed, style: kind)
        } else {
            items.append(CustomMoneyAccountCategory(name: trimmed, style: kind))
        }

        TransactionCustomizationStore.shared.saveMoneyAccountCustomCategories(items, user: auth.currentUser)
        reloadCustomCategories()
    }

    private func save() {
        let trimmedName = FormValidator.trim(name)

        guard !trimmedName.isEmpty else {
            validationMessage = settings.language == .spanish
            ? "Escribe un nombre para la cuenta."
            : "Enter a name for the account."
            showValidationAlert = true
            return
        }

        guard let balance = FormValidator.normalizedSignedAmount(from: amount) else {
            validationMessage = settings.language == .spanish
            ? "Ingresa un saldo válido."
            : "Enter a valid balance."
            showValidationAlert = true
            return
        }

        let savedAccount = MoneyAccount(
            id: existingAccount?.id ?? UUID(),
            name: trimmedName,
            balance: balance,
            kind: kind,
            customCategoryName: customCategoryName,
            includeInAvailableTotal: includeInAvailableTotal
        )

        onSave(savedAccount)
        dismiss()
    }

    private static func makeAmountText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
    }
}

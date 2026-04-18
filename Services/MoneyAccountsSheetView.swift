import SwiftUI

struct MoneyAccountsSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var auth: AuthManager

    @State private var draftAccounts: [MoneyAccount]
    private let originalAccounts: [MoneyAccount]
    @State private var draftAdjustments: [AccountBalanceAdjustment]
    private let originalAdjustments: [AccountBalanceAdjustment]
    @State private var pendingAdjustmentAuditEntries: [PendingAdjustmentAuditEntry] = []
    @State private var activeEditor: MoneyAccountEditorRoute?
    @State private var adjustmentTargetAccount: MoneyAccount?
    @State private var showDeletionBlockedAlert = false
    @State private var deletionBlockedTitle = ""
    @State private var deletionBlockedMessage = ""

    let expenses: [Expense]
    let incomes: [Income]
    let transfers: [AccountTransfer]
    let startInCreateMode: Bool
    let onSave: ([MoneyAccount], [AccountBalanceAdjustment]) -> Void

    private let deletionGuard = MoneyAccountDeletionGuard()
    private let adjustmentSync = AccountBalanceAdjustmentSync()

    init(
        accounts: [MoneyAccount],
        balanceAdjustments: [AccountBalanceAdjustment],
        expenses: [Expense],
        incomes: [Income],
        transfers: [AccountTransfer],
        startInCreateMode: Bool = false,
        onSave: @escaping ([MoneyAccount], [AccountBalanceAdjustment]) -> Void
    ) {
        _draftAccounts = State(initialValue: accounts.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        })
        _draftAdjustments = State(initialValue: balanceAdjustments.sorted(by: Self.adjustmentSort))
        self.originalAccounts = accounts
        self.originalAdjustments = balanceAdjustments
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
                        ? "Usa esta sección para registrar efectivo, ahorros, billeteras digitales u otras cuentas con saldo. El saldo solo se define al crear la cuenta. Después, el dinero debería moverse con ingresos, gastos, transferencias o ajustes de saldo para evitar desajustes."
                        : "Use this section to track cash, savings, digital wallets, or other balances. The balance is only defined when creating the account. After that, money should move through income, expenses, transfers, or balance adjustments to avoid inconsistencies."
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

                                        if let openingBalance = account.openingBalance,
                                           let openingDate = account.openingBalanceDate {
                                            Text(
                                                settings.language == .spanish
                                                ? "Base: \(settings.secureCurrency(openingBalance)) · \(Self.accountDateFormatter.string(from: openingDate))"
                                                : "Base: \(settings.secureCurrency(openingBalance)) · \(Self.accountDateFormatter.string(from: openingDate))"
                                            )
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        }

                                        let adjustmentCount = adjustmentCount(for: account.id)
                                        if adjustmentCount > 0 {
                                            Text(
                                                settings.language == .spanish
                                                ? "Ajustes registrados: \(adjustmentCount)"
                                                : "Recorded adjustments: \(adjustmentCount)"
                                            )
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
                                Button {
                                    adjustmentTargetAccount = account
                                } label: {
                                    Label(settings.language == .spanish ? "Ajustar" : "Adjust", systemImage: "slider.horizontal.3")
                                }
                                .tint(.orange)

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
                MoneyAccountFormView(
                    account: route.account,
                    existingAccounts: draftAccounts
                ) { savedAccount in
                    upsert(savedAccount)
                }
                .environmentObject(auth)
                .environmentObject(settings)
            }
            .sheet(item: $adjustmentTargetAccount) { account in
                AccountBalanceAdjustmentSheetView(account: account) { adjustment in
                    applyAdjustment(adjustment)
                }
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

    private func adjustmentCount(for accountId: UUID) -> Int {
        draftAdjustments.filter { $0.moneyAccountId == accountId }.count
    }

    private func upsert(_ account: MoneyAccount) {
        if let index = draftAccounts.firstIndex(where: { $0.id == account.id }) {
            draftAccounts[index] = account
        } else {
            draftAccounts.append(account)
        }

        draftAccounts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func applyAdjustment(_ adjustment: AccountBalanceAdjustment) {
        guard let previousAccount = draftAccounts.first(where: { $0.id == adjustment.moneyAccountId }) else {
            return
        }

        draftAdjustments.append(adjustment)
        draftAdjustments.sort(by: Self.adjustmentSort)
        adjustmentSync.applyNewAdjustment(adjustment, to: &draftAccounts)
        draftAccounts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        guard let updatedAccount = draftAccounts.first(where: { $0.id == adjustment.moneyAccountId }) else {
            return
        }

        pendingAdjustmentAuditEntries.append(
            PendingAdjustmentAuditEntry(
                adjustment: adjustment,
                accountName: previousAccount.name,
                previousBalance: previousAccount.balance,
                newBalance: updatedAccount.balance
            )
        )
    }

    private func deleteAccount(_ account: MoneyAccount) {
        let impact = deletionGuard.impact(
            for: account.id,
            expenses: expenses,
            incomes: incomes,
            transfers: transfers
        )

        let linkedAdjustments = adjustmentCount(for: account.id)

        guard !impact.hasLinkedRecords, linkedAdjustments == 0 else {
            presentDeletionBlockedAlert(for: account, impact: impact, linkedAdjustments: linkedAdjustments)
            return
        }

        draftAccounts.removeAll { $0.id == account.id }
    }

    private func presentDeletionBlockedAlert(
        for account: MoneyAccount,
        impact: MoneyAccountDeletionImpact,
        linkedAdjustments: Int
    ) {
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
            ),
            localizedCount(
                linkedAdjustments,
                singularSpanish: "ajuste de saldo",
                pluralSpanish: "ajustes de saldo",
                singularEnglish: "balance adjustment",
                pluralEnglish: "balance adjustments"
            )
        ]
        .compactMap { $0 }

        let joined = components.joined(separator: ", ")

        deletionBlockedMessage = settings.language == .spanish
        ? "La cuenta \"\(account.name)\" está siendo usada en \(joined). Reasigna o elimina esos registros primero."
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
        let originalById = Dictionary(uniqueKeysWithValues: originalAccounts.map { ($0.id, $0) })
        let draftById = Dictionary(uniqueKeysWithValues: draftAccounts.map { ($0.id, $0) })
        let originalAdjustmentIds = Set(originalAdjustments.map(\.id))

        for account in draftAccounts {
            if let original = originalById[account.id] {
                if accountMetadataChanged(from: original, to: account) {
                    AuditLogStore.shared.logMoneyAccountUpdated(
                        from: original,
                        to: account,
                        user: auth.currentUser
                    )
                }
            } else {
                AuditLogStore.shared.logMoneyAccountCreated(account, user: auth.currentUser)
            }
        }

        for original in originalAccounts where draftById[original.id] == nil {
            AuditLogStore.shared.logMoneyAccountDeleted(original, user: auth.currentUser)
        }

        for pendingAudit in pendingAdjustmentAuditEntries where !originalAdjustmentIds.contains(pendingAudit.adjustment.id) {
            AuditLogStore.shared.logMoneyAccountBalanceAdjusted(
                accountName: pendingAudit.accountName,
                previousBalance: pendingAudit.previousBalance,
                newBalance: pendingAudit.newBalance,
                adjustment: pendingAudit.adjustment,
                user: auth.currentUser
            )
        }

        onSave(draftAccounts, draftAdjustments)
        dismiss()
    }

    private func accountMetadataChanged(from old: MoneyAccount, to new: MoneyAccount) -> Bool {
        old.name != new.name ||
        old.kind != new.kind ||
        old.customCategoryName != new.customCategoryName ||
        old.includeInAvailableTotal != new.includeInAvailableTotal ||
        old.openingBalance != new.openingBalance ||
        old.openingBalanceDate != new.openingBalanceDate
    }

    private static func adjustmentSort(_ lhs: AccountBalanceAdjustment, _ rhs: AccountBalanceAdjustment) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }

        return lhs.createdAt > rhs.createdAt
    }

    private static let accountDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct PendingAdjustmentAuditEntry: Identifiable {
    let id = UUID()
    let adjustment: AccountBalanceAdjustment
    let accountName: String
    let previousBalance: Double
    let newBalance: Double
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
    let existingAccounts: [MoneyAccount]
    let onSave: (MoneyAccount) -> Void

    private var isEditing: Bool {
        existingAccount != nil
    }

    init(
        account: MoneyAccount?,
        existingAccounts: [MoneyAccount],
        onSave: @escaping (MoneyAccount) -> Void
    ) {
        self.existingAccount = account
        self.existingAccounts = existingAccounts
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

                    if isEditing {
                        HStack {
                            Text(settings.language == .spanish ? "Saldo actual" : "Current balance")
                            Spacer()
                            Text(settings.secureCurrency(existingAccount?.balance ?? 0))
                                .foregroundColor(.secondary)
                        }

                        if let openingBalance = existingAccount?.openingBalance,
                           let openingBalanceDate = existingAccount?.openingBalanceDate {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(settings.language == .spanish ? "Foto base de la cuenta" : "Account opening snapshot")
                                    .font(.subheadline.weight(.semibold))

                                Text(
                                    settings.language == .spanish
                                    ? "Saldo inicial guardado: \(settings.secureCurrency(openingBalance))"
                                    : "Saved opening balance: \(settings.secureCurrency(openingBalance))"
                                )
                                .font(.footnote)
                                .foregroundColor(.secondary)

                                Text(
                                    settings.language == .spanish
                                    ? "Fecha base: \(Self.dateFormatter.string(from: openingBalanceDate))"
                                    : "Base date: \(Self.dateFormatter.string(from: openingBalanceDate))"
                                )
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            }
                        }

                        Text(
                            settings.language == .spanish
                            ? "El saldo ya no se edita directamente desde esta pantalla para evitar desajustes. Corrígelo usando un ajuste de saldo desde la lista de cuentas."
                            : "The balance is no longer edited directly from this screen to avoid inconsistencies. Correct it using a balance adjustment from the accounts list."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    } else {
                        MoneyTextField(
                            title: settings.language == .spanish ? "Saldo inicial" : "Opening balance",
                            text: $amount,
                            accessibilityIdentifier: "moneyAccounts.balance"
                        )

                        Text(
                            settings.language == .spanish
                            ? "Este saldo se guardará como la foto base con la que arrancó la cuenta dentro de la app."
                            : "This balance will be saved as the opening snapshot for this account inside the app."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
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
                isEditing
                ? (settings.language == .spanish ? "Editar cuenta" : "Edit account")
                : (settings.language == .spanish ? "Nueva cuenta" : "New account")
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

        let duplicatedName = existingAccounts.contains { account in
            let isSameAccount = account.id == existingAccount?.id
            guard !isSameAccount else { return false }

            return account.name.compare(trimmedName, options: .caseInsensitive) == .orderedSame
        }

        guard !duplicatedName else {
            validationMessage = settings.language == .spanish
            ? "Ya existe una cuenta con ese nombre. Usa un nombre distinto."
            : "An account with that name already exists. Use a different name."
            showValidationAlert = true
            return
        }

        let resolvedBalance: Double
        let resolvedOpeningBalance: Double?
        let resolvedOpeningBalanceDate: Date?

        if isEditing {
            resolvedBalance = existingAccount?.balance ?? 0
            resolvedOpeningBalance = existingAccount?.openingBalance
            resolvedOpeningBalanceDate = existingAccount?.openingBalanceDate
        } else {
            guard let parsedBalance = FormValidator.normalizedNonNegativeAmount(from: amount) else {
                validationMessage = settings.language == .spanish
                ? "Ingresa un saldo inicial válido igual o mayor que cero."
                : "Enter a valid opening balance equal to or greater than zero."
                showValidationAlert = true
                return
            }

            resolvedBalance = parsedBalance
            resolvedOpeningBalance = parsedBalance
            resolvedOpeningBalanceDate = Date()
        }

        let savedAccount = MoneyAccount(
            id: existingAccount?.id ?? UUID(),
            name: trimmedName,
            balance: resolvedBalance,
            kind: kind,
            customCategoryName: customCategoryName,
            includeInAvailableTotal: includeInAvailableTotal,
            openingBalance: resolvedOpeningBalance,
            openingBalanceDate: resolvedOpeningBalanceDate
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

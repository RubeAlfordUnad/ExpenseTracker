import SwiftUI

struct CustomCategoriesSettingsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    let mode: CustomCategoryMode

    @State private var expenseCategories: [CustomExpenseCategory] = []
    @State private var incomeCategories: [CustomIncomeCategory] = []
    @State private var moneyAccountCategories: [CustomMoneyAccountCategory] = []

    @State private var name = ""
    @State private var selectedExpenseStyle: Category = .other
    @State private var selectedIncomeStyle: IncomeCategory = .other
    @State private var selectedMoneyAccountStyle: MoneyAccountKind = .other

    @State private var editingExpenseID: UUID?
    @State private var editingIncomeID: UUID?
    @State private var editingMoneyAccountID: UUID?

    var body: some View {
        Form {
            Section {
                TextField(nameFieldTitle, text: $name)

                switch mode {
                case .expense:
                    Picker(baseStyleTitle, selection: $selectedExpenseStyle) {
                        ForEach(Category.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                                .tag(item)
                        }
                    }

                case .income:
                    Picker(baseStyleTitle, selection: $selectedIncomeStyle) {
                        ForEach(IncomeCategory.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                                .tag(item)
                        }
                    }

                case .moneyAccount:
                    Picker(baseStyleTitle, selection: $selectedMoneyAccountStyle) {
                        ForEach(MoneyAccountKind.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                                .tag(item)
                        }
                    }
                }

                Button(editingTitle) {
                    saveCurrentCategory()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text(settings.language == .spanish ? "Editor" : "Editor")
            }

            switch mode {
            case .expense:
                Section {
                    if expenseCategories.isEmpty {
                        emptyStateRow
                    } else {
                        ForEach(expenseCategories) { item in
                            Button {
                                editingExpenseID = item.id
                                editingIncomeID = nil
                                editingMoneyAccountID = nil
                                name = item.name
                                selectedExpenseStyle = item.style
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.style.icon)
                                        .foregroundColor(item.style.color)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .foregroundColor(.primary)

                                        Text(item.style.displayName(language: settings.language))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteExpenseCategories)
                    }
                } header: {
                    Text(settings.language == .spanish ? "Categorías personalizadas de gastos" : "Custom expense categories")
                }

            case .income:
                Section {
                    if incomeCategories.isEmpty {
                        emptyStateRow
                    } else {
                        ForEach(incomeCategories) { item in
                            Button {
                                editingExpenseID = nil
                                editingIncomeID = item.id
                                editingMoneyAccountID = nil
                                name = item.name
                                selectedIncomeStyle = item.style
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.style.icon)
                                        .foregroundColor(item.style.color)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .foregroundColor(.primary)

                                        Text(item.style.displayName(language: settings.language))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteIncomeCategories)
                    }
                } header: {
                    Text(settings.language == .spanish ? "Categorías personalizadas de ingresos" : "Custom income categories")
                }

            case .moneyAccount:
                Section {
                    if moneyAccountCategories.isEmpty {
                        emptyStateRow
                    } else {
                        ForEach(moneyAccountCategories) { item in
                            Button {
                                editingExpenseID = nil
                                editingIncomeID = nil
                                editingMoneyAccountID = item.id
                                name = item.name
                                selectedMoneyAccountStyle = item.style
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.style.icon)
                                        .foregroundColor(item.style.color)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .foregroundColor(.primary)

                                        Text(item.style.displayName(language: settings.language))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteMoneyAccountCategories)
                    }
                } header: {
                    Text(settings.language == .spanish ? "Categorías personalizadas de cuentas" : "Custom money account categories")
                }
            }
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadData()
        }
    }

    private var screenTitle: String {
        switch mode {
        case .expense:
            return settings.language == .spanish ? "Categorías de gastos" : "Expense categories"
        case .income:
            return settings.language == .spanish ? "Categorías de ingresos" : "Income categories"
        case .moneyAccount:
            return settings.language == .spanish ? "Categorías de cuentas" : "Money account categories"
        }
    }

    private var nameFieldTitle: String {
        settings.language == .spanish ? "Nombre personalizado" : "Custom name"
    }

    private var baseStyleTitle: String {
        settings.language == .spanish ? "Estilo base" : "Base style"
    }

    private var editingTitle: String {
        let isEditing: Bool = {
            switch mode {
            case .expense:
                return editingExpenseID != nil
            case .income:
                return editingIncomeID != nil
            case .moneyAccount:
                return editingMoneyAccountID != nil
            }
        }()

        if settings.language == .spanish {
            return isEditing ? "Guardar cambios" : "Agregar categoría"
        } else {
            return isEditing ? "Save changes" : "Add category"
        }
    }

    private var emptyStateRow: some View {
        Text(
            settings.language == .spanish
            ? "Aún no has creado categorías personalizadas."
            : "You have not created custom categories yet."
        )
        .foregroundColor(.secondary)
    }

    private func reloadData() {
        expenseCategories = TransactionCustomizationStore.shared.loadExpenseCustomCategories(user: auth.currentUser)
        incomeCategories = TransactionCustomizationStore.shared.loadIncomeCustomCategories(user: auth.currentUser)
        moneyAccountCategories = TransactionCustomizationStore.shared.loadMoneyAccountCustomCategories(user: auth.currentUser)
    }

    private func saveCurrentCategory() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .expense:
            var items = expenseCategories

            if let editingExpenseID,
               let index = items.firstIndex(where: { $0.id == editingExpenseID }) {
                items[index] = CustomExpenseCategory(id: editingExpenseID, name: trimmed, style: selectedExpenseStyle)
            } else {
                items.append(CustomExpenseCategory(name: trimmed, style: selectedExpenseStyle))
            }

            TransactionCustomizationStore.shared.saveExpenseCustomCategories(items, user: auth.currentUser)

        case .income:
            var items = incomeCategories

            if let editingIncomeID,
               let index = items.firstIndex(where: { $0.id == editingIncomeID }) {
                items[index] = CustomIncomeCategory(id: editingIncomeID, name: trimmed, style: selectedIncomeStyle)
            } else {
                items.append(CustomIncomeCategory(name: trimmed, style: selectedIncomeStyle))
            }

            TransactionCustomizationStore.shared.saveIncomeCustomCategories(items, user: auth.currentUser)

        case .moneyAccount:
            var items = moneyAccountCategories

            if let editingMoneyAccountID,
               let index = items.firstIndex(where: { $0.id == editingMoneyAccountID }) {
                items[index] = CustomMoneyAccountCategory(id: editingMoneyAccountID, name: trimmed, style: selectedMoneyAccountStyle)
            } else {
                items.append(CustomMoneyAccountCategory(name: trimmed, style: selectedMoneyAccountStyle))
            }

            TransactionCustomizationStore.shared.saveMoneyAccountCustomCategories(items, user: auth.currentUser)
        }

        resetEditor()
        reloadData()
    }

    private func deleteExpenseCategories(at offsets: IndexSet) {
        expenseCategories.remove(atOffsets: offsets)
        TransactionCustomizationStore.shared.saveExpenseCustomCategories(expenseCategories, user: auth.currentUser)
        reloadData()
    }

    private func deleteIncomeCategories(at offsets: IndexSet) {
        incomeCategories.remove(atOffsets: offsets)
        TransactionCustomizationStore.shared.saveIncomeCustomCategories(incomeCategories, user: auth.currentUser)
        reloadData()
    }

    private func deleteMoneyAccountCategories(at offsets: IndexSet) {
        moneyAccountCategories.remove(atOffsets: offsets)
        TransactionCustomizationStore.shared.saveMoneyAccountCustomCategories(moneyAccountCategories, user: auth.currentUser)
        reloadData()
    }

    private func resetEditor() {
        name = ""
        editingExpenseID = nil
        editingIncomeID = nil
        editingMoneyAccountID = nil
        selectedExpenseStyle = .other
        selectedIncomeStyle = .other
        selectedMoneyAccountStyle = .other
    }
}

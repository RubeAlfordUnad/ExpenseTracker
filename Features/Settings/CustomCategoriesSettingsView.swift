import SwiftUI

struct CustomCategoriesSettingsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    let mode: CustomCategoryMode

    @State private var expenseCategories: [CustomExpenseCategory] = []
    @State private var incomeCategories: [CustomIncomeCategory] = []

    @State private var name = ""
    @State private var selectedExpenseStyle: Category = .other
    @State private var selectedIncomeStyle: IncomeCategory = .other

    @State private var editingExpenseID: UUID?
    @State private var editingIncomeID: UUID?

    var body: some View {
        Form {
            Section {
                TextField(nameFieldTitle, text: $name)

                if mode == .expense {
                    Picker(baseStyleTitle, selection: $selectedExpenseStyle) {
                        ForEach(Category.allCases, id: \.self) { item in
                            Text(item.displayName(language: settings.language))
                                .tag(item)
                        }
                    }
                } else {
                    Picker(baseStyleTitle, selection: $selectedIncomeStyle) {
                        ForEach(IncomeCategory.allCases, id: \.self) { item in
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

            if mode == .expense {
                Section {
                    if expenseCategories.isEmpty {
                        emptyStateRow
                    } else {
                        ForEach(expenseCategories) { item in
                            Button {
                                editingExpenseID = item.id
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
                        }
                        .onDelete(perform: deleteExpenseCategories)
                    }
                } header: {
                    Text(settings.language == .spanish ? "Categorías personalizadas de gastos" : "Custom expense categories")
                }
            } else {
                Section {
                    if incomeCategories.isEmpty {
                        emptyStateRow
                    } else {
                        ForEach(incomeCategories) { item in
                            Button {
                                editingIncomeID = item.id
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
                        }
                        .onDelete(perform: deleteIncomeCategories)
                    }
                } header: {
                    Text(settings.language == .spanish ? "Categorías personalizadas de ingresos" : "Custom income categories")
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
        }
    }

    private var nameFieldTitle: String {
        settings.language == .spanish ? "Nombre personalizado" : "Custom name"
    }

    private var baseStyleTitle: String {
        settings.language == .spanish ? "Estilo base" : "Base style"
    }

    private var editingTitle: String {
        let isEditing = mode == .expense ? editingExpenseID != nil : editingIncomeID != nil

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
    }

    private func saveCurrentCategory() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if mode == .expense {
            var items = expenseCategories

            if let editingExpenseID,
               let index = items.firstIndex(where: { $0.id == editingExpenseID }) {
                items[index] = CustomExpenseCategory(id: editingExpenseID, name: trimmed, style: selectedExpenseStyle)
            } else {
                items.append(CustomExpenseCategory(name: trimmed, style: selectedExpenseStyle))
            }

            TransactionCustomizationStore.shared.saveExpenseCustomCategories(items, user: auth.currentUser)
        } else {
            var items = incomeCategories

            if let editingIncomeID,
               let index = items.firstIndex(where: { $0.id == editingIncomeID }) {
                items[index] = CustomIncomeCategory(id: editingIncomeID, name: trimmed, style: selectedIncomeStyle)
            } else {
                items.append(CustomIncomeCategory(name: trimmed, style: selectedIncomeStyle))
            }

            TransactionCustomizationStore.shared.saveIncomeCustomCategories(items, user: auth.currentUser)
        }

        name = ""
        editingExpenseID = nil
        editingIncomeID = nil
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
}

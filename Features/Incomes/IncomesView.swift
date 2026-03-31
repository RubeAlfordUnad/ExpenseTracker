import SwiftUI

struct IncomesView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var incomes: [Income] = []
    @State private var showEditor = false
    @State private var editingIncome: Income?
    @State private var incomePendingDelete: Income?

    private var currentMonthIncomes: [Income] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return incomes.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }
    }

    private var sortedIncomes: [Income] {
        incomes.sorted { $0.date > $1.date }
    }

    private var monthlyTotal: Double {
        currentMonthIncomes.reduce(0) { $0 + $1.amount }
    }

    private var monthlyAverage: Double {
        guard !currentMonthIncomes.isEmpty else { return 0 }
        return monthlyTotal / Double(currentMonthIncomes.count)
    }

    private var groupedByCategory: [IncomeCategory: Double] {
        Dictionary(grouping: currentMonthIncomes, by: { $0.category })
            .mapValues { group in
                group.reduce(0) { $0 + $1.amount }
            }
    }

    private var topCategory: IncomeCategory? {
        groupedByCategory.max { $0.value < $1.value }?.key
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    statsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startCreatingIncome()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: {
                editingIncome = nil
            }) {
                AddIncomeView(existingIncome: editingIncome) { savedIncome in
                    upsertIncome(savedIncome)
                }
                .environmentObject(settings)
            }
            .alert(
                settings.language == .spanish ? "Eliminar ingreso" : "Delete income",
                isPresented: Binding(
                    get: { incomePendingDelete != nil },
                    set: { newValue in
                        if !newValue {
                            incomePendingDelete = nil
                        }
                    }
                )
            ) {
                Button(settings.t("common.cancel"), role: .cancel) {
                    incomePendingDelete = nil
                }

                Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                    if let incomePendingDelete {
                        removeIncome(incomePendingDelete)
                    }
                    self.incomePendingDelete = nil
                }
            } message: {
                Text(
                    settings.language == .spanish
                    ? "Se borrará \"\(incomePendingDelete?.title ?? "")\" de forma permanente."
                    : "\"\(incomePendingDelete?.title ?? "")\" will be permanently removed."
                )
            }
            .onAppear {
                loadIncomes()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        settings.language == .spanish
                        ? "Entradas del mes"
                        : "Money coming in"
                    )
                    .font(.headline)
                    .foregroundColor(.secondary)

                    Text(settings.formatCurrency(monthlyTotal))
                        .font(.system(size: 32, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(
                        settings.language == .spanish
                        ? "Registra salarios, freelance y otros ingresos para medir tu balance real."
                        : "Record salary, freelance and other income to measure your real balance."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(width: 52, height: 52)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    infoPill(
                        icon: "calendar",
                        text: settings.monthYearString(from: Date())
                    )

                    infoPill(
                        icon: "list.bullet",
                        text: settings.language == .spanish
                        ? "\(currentMonthIncomes.count) ingresos"
                        : "\(currentMonthIncomes.count) incomes"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoPill(
                        icon: "calendar",
                        text: settings.monthYearString(from: Date())
                    )

                    infoPill(
                        icon: "list.bullet",
                        text: settings.language == .spanish
                        ? "\(currentMonthIncomes.count) ingresos"
                        : "\(currentMonthIncomes.count) incomes"
                    )
                }
            }
        }
        .padding(20)
        .background(BrandPalette.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(
                    title: settings.language == .spanish ? "Promedio" : "Average",
                    value: settings.formatCurrency(monthlyAverage),
                    accent: .blue
                )

                statCard(
                    title: settings.language == .spanish ? "Registros" : "Entries",
                    value: "\(currentMonthIncomes.count)",
                    accent: .green
                )
            }

            if let topCategory {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(topCategory.color.opacity(0.18))
                            .frame(width: 50, height: 50)

                        Image(systemName: topCategory.icon)
                            .foregroundColor(topCategory.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.language == .spanish ? "Categoría principal" : "Top category")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(topCategory.displayName(language: settings.language))
                            .font(.headline)
                    }

                    Spacer()

                    if let amount = groupedByCategory[topCategory] {
                        Text(settings.formatCurrency(amount))
                            .font(.subheadline.bold())
                    }
                }
                .padding(18)
                .background(BrandPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.language == .spanish ? "Historial de ingresos" : "Income history")
                .font(.headline)

            if sortedIncomes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.language == .spanish ? "Todavía no tienes ingresos" : "You do not have incomes yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(
                        settings.language == .spanish
                        ? "Agrega tu salario, trabajos freelance u otras entradas para ver tu balance mensual real."
                        : "Add salary, freelance work or other money coming in to see your real monthly balance."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedIncomes) { income in
                        incomeRow(income)
                    }
                }
            }
        }
    }

    private func incomeRow(_ income: Income) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(income.category.color.opacity(0.18))
                    .frame(width: 46, height: 46)

                Image(systemName: income.category.icon)
                    .foregroundColor(income.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(income.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(income.category.displayName(language: settings.language))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(settings.shortDateString(from: income.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(settings.formatCurrency(income.amount))
                    .font(.subheadline.bold())
                    .foregroundColor(.green)

                HStack(spacing: 10) {
                    Button {
                        startEditing(income)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        incomePendingDelete = income
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(BrandPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.green)

            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BrandPalette.surface)
        .clipShape(Capsule())
    }

    private func loadIncomes() {
        incomes = DataManager.shared.loadIncomes(user: auth.currentUser)
    }

    private func startCreatingIncome() {
        editingIncome = nil
        showEditor = true
    }

    private func startEditing(_ income: Income) {
        editingIncome = income
        showEditor = true
    }

    private func upsertIncome(_ income: Income) {
        if let index = incomes.firstIndex(where: { $0.id == income.id }) {
            incomes[index] = income
        } else {
            incomes.append(income)
        }

        persistIncomes()
    }

    private func removeIncome(_ income: Income) {
        incomes.removeAll { $0.id == income.id }
        persistIncomes()
    }

    private func persistIncomes() {
        DataManager.shared.saveIncomes(incomes, user: auth.currentUser)
        incomes = DataManager.shared.loadIncomes(user: auth.currentUser)
    }

    private var screenTitle: String {
        settings.language == .spanish ? "Ingresos" : "Incomes"
    }
}

import SwiftUI

struct IncomesView: View {

    @EnvironmentObject private var settings: AppSettings

    @Binding var incomes: [Income]
    let onPersist: () -> Void

    @State private var showEditor = false
    @State private var editingIncome: Income?
    @State private var incomePendingDelete: Income?

    private let calendar = Calendar.current

    private var sortedIncomes: [Income] {
        incomes.sorted { $0.date > $1.date }
    }

    private var currentMonthIncomes: [Income] {
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        return sortedIncomes.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }
    }

    private var totalCurrentMonth: Double {
        currentMonthIncomes.reduce(0) { $0 + $1.amount }
    }

    private var latestIncome: Income? {
        sortedIncomes.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                sectionHeader

                if sortedIncomes.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedIncomes) { income in
                            incomeCard(income)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(settings.language == .spanish ? "Ingresos" : "Income")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingIncome = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("income.add")
            }
        }
        .sheet(isPresented: $showEditor) {
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
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.language == .spanish ? "Flujo positivo" : "Positive cash flow")
                        .font(.caption.bold())
                        .foregroundColor(BrandPalette.primary)

                    Text(settings.language == .spanish ? "Tus ingresos" : "Your income")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(
                        settings.language == .spanish
                        ? "Registra lo que entra para calcular tu balance real del mes."
                        : "Track what comes in to calculate your real monthly balance."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(width: 52, height: 52)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                statPill(
                    icon: "calendar",
                    text: settings.language == .spanish
                    ? "Este mes: \(settings.secureCurrency(totalCurrentMonth))"
                    : "This month: \(settings.secureCurrency(totalCurrentMonth))"
                )

                statPill(
                    icon: latestIncome?.category.icon ?? "plus.circle.fill",
                    text: latestIncome?.title ?? (settings.language == .spanish ? "Sin ingresos" : "No income yet")
                )
            }
        }
        .padding(18)
        .background(BrandPalette.heroGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var sectionHeader: some View {
        HStack {
            Text(settings.language == .spanish ? "Todos los ingresos" : "All income")
                .font(.headline)

            Spacer()

            Text(settings.language == .spanish ? "\(sortedIncomes.count) registros" : "\(sortedIncomes.count) records")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.language == .spanish ? "Aún no tienes ingresos" : "You do not have income yet")
                .font(.headline)

            Text(
                settings.language == .spanish
                ? "Empieza por salario, freelance o cualquier otra entrada de dinero."
                : "Start with salary, freelance work or any other cash inflow."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func incomeCard(_ income: Income) -> some View {
        HStack(spacing: 14) {
            Image(systemName: income.category.icon)
                .font(.headline)
                .foregroundColor(income.category.color)
                .frame(width: 42, height: 42)
                .background(income.category.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(income.title)
                    .font(.headline)

                Text(income.categoryDisplayName(language: settings.language))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let comment = income.normalizedComment {
                    Text(comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(settings.shortDateString(from: income.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)

                    Text("+\(settings.secureCurrency(income.amount))")
                        .font(.headline)
                        .foregroundColor(.green)
                }

                Menu {
                    Button(settings.language == .spanish ? "Editar" : "Edit") {
                        editingIncome = income
                        showEditor = true
                    }

                    Button(settings.language == .spanish ? "Eliminar" : "Delete", role: .destructive) {
                        incomePendingDelete = income
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(BrandPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundColor(BrandPalette.primary)

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandPalette.surface)
        .clipShape(Capsule())
    }

    private func upsertIncome(_ income: Income) {
        if let index = incomes.firstIndex(where: { $0.id == income.id }) {
            incomes[index] = income
        } else {
            incomes.append(income)
        }

        incomes.sort { $0.date > $1.date }
        onPersist()
    }

    private func removeIncome(_ income: Income) {
        incomes.removeAll { $0.id == income.id }
        onPersist()
    }
}

import SwiftUI
import Charts

struct ExpensesChartView: View {

    @EnvironmentObject var settings: AppSettings

    var expenses: [Expense]

    private var categoryTotals: [(Category, Double)] {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })

        return grouped.map { key, value in
            let total = value.reduce(0) { $0 + $1.amount }
            return (key, total)
        }
        .filter { $0.1.isFinite && $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
    }

    private var totalAmount: Double {
        let total = expenses.reduce(0) { $0 + $1.amount }
        return total.isFinite ? total : 0
    }

    private var canRenderChart: Bool {
        totalAmount > 0 && !categoryTotals.isEmpty
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.language == .spanish ? "Distribución del gasto" : "Spending distribution")
                        .font(.headline)

                    Text(settings.language == .spanish ? "Por categoría" : "By category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if canRenderChart {
                ZStack {
                    Chart(categoryTotals, id: \.0) { item in
                        SectorMark(
                            angle: .value("Amount", item.1),
                            innerRadius: .ratio(0.58),
                            angularInset: 2
                        )
                        .foregroundStyle(item.0.color)
                    }
                    .frame(height: 260)

                    VStack(spacing: 4) {
                        Text(settings.language == .spanish ? "Total" : "Total")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(settings.formatCurrency(totalAmount))
                            .font(.title2.bold())
                    }
                }

                VStack(spacing: 10) {
                    ForEach(categoryTotals, id: \.0) { item in
                        HStack {
                            Circle()
                                .fill(item.0.color)
                                .frame(width: 10, height: 10)

                            Text(item.0.displayName(language: settings.language))
                                .font(.subheadline)

                            Spacer()

                            Text(settings.formatCurrency(item.1, decimals: 2))
                                .font(.subheadline.bold())
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text(settings.language == .spanish ? "Sin datos para graficar" : "No data to chart")
                        .font(.subheadline.bold())

                    Text(
                        settings.language == .spanish
                        ? "Agrega gastos válidos para ver la distribución por categoría."
                        : "Add valid expenses to see category distribution."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(22)
        .padding(.horizontal)
    }
}

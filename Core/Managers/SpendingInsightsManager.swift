import Foundation

class SpendingInsightsManager {

    static let shared = SpendingInsightsManager()

    func analyzeSpending(
        expenses: [Expense],
        monthlyBudget: Double,
        currencyCode: String,
        locale: Locale,
        language: AppLanguage
    ) -> InsightResult {

        let calendar = Calendar.current
        let now = Date()

        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
        let lastMonth = calendar.component(.month, from: lastMonthDate)
        let lastYear = calendar.component(.year, from: lastMonthDate)

        let thisMonthExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }

        let lastMonthExpenses = expenses.filter {
            calendar.component(.month, from: $0.date) == lastMonth &&
            calendar.component(.year, from: $0.date) == lastYear
        }

        let thisMonthTotal = thisMonthExpenses.reduce(0) { $0 + $1.amount }
        let lastMonthTotal = lastMonthExpenses.reduce(0) { $0 + $1.amount }

        let difference = thisMonthTotal - lastMonthTotal
        let formattedDifference = difference.asCurrency(
            code: currencyCode,
            locale: locale,
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        )
        let formattedSavings = abs(difference).asCurrency(
            code: currencyCode,
            locale: locale,
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        )

        if thisMonthTotal > monthlyBudget && monthlyBudget > 0 {
            return language == .spanish
            ? InsightResult(
                title: "Cuidado",
                message: "Ya superaste tu presupuesto mensual.",
                type: .warning
            )
            : InsightResult(
                title: "Careful",
                message: "You already exceeded your monthly budget.",
                type: .warning
            )
        }

        if difference > 0 {
            return language == .spanish
            ? InsightResult(
                title: "Estás gastando más",
                message: "Este mes llevas \(formattedDifference) más que el mes pasado.",
                type: .warning
            )
            : InsightResult(
                title: "You are spending more",
                message: "This month you are \(formattedDifference) above last month.",
                type: .warning
            )
        }

        if difference < 0 {
            return language == .spanish
            ? InsightResult(
                title: "Buen trabajo",
                message: "Estás ahorrando \(formattedSavings) comparado con el mes pasado.",
                type: .positive
            )
            : InsightResult(
                title: "Nice work",
                message: "You are saving \(formattedSavings) compared to last month.",
                type: .positive
            )
        }

        return language == .spanish
        ? InsightResult(
            title: "Todo estable",
            message: "Tu gasto es similar al mes pasado.",
            type: .neutral
        )
        : InsightResult(
            title: "All stable",
            message: "Your spending is similar to last month.",
            type: .neutral
        )
    }
}

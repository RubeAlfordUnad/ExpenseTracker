import Foundation
import Testing
@testable import ExpenseTracker

@Suite("Regression - dashboard debt metrics")
struct RegressionDashboardDebtMetricsTests {

    @Test("Dashboard separates cards loans and total owed")
    func dashboard_separates_cards_loans_and_total_owed() {
        let card = Debt(
            cardName: "Visa",
            brand: .visa,
            totalLimit: 2_000_000,
            remainingDebt: 500_000,
            kind: .creditCard,
            status: .active
        )

        let loan = Debt(
            cardName: "Ortodoncia",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 800_000,
            kind: .loan,
            status: .active,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 1
        )

        let metrics = DashboardDebtMetrics(debts: [card, loan])

        #expect(metrics.totalCardDebt == 500_000)
        #expect(metrics.totalLoanDebt == 800_000)
        #expect(metrics.totalOutstandingDebt == 1_300_000)
        #expect(metrics.totalCardLimit == 2_000_000)
        #expect(metrics.totalAvailableCredit == 1_500_000)
        #expect(metrics.creditUtilizationPercentage == 25)
    }

    @Test("Dashboard excludes paid debts from active metrics")
    func dashboard_excludes_paid_debts_from_active_metrics() {
        let paidCard = Debt(
            cardName: "Visa pagada",
            brand: .visa,
            totalLimit: 2_000_000,
            remainingDebt: 0,
            kind: .creditCard,
            status: .paid
        )

        let paidLoan = Debt(
            cardName: "Préstamo pagado",
            brand: .other,
            totalLimit: 900_000,
            remainingDebt: 0,
            kind: .loan,
            status: .paid,
            monthlyPayment: 100_000,
            installmentCount: 9,
            paymentsMade: 9
        )

        let metrics = DashboardDebtMetrics(debts: [paidCard, paidLoan])

        #expect(metrics.activeDebtCount == 0)
        #expect(metrics.totalOutstandingDebt == 0)
        #expect(metrics.totalCardLimit == 0)
        #expect(metrics.creditUtilizationPercentage == 0)
        #expect(metrics.paidDebts.count == 2)
    }

    @Test("Loan debt does not affect credit card utilization")
    func loan_debt_does_not_affect_credit_card_utilization() {
        let card = Debt(
            cardName: "Visa",
            brand: .visa,
            totalLimit: 2_000_000,
            remainingDebt: 500_000,
            kind: .creditCard,
            status: .active
        )

        let loan = Debt(
            cardName: "Libre inversión",
            brand: .other,
            totalLimit: 10_000_000,
            remainingDebt: 9_000_000,
            kind: .loan,
            status: .active,
            monthlyPayment: 500_000,
            installmentCount: 20,
            paymentsMade: 2
        )

        let metrics = DashboardDebtMetrics(debts: [card, loan])

        #expect(metrics.totalOutstandingDebt == 9_500_000)
        #expect(metrics.creditUtilizationPercentage == 25)
    }
}

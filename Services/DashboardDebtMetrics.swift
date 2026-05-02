import Foundation

struct DashboardDebtMetrics {

    let activeCards: [Debt]
    let activeLoans: [Debt]
    let paidDebts: [Debt]

    init(debts: [Debt]) {
        self.activeCards = debts.filter { $0.isActive && $0.isCreditCard }
        self.activeLoans = debts.filter { $0.isActive && $0.isLoan }
        self.paidDebts = debts.filter { $0.isPaid }
    }

    var activeDebtCount: Int {
        activeCards.count + activeLoans.count
    }

    var totalCardDebt: Double {
        activeCards.reduce(0) { $0 + max($1.remainingDebt, 0) }
    }

    var totalLoanDebt: Double {
        activeLoans.reduce(0) { $0 + max($1.remainingDebt, 0) }
    }

    var totalOutstandingDebt: Double {
        totalCardDebt + totalLoanDebt
    }

    var totalCardLimit: Double {
        activeCards.reduce(0) { $0 + max($1.totalLimit, 0) }
    }

    var totalAvailableCredit: Double {
        activeCards.reduce(0) { $0 + max($1.availableCredit, 0) }
    }

    var creditUtilizationRaw: Double {
        guard totalCardLimit > 0 else {
            return 0
        }

        let raw = totalCardDebt / totalCardLimit
        guard raw.isFinite else {
            return 0
        }

        return max(raw, 0)
    }

    var creditUtilization: Double {
        min(max(creditUtilizationRaw, 0), 1)
    }

    var creditUtilizationPercentage: Int {
        Int((creditUtilizationRaw * 100).rounded())
    }

    var highlightedCard: Debt? {
        activeCards
            .filter { $0.remainingDebt > 0 }
            .max { $0.remainingDebt < $1.remainingDebt }
    }

    var highlightedLoan: Debt? {
        activeLoans
            .filter { $0.remainingDebt > 0 }
            .max { $0.remainingDebt < $1.remainingDebt }
    }
}

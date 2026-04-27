import Foundation

enum CardBrand: String, CaseIterable, Codable, Identifiable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case other = "Otra"

    var id: String { rawValue }

    var logoName: String {
        switch self {
        case .visa:
            return "visa_logo"
        case .mastercard:
            return "mastercard_logo"
        case .amex:
            return "amex_logo"
        case .other:
            return "creditcard"
        }
    }

    var systemImageName: String {
        switch self {
        case .visa:
            return "creditcard.fill"
        case .mastercard:
            return "creditcard.and.123"
        case .amex:
            return "creditcard.trianglebadge.exclamationmark"
        case .other:
            return "creditcard"
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.visa, _):
            return "Visa"
        case (.mastercard, .spanish):
            return "Mastercard"
        case (.mastercard, .english):
            return "Mastercard"
        case (.amex, .spanish):
            return "American Express"
        case (.amex, .english):
            return "American Express"
        case (.other, .spanish):
            return "Otra"
        case (.other, .english):
            return "Other"
        }
    }
}

enum DebtKind: String, CaseIterable, Codable, Identifiable {
    case creditCard
    case loan

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.creditCard, .spanish): return "Tarjeta"
        case (.creditCard, .english): return "Card"
        case (.loan, .spanish): return "Préstamo"
        case (.loan, .english): return "Loan"
        }
    }

    var icon: String {
        switch self {
        case .creditCard: return "creditcard.fill"
        case .loan: return "doc.text.fill"
        }
    }
}

enum DebtStatus: String, Codable {
    case active
    case paid

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.active, .spanish): return "Activa"
        case (.active, .english): return "Active"
        case (.paid, .spanish): return "Pagada"
        case (.paid, .english): return "Paid"
        }
    }
}

struct Debt: Identifiable, Codable, Equatable {
    var id = UUID()
    var cardName: String
    var brand: CardBrand
    var totalLimit: Double
    var remainingDebt: Double

    var kind: DebtKind
    var status: DebtStatus

    var monthlyPayment: Double?
    var installmentCount: Int?
    var paymentsMade: Int
    var firstPaymentDate: Date?
    var linkedRecurringPaymentId: UUID?

    var managementFee: Double
    var minimumPaymentRate: Double
    var minimumPaymentFixedAmount: Double?
    var statementClosingDay: Int?
    var minimumPaymentDueDay: Int?

    init(
        id: UUID = UUID(),
        cardName: String,
        brand: CardBrand = .other,
        totalLimit: Double,
        remainingDebt: Double,
        kind: DebtKind = .creditCard,
        status: DebtStatus = .active,
        monthlyPayment: Double? = nil,
        installmentCount: Int? = nil,
        paymentsMade: Int = 0,
        firstPaymentDate: Date? = nil,
        linkedRecurringPaymentId: UUID? = nil,
        managementFee: Double = 0,
        minimumPaymentRate: Double = 0.05,
        minimumPaymentFixedAmount: Double? = nil,
        statementClosingDay: Int? = nil,
        minimumPaymentDueDay: Int? = nil
    ) {
        self.id = id
        self.cardName = cardName
        self.brand = brand
        self.totalLimit = totalLimit
        self.remainingDebt = remainingDebt
        self.kind = kind
        self.status = status
        self.monthlyPayment = monthlyPayment
        self.installmentCount = installmentCount
        self.paymentsMade = paymentsMade
        self.firstPaymentDate = firstPaymentDate
        self.linkedRecurringPaymentId = linkedRecurringPaymentId
        self.managementFee = managementFee
        self.minimumPaymentRate = minimumPaymentRate
        self.minimumPaymentFixedAmount = minimumPaymentFixedAmount
        self.statementClosingDay = statementClosingDay
        self.minimumPaymentDueDay = minimumPaymentDueDay
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cardName
        case brand
        case totalLimit
        case remainingDebt
        case kind
        case status
        case monthlyPayment
        case installmentCount
        case paymentsMade
        case firstPaymentDate
        case linkedRecurringPaymentId
        case managementFee
        case minimumPaymentRate
        case minimumPaymentFixedAmount
        case statementClosingDay
        case minimumPaymentDueDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardName = try container.decode(String.self, forKey: .cardName)
        brand = try container.decodeIfPresent(CardBrand.self, forKey: .brand) ?? .other
        totalLimit = try container.decode(Double.self, forKey: .totalLimit)
        remainingDebt = try container.decode(Double.self, forKey: .remainingDebt)
        kind = try container.decodeIfPresent(DebtKind.self, forKey: .kind) ?? .creditCard
        status = try container.decodeIfPresent(DebtStatus.self, forKey: .status) ?? .active
        monthlyPayment = try container.decodeIfPresent(Double.self, forKey: .monthlyPayment)
        installmentCount = try container.decodeIfPresent(Int.self, forKey: .installmentCount)
        paymentsMade = try container.decodeIfPresent(Int.self, forKey: .paymentsMade) ?? 0
        firstPaymentDate = try container.decodeIfPresent(Date.self, forKey: .firstPaymentDate)
        linkedRecurringPaymentId = try container.decodeIfPresent(UUID.self, forKey: .linkedRecurringPaymentId)
        managementFee = try container.decodeIfPresent(Double.self, forKey: .managementFee) ?? 0
        minimumPaymentRate = try container.decodeIfPresent(Double.self, forKey: .minimumPaymentRate) ?? 0.05
        minimumPaymentFixedAmount = try container.decodeIfPresent(Double.self, forKey: .minimumPaymentFixedAmount)
        statementClosingDay = try container.decodeIfPresent(Int.self, forKey: .statementClosingDay)
        minimumPaymentDueDay = try container.decodeIfPresent(Int.self, forKey: .minimumPaymentDueDay)
    }

    var isCreditCard: Bool { kind == .creditCard }
    var isLoan: Bool { kind == .loan }
    var isPaid: Bool { status == .paid }
    var isActive: Bool { status == .active }

    var availableCredit: Double {
        guard isCreditCard else { return 0 }
        let value = totalLimit - remainingDebt
        guard value.isFinite else { return 0 }
        return max(value, 0)
    }

    var rawUtilization: Double {
        guard totalLimit.isFinite,
              remainingDebt.isFinite,
              totalLimit > 0 else {
            return 0
        }

        let raw = remainingDebt / totalLimit
        guard raw.isFinite else { return 0 }

        return max(raw, 0)
    }

    var utilization: Double {
        min(rawUtilization, 1)
    }

    var utilizationPercentage: Int {
        Int((rawUtilization * 100).rounded())
    }

    var principalAmount: Double {
        max(totalLimit, 0)
    }

    var paidAmount: Double {
        max(principalAmount - remainingDebt, 0)
    }

    var progress: Double {
        guard principalAmount > 0 else { return 0 }
        return min(max(paidAmount / principalAmount, 0), 1)
    }

    var progressPercentage: Int {
        Int((progress * 100).rounded())
    }

    var remainingInstallments: Int? {
        guard let installmentCount else { return nil }
        return max(installmentCount - paymentsMade, 0)
    }

    var isFullyPaid: Bool {
        remainingDebt <= 0.0001 || remainingInstallments == 0
    }

    var estimatedMinimumPayment: Double {
        guard isCreditCard else { return monthlyPayment ?? 0 }
        guard remainingDebt > 0 else { return 0 }

        let percentagePayment = remainingDebt * max(minimumPaymentRate, 0)
        let fixedPayment = minimumPaymentFixedAmount ?? 0
        let basePayment = max(percentagePayment, fixedPayment)
        return min(basePayment, remainingDebt)
    }

    var estimatedMonthlyCardPayment: Double {
        guard isCreditCard else { return monthlyPayment ?? 0 }
        return estimatedMinimumPayment + max(managementFee, 0)
    }

    mutating func applyPayment(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }

        remainingDebt = max(remainingDebt - amount, 0)

        if isLoan {
            let expectedMonthlyPayment = monthlyPayment ?? amount
            if amount + 0.0001 >= expectedMonthlyPayment || remainingDebt <= 0.0001 {
                paymentsMade += 1
            }

            if let installmentCount {
                paymentsMade = min(paymentsMade, installmentCount)
            }
        }

        if isFullyPaid {
            remainingDebt = 0
        }
    }

    mutating func revertPayment(_ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }

        remainingDebt = min(remainingDebt + amount, principalAmount)
        status = .active

        if isLoan, paymentsMade > 0 {
            paymentsMade -= 1
        }
    }

    mutating func markAsPaid() {
        remainingDebt = 0
        status = .paid

        if let installmentCount {
            paymentsMade = installmentCount
        }
    }
}

import Foundation
import UniformTypeIdentifiers

enum DebtsExportFormat: String, CaseIterable, Identifiable {
    case csv
    case json

    var id: String { rawValue }

    var title: String {
        switch self {
        case .csv:
            return "Exportar CSV"
        case .json:
            return "Exportar JSON"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv:
            return .commaSeparatedText
        case .json:
            return .json
        }
    }

    var fileExtension: String {
        rawValue
    }
}

struct DebtsExportPayload {
    let data: Data
    let contentType: UTType
    let fileName: String
}

enum DebtsExportError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "No se pudo generar el archivo de exportación."
    }
}

final class DebtsExportService {

    func makeExport(from debts: [Debt], format: DebtsExportFormat) throws -> DebtsExportPayload {
        let fileName = "wallet_debts_\(timestamp()).\(format.fileExtension)"

        switch format {
        case .csv:
            let data = try makeCSVData(from: debts)

            return DebtsExportPayload(
                data: data,
                contentType: format.contentType,
                fileName: fileName
            )

        case .json:
            let data = try makeJSONData(from: debts)

            return DebtsExportPayload(
                data: data,
                contentType: format.contentType,
                fileName: fileName
            )
        }
    }

    private func makeJSONData(from debts: [Debt]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(debts)
        } catch {
            throw DebtsExportError.encodingFailed
        }
    }

    private func makeCSVData(from debts: [Debt]) throws -> Data {
        var lines: [String] = []
        lines.append(csvHeader())

        for debt in debts {
            lines.append(csvRow(for: debt))
        }

        let csv = lines.joined(separator: "\n")

        guard let data = csv.data(using: String.Encoding.utf8) else {
            throw DebtsExportError.encodingFailed
        }

        return data
    }

    private func csvHeader() -> String {
        let columns: [String] = [
            "name",
            "kind",
            "status",
            "brand",
            "total_amount_or_limit",
            "remaining_debt",
            "paid_amount",
            "available_credit",
            "progress_percentage",
            "utilization_percentage",
            "monthly_payment",
            "installment_count",
            "payments_made",
            "remaining_installments",
            "first_payment_date",
            "linked_recurring_payment_id",
            "management_fee",
            "minimum_payment_rate",
            "minimum_payment_fixed_amount",
            "estimated_minimum_payment",
            "estimated_monthly_card_payment",
            "statement_closing_day",
            "minimum_payment_due_day"
        ]

        return columns.joined(separator: ",")
    }

    private func csvRow(for debt: Debt) -> String {
        let monthlyPaymentText = optionalDecimal(debt.monthlyPayment)
        let installmentCountText = optionalInt(debt.installmentCount)
        let remainingInstallmentsText = optionalInt(debt.remainingInstallments)
        let firstPaymentDateText = optionalDate(debt.firstPaymentDate)
        let linkedRecurringPaymentText = optionalUUID(debt.linkedRecurringPaymentId)
        let minimumPaymentFixedText = optionalDecimal(debt.minimumPaymentFixedAmount)
        let statementClosingDayText = optionalInt(debt.statementClosingDay)
        let minimumPaymentDueDayText = optionalInt(debt.minimumPaymentDueDay)

        let columns: [String] = [
            escape(debt.cardName),
            escape(debt.kind.rawValue),
            escape(debt.status.rawValue),
            escape(debt.brand.rawValue),
            decimal(debt.totalLimit),
            decimal(debt.remainingDebt),
            decimal(debt.paidAmount),
            decimal(debt.availableCredit),
            String(debt.progressPercentage),
            String(debt.utilizationPercentage),
            monthlyPaymentText,
            installmentCountText,
            String(debt.paymentsMade),
            remainingInstallmentsText,
            firstPaymentDateText,
            linkedRecurringPaymentText,
            decimal(debt.managementFee),
            decimal(debt.minimumPaymentRate),
            minimumPaymentFixedText,
            decimal(debt.estimatedMinimumPayment),
            decimal(debt.estimatedMonthlyCardPayment),
            statementClosingDayText,
            minimumPaymentDueDayText
        ]

        return columns.joined(separator: ",")
    }

    private func escape(_ value: String) -> String {
        let shouldEscape = value.contains(",")
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")

        guard shouldEscape else {
            return value
        }

        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedValue)\""
    }

    private func decimal(_ value: Double) -> String {
        guard value.isFinite else {
            return "0.00"
        }

        return String(format: "%.2f", value)
    }

    private func optionalDecimal(_ value: Double?) -> String {
        guard let value else {
            return ""
        }

        return decimal(value)
    }

    private func optionalInt(_ value: Int?) -> String {
        guard let value else {
            return ""
        }

        return String(value)
    }

    private func optionalUUID(_ value: UUID?) -> String {
        guard let value else {
            return ""
        }

        return value.uuidString
    }

    private func optionalDate(_ value: Date?) -> String {
        guard let value else {
            return ""
        }

        return isoDateString(value)
    }

    private func isoDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

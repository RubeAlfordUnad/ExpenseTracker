//
//  DebtsExportService.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 20/03/26.
//

import Foundation
import UniformTypeIdentifiers

enum DebtsExportFormat: String, CaseIterable, Identifiable {
    case csv
    case json

    var id: String { rawValue }

    var title: String {
        switch self {
        case .csv: return "Exportar CSV"
        case .json: return "Exportar JSON"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
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
        let fileName = "wallet_cards_\(timestamp()).\(format.fileExtension)"

        switch format {
        case .csv:
            return DebtsExportPayload(
                data: try makeCSVData(from: debts),
                contentType: format.contentType,
                fileName: fileName
            )
        case .json:
            return DebtsExportPayload(
                data: try makeJSONData(from: debts),
                contentType: format.contentType,
                fileName: fileName
            )
        }
    }

    private func makeJSONData(from debts: [Debt]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(debts)
        } catch {
            throw DebtsExportError.encodingFailed
        }
    }

    private func makeCSVData(from debts: [Debt]) throws -> Data {
        let header = [
            "card_name",
            "brand",
            "total_limit",
            "remaining_debt",
            "available_credit",
            "utilization_percentage"
        ].joined(separator: ",")

        let rows = debts.map { debt in
            [
                escape(debt.cardName),
                escape(debt.brand.rawValue),
                String(debt.totalLimit),
                String(debt.remainingDebt),
                String(debt.availableCredit),
                String(debt.utilizationPercentage)
            ].joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else {
            throw DebtsExportError.encodingFailed
        }

        return data
    }

    private func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

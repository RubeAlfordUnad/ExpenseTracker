import Foundation
import UniformTypeIdentifiers

enum ExpensesTransferFormat: String, CaseIterable, Identifiable {
    case csv
    case json

    var id: String { rawValue }

    var contentType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .json: return .json
        }
    }

    var defaultFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStamp = formatter.string(from: Date())

        switch self {
        case .csv:
            return "expenses_\(dateStamp).csv"
        case .json:
            return "expenses_\(dateStamp).json"
        }
    }
}

struct ExpensesTransferPayload {
    let data: Data
    let contentType: UTType
    let fileName: String
}

struct ExpensesImportResult {
    let expenses: [Expense]
    let importedRows: Int
    let skippedRows: Int
}

enum ExpensesTransferError: LocalizedError {
    case emptyInput
    case unsupportedFormat
    case missingRequiredColumns
    case noValidRows
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "El archivo está vacío."
        case .unsupportedFormat:
            return "Formato no soportado. Usa CSV o JSON."
        case .missingRequiredColumns:
            return "El CSV debe incluir al menos estas columnas: title, amount, date."
        case .noValidRows:
            return "No se encontraron filas válidas para importar."
        case .encodingFailed:
            return "No se pudo generar el archivo."
        case .decodingFailed:
            return "No se pudo leer el archivo."
        }
    }
}

final class ExpensesTransferService {

    func makeExport(from expenses: [Expense], format: ExpensesTransferFormat) throws -> ExpensesTransferPayload {
        switch format {
        case .csv:
            return ExpensesTransferPayload(
                data: try makeCSVData(from: expenses),
                contentType: format.contentType,
                fileName: format.defaultFileName
            )
        case .json:
            return ExpensesTransferPayload(
                data: try makeJSONData(from: expenses),
                contentType: format.contentType,
                fileName: format.defaultFileName
            )
        }
    }

    func importExpenses(from data: Data, contentType: UTType?) throws -> ExpensesImportResult {
        guard !data.isEmpty else {
            throw ExpensesTransferError.emptyInput
        }

        let resolvedFormat = try resolveFormat(from: data, contentType: contentType)

        switch resolvedFormat {
        case .json:
            return try importJSON(from: data)
        case .csv:
            return try importCSV(from: data)
        }
    }

    private func resolveFormat(from data: Data, contentType: UTType?) throws -> ExpensesTransferFormat {
        if let contentType {
            if contentType.conforms(to: .json) {
                return .json
            }

            if contentType.conforms(to: .commaSeparatedText) || contentType.conforms(to: .text) {
                return .csv
            }
        }

        if let text = decodedString(from: data)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let first = text.first {
            if first == "[" || first == "{" {
                return .json
            }

            return .csv
        }

        throw ExpensesTransferError.unsupportedFormat
    }

    private func makeJSONData(from expenses: [Expense]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            return try encoder.encode(expenses.sorted { $0.date > $1.date })
        } catch {
            throw ExpensesTransferError.encodingFailed
        }
    }

    private func makeCSVData(from expenses: [Expense]) throws -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var lines: [String] = [
            "title,amount,date,category"
        ]

        for expense in expenses.sorted(by: { $0.date > $1.date }) {
            let row = [
                escapeCSVCell(expense.title),
                String(format: "%.2f", expense.amount),
                formatter.string(from: expense.date),
                escapeCSVCell(expense.category.rawValue)
            ].joined(separator: ",")

            lines.append(row)
        }

        guard let data = lines.joined(separator: "\n").data(using: .utf8) else {
            throw ExpensesTransferError.encodingFailed
        }

        return data
    }

    private func importJSON(from data: Data) throws -> ExpensesImportResult {
        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601

        if let decoded = try? isoDecoder.decode([Expense].self, from: data), !decoded.isEmpty {
            return ExpensesImportResult(
                expenses: decoded,
                importedRows: decoded.count,
                skippedRows: 0
            )
        }

        let defaultDecoder = JSONDecoder()

        do {
            let decoded = try defaultDecoder.decode([Expense].self, from: data)

            guard !decoded.isEmpty else {
                throw ExpensesTransferError.noValidRows
            }

            return ExpensesImportResult(
                expenses: decoded,
                importedRows: decoded.count,
                skippedRows: 0
            )
        } catch {
            throw ExpensesTransferError.decodingFailed
        }
    }

    private func importCSV(from data: Data) throws -> ExpensesImportResult {
        guard let text = decodedString(from: data)?
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n") else {
            throw ExpensesTransferError.decodingFailed
        }

        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard lines.count >= 2 else {
            throw ExpensesTransferError.noValidRows
        }

        let headers = parseCSVLine(lines[0]).map(normalizeHeader)

        guard let titleIndex = index(in: headers, matchingAny: ["title", "titulo", "título", "name", "concepto"]),
              let amountIndex = index(in: headers, matchingAny: ["amount", "monto", "valor", "importe"]),
              let dateIndex = index(in: headers, matchingAny: ["date", "fecha", "day", "dia", "día"]) else {
            throw ExpensesTransferError.missingRequiredColumns
        }

        let categoryIndex = index(in: headers, matchingAny: ["category", "categoria", "categoría", "type", "tipo"])

        var importedExpenses: [Expense] = []
        var skippedRows = 0

        for line in lines.dropFirst() {
            let cells = parseCSVLine(line)

            let safeTitle = value(at: titleIndex, in: cells)
            let safeAmount = value(at: amountIndex, in: cells)
            let safeDate = value(at: dateIndex, in: cells)
            let safeCategory = categoryIndex.flatMap { value(at: $0, in: cells) } ?? ""

            guard let title = parseTitle(safeTitle),
                  let amount = parseAmount(safeAmount),
                  let date = parseDate(safeDate) else {
                skippedRows += 1
                continue
            }

            let category = parseCategory(safeCategory)

            importedExpenses.append(
                Expense(
                    title: title,
                    amount: amount,
                    date: date,
                    category: category
                )
            )
        }

        guard !importedExpenses.isEmpty else {
            throw ExpensesTransferError.noValidRows
        }

        return ExpensesImportResult(
            expenses: importedExpenses,
            importedRows: importedExpenses.count,
            skippedRows: skippedRows
        )
    }

    private func parseTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseAmount(_ raw: String) -> Double? {
        let filtered = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { "0123456789,.-".contains($0) }

        guard !filtered.isEmpty else { return nil }

        let commaCount = filtered.filter { $0 == "," }.count
        let dotCount = filtered.filter { $0 == "." }.count

        let normalized: String

        if commaCount > 0 && dotCount > 0 {
            let lastComma = filtered.lastIndex(of: ",")!
            let lastDot = filtered.lastIndex(of: ".")!

            if lastComma > lastDot {
                normalized = filtered
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = filtered.replacingOccurrences(of: ",", with: "")
            }
        } else if commaCount > 1 && dotCount == 0 {
            normalized = filtered.replacingOccurrences(of: ",", with: "")
        } else if dotCount > 1 && commaCount == 0 {
            normalized = filtered.replacingOccurrences(of: ".", with: "")
        } else {
            normalized = filtered.replacingOccurrences(of: ",", with: ".")
        }

        guard let value = Double(normalized), value > 0 else {
            return nil
        }

        return value
    }

    private func parseDate(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return nil }

        if let excelSerial = Double(value), excelSerial > 20_000, excelSerial < 80_000 {
            let excelBaseDate = Date(timeIntervalSince1970: -2209161600) // 1899-12-30
            return Calendar.current.date(byAdding: .day, value: Int(excelSerial), to: excelBaseDate)
        }

        let isoFullDate = ISO8601DateFormatter()
        isoFullDate.formatOptions = [.withFullDate]

        if let date = isoFullDate.date(from: value) {
            return date
        }

        let isoDateTime = ISO8601DateFormatter()
        isoDateTime.formatOptions = [.withInternetDateTime]

        if let date = isoDateTime.date(from: value) {
            return date
        }

        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd-MM-yyyy",
            "d-M-yyyy",
            "yyyy-MM-dd HH:mm:ss",
            "dd/MM/yyyy HH:mm:ss"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func parseCategory(_ raw: String) -> Category {
        let value = normalizeHeader(raw)

        if value.contains("food") || value.contains("comida") || value.contains("restaurant") || value.contains("restaurante") || value.contains("almuerzo") || value.contains("mercado") {
            return .food
        }

        if value.contains("transport") || value.contains("transporte") || value.contains("taxi") || value.contains("uber") || value.contains("gasolina") || value.contains("bus") {
            return .transport
        }

        if value.contains("entertainment") || value.contains("entretenimiento") || value.contains("ocio") || value.contains("cine") || value.contains("game") || value.contains("stream") {
            return .entertainment
        }

        if value.contains("bill") || value.contains("factura") || value.contains("servicio") || value.contains("internet") || value.contains("luz") || value.contains("agua") || value.contains("rent") || value.contains("arriendo") {
            return .bills
        }

        return .other
    }

    private func decodedString(from data: Data) -> String? {
        String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .utf16)
        ?? String(data: data, encoding: .unicode)
    }

    private func index(in headers: [String], matchingAny candidates: [String]) -> Int? {
        headers.firstIndex { header in
            candidates.contains(header)
        }
    }

    private func value(at index: Int, in cells: [String]) -> String {
        guard index < cells.count else { return "" }
        return cells[index]
    }

    private func normalizeHeader(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private func escapeCSVCell(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }

        return value
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]

            if character == "\"" {
                let nextIndex = line.index(after: index)

                if insideQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    current.append("\"")
                    index = nextIndex
                } else {
                    insideQuotes.toggle()
                }
            } else if character == ",", !insideQuotes {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }

            index = line.index(after: index)
        }

        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }
}

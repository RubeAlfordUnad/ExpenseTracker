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
    let totalRows: Int
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
    case tooManyRows

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
        case .tooManyRows:
            return "El archivo tiene demasiadas filas para importarse de forma segura."
        }
    }
}

final class ExpensesTransferService {

    private let maximumImportRows = 10_000

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
        let cleanedData = removeUTF8BOMIfNeeded(from: data)

        guard !cleanedData.isEmpty else {
            throw ExpensesTransferError.emptyInput
        }

        let resolvedFormat = try resolveFormat(from: cleanedData, contentType: contentType)

        switch resolvedFormat {
        case .json:
            return try importJSON(from: cleanedData)
        case .csv:
            return try importCSV(from: cleanedData)
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

        if let text = decodedString(from: data)?.trimmingCharacters(in: .whitespacesAndNewlines),
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
                totalRows: decoded.count,
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
                totalRows: decoded.count,
                importedRows: decoded.count,
                skippedRows: 0
            )
        } catch let error as ExpensesTransferError {
            throw error
        } catch {
            throw ExpensesTransferError.decodingFailed
        }
    }

    private func importCSV(from data: Data) throws -> ExpensesImportResult {
        guard let rawText = decodedString(from: data) else {
            throw ExpensesTransferError.decodingFailed
        }

        let text = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw ExpensesTransferError.emptyInput
        }

        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard lines.count >= 2 else {
            throw ExpensesTransferError.noValidRows
        }

        let delimiter = detectDelimiter(in: lines[0])
        let headers = parseCSVLine(lines[0], delimiter: delimiter).map(normalizeHeader)

        guard let titleIndex = index(in: headers, matchingAny: ["title", "titulo", "título", "name", "concepto", "descripcion", "descripción", "description"]),
              let amountIndex = index(in: headers, matchingAny: ["amount", "monto", "valor", "importe", "price", "precio"]),
              let dateIndex = index(in: headers, matchingAny: ["date", "fecha", "day", "dia", "día"]) else {
            throw ExpensesTransferError.missingRequiredColumns
        }

        let categoryIndex = index(in: headers, matchingAny: ["category", "categoria", "categoría", "type", "tipo", "rubro"])
        let dataLines = Array(lines.dropFirst())

        guard dataLines.count <= maximumImportRows else {
            throw ExpensesTransferError.tooManyRows
        }

        var importedExpenses: [Expense] = []
        var skippedRows = 0

        for line in dataLines {
            let cells = parseCSVLine(line, delimiter: delimiter)

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
            totalRows: dataLines.count,
            importedRows: importedExpenses.count,
            skippedRows: skippedRows
        )
    }

    private func parseTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let collapsed = trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(collapsed.prefix(80))
    }

    private func parseAmount(_ raw: String) -> Double? {
        let compact = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")

        guard !compact.isEmpty else { return nil }
        guard !compact.contains("-") else { return nil }

        let filtered = compact.filter { "0123456789,.".contains($0) }
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
        } else if commaCount > 0 {
            normalized = normalizeSingleSeparatorNumber(filtered, separator: ",")
                .replacingOccurrences(of: ",", with: ".")
        } else if dotCount > 0 {
            normalized = normalizeSingleSeparatorNumber(filtered, separator: ".")
        } else {
            normalized = filtered
        }

        guard let value = Double(normalized), value > 0 else {
            return nil
        }

        return value
    }

    private func normalizeSingleSeparatorNumber(_ raw: String, separator: Character) -> String {
        let pieces = raw.split(separator: separator, omittingEmptySubsequences: false)

        guard pieces.count > 1 else { return raw }

        let lastDigits = pieces.last?.count ?? 0

        if pieces.count == 2 {
            if lastDigits == 3 {
                return raw.replacingOccurrences(of: String(separator), with: "")
            }

            return raw
        }

        if lastDigits == 1 || lastDigits == 2 {
            let decimalPart = String(pieces.last ?? "")
            let integerPart = pieces.dropLast().joined()
            return integerPart + String(separator) + decimalPart
        }

        return raw.replacingOccurrences(of: String(separator), with: "")
    }

    private func parseDate(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return nil }

        if let excelSerial = Double(value), excelSerial > 20_000, excelSerial < 80_000 {
            let excelBaseDate = Date(timeIntervalSince1970: -2209161600) // 1899-12-30
            return Calendar.current.date(byAdding: .day, value: Int(excelSerial.rounded(.down)), to: excelBaseDate)
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
            "yyyy.MM.dd",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "dd-MM-yyyy",
            "d-M-yyyy",
            "dd.MM.yyyy",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM-dd-yyyy",
            "M-d-yyyy",
            "yyyy-MM-dd HH:mm:ss",
            "dd/MM/yyyy HH:mm:ss",
            "MM/dd/yyyy HH:mm:ss"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.isLenient = false

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

        if matchesAnyCategoryToken(value, tokens: ["food", "comida", "restaurant", "restaurante", "almuerzo", "mercado", "grocery", "groceries", "supermercado"]) {
            return .food
        }

        if matchesAnyCategoryToken(value, tokens: ["transport", "transporte", "taxi", "uber", "gasolina", "fuel", "bus", "metro"]) {
            return .transport
        }

        if matchesAnyCategoryToken(value, tokens: ["entertainment", "entretenimiento", "ocio", "cine", "game", "gaming", "stream", "streaming"]) {
            return .entertainment
        }

        if matchesAnyCategoryToken(value, tokens: ["bill", "bills", "factura", "facturas", "servicio", "servicios", "internet", "luz", "agua", "utilities"]) {
            return .bills
        }

        if matchesAnyCategoryToken(value, tokens: ["housing", "vivienda", "rent", "arriendo", "lease", "mortgage", "hipoteca"]) {
            return .housing
        }

        if matchesAnyCategoryToken(value, tokens: ["health", "salud", "pharmacy", "farmacia", "medical", "medico", "médico"]) {
            return .health
        }

        if matchesAnyCategoryToken(value, tokens: ["shopping", "compras", "store", "tienda"]) {
            return .shopping
        }

        if matchesAnyCategoryToken(value, tokens: ["education", "educacion", "educación", "course", "curso", "school", "escuela"]) {
            return .education
        }

        if matchesAnyCategoryToken(value, tokens: ["subscription", "subscriptions", "suscripcion", "suscripción", "suscripciones", "netflix", "spotify", "icloud"]) {
            return .subscriptions
        }

        if matchesAnyCategoryToken(value, tokens: ["personalcare", "cuidadopersonal", "beauty", "belleza", "barber", "barberia", "barbería"]) {
            return .personalCare
        }

        if matchesAnyCategoryToken(value, tokens: ["travel", "viaje", "viajes", "hotel", "flight", "vuelo"]) {
            return .travel
        }

        if matchesAnyCategoryToken(value, tokens: ["gift", "gifts", "regalo", "regalos"]) {
            return .gifts
        }

        return .other
    }

    private func matchesAnyCategoryToken(_ value: String, tokens: [String]) -> Bool {
        tokens.contains { value.contains(normalizeHeader($0)) }
    }

    private func removeUTF8BOMIfNeeded(from data: Data) -> Data {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        if data.starts(with: bom) {
            return data.dropFirst(3)
        }
        return data
    }

    private func decodedString(from data: Data) -> String? {
        String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .utf16)
        ?? String(data: data, encoding: .unicode)
    }

    private func detectDelimiter(in headerLine: String) -> Character {
        let commaCount = countOccurrences(of: ",", in: headerLine)
        let semicolonCount = countOccurrences(of: ";", in: headerLine)
        return semicolonCount > commaCount ? ";" : ","
    }

    private func countOccurrences(of delimiter: Character, in line: String) -> Int {
        var count = 0
        var insideQuotes = false

        for character in line {
            if character == "\"" {
                insideQuotes.toggle()
                continue
            }

            if character == delimiter, !insideQuotes {
                count += 1
            }
        }

        return count
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
            .replacingOccurrences(of: ".", with: "")
    }

    private func escapeCSVCell(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }

        return value
    }

    private func parseCSVLine(_ line: String, delimiter: Character) -> [String] {
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
            } else if character == delimiter, !insideQuotes {
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

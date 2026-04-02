import Foundation

enum MoneyInputFormatter {

    static func sanitizeInput(
        _ text: String,
        locale: Locale,
        maximumFractionDigits: Int = 2
    ) -> String {
        let groupingSeparator = locale.groupingSeparator ?? "."
        let decimalSeparator = locale.decimalSeparator ?? ","

        let withoutGrouping = text.replacingOccurrences(of: groupingSeparator, with: "")

        var result = ""
        var hasDecimalSeparator = false
        var fractionDigitsCount = 0

        for character in withoutGrouping {
            if character.isWholeNumber {
                if hasDecimalSeparator {
                    if fractionDigitsCount < maximumFractionDigits {
                        result.append(character)
                        fractionDigitsCount += 1
                    }
                } else {
                    result.append(character)
                }
            } else if maximumFractionDigits > 0,
                      String(character) == decimalSeparator,
                      !hasDecimalSeparator {
                if result.isEmpty {
                    result = "0"
                }
                result.append(".")
                hasDecimalSeparator = true
            }
        }

        return result
    }

    static func formatRawForDisplay(
        _ raw: String,
        locale: Locale,
        maximumFractionDigits: Int = 2
    ) -> String {
        guard !raw.isEmpty else { return "" }

        let groupingSeparator = locale.groupingSeparator ?? "."
        let decimalSeparator = locale.decimalSeparator ?? ","

        let parts = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let integerPart = String(parts.first ?? "")
        let groupedInteger = grouped(integerPart.isEmpty ? "0" : integerPart, separator: groupingSeparator)

        if parts.count == 2 {
            let fractionPart = String(parts[1].prefix(maximumFractionDigits))
            return fractionPart.isEmpty
                ? groupedInteger + decimalSeparator
                : groupedInteger + decimalSeparator + fractionPart
        }

        return groupedInteger
    }

    static func formatForEditing(
        _ text: String,
        locale: Locale,
        maximumFractionDigits: Int = 2
    ) -> String {
        let raw = sanitizeInput(text, locale: locale, maximumFractionDigits: maximumFractionDigits)
        return formatRawForDisplay(raw, locale: locale, maximumFractionDigits: maximumFractionDigits)
    }

    static func normalizedDecimalString(
        from text: String,
        locale: Locale = .current,
        maximumFractionDigits: Int = 2
    ) -> String? {
        let raw = sanitizeInput(text, locale: locale, maximumFractionDigits: maximumFractionDigits)
        return raw.isEmpty ? nil : raw
    }

    private static func grouped(_ digits: String, separator: String) -> String {
        guard !digits.isEmpty else { return "" }

        var result = ""
        let reversedDigits = Array(digits.reversed())

        for index in reversedDigits.indices {
            if index != 0 && index % 3 == 0 {
                result.append(separator)
            }
            result.append(reversedDigits[index])
        }

        return String(result.reversed())
    }
}

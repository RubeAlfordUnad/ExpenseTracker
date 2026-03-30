import Foundation

extension Double {
    func asCurrency(
        code: String,
        locale: Locale,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 0
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

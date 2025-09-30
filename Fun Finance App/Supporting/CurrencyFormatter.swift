import Foundation

enum CurrencyFormatter {
    static let usdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static func string(from decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        return usdFormatter.string(from: number) ?? "$0.00"
    }
}

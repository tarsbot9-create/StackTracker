import Foundation

enum Formatters {
    static let btcFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        f.groupingSeparator = ","
        return f
    }()

    static let satsFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return f
    }()

    static let usdFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static let usdCompactFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()

    static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.positivePrefix = "+"
        return f
    }()

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func formatBTC(_ value: Double) -> String {
        btcFormatter.string(from: NSNumber(value: value)) ?? "0"
    }

    static func formatSats(_ btc: Double) -> String {
        let sats = Int(btc * 100_000_000)
        return satsFormatter.string(from: NSNumber(value: sats)) ?? "0"
    }

    static func formatUSD(_ value: Double) -> String {
        usdFormatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    static func formatUSDCompact(_ value: Double) -> String {
        usdCompactFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    static func formatPercent(_ value: Double) -> String {
        (percentFormatter.string(from: NSNumber(value: value)) ?? "0.00") + "%"
    }

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

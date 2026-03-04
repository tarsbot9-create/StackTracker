import Foundation

// MARK: - Platform Detection

enum CSVPlatform: String, CaseIterable {
    case coinbase = "Coinbase"
    case cashApp = "Cash App"
    case strike = "Strike"
    case swan = "Swan"
    case river = "River"
    case stackTracker = "StackTracker"
    case unknown = "Unknown"
}

// MARK: - Parsed Row

struct ParsedPurchase: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var btcAmount: Double
    var pricePerBTC: Double
    var usdSpent: Double
    var walletName: String
    var notes: String
    var isSelected: Bool = true
    var isDuplicate: Bool = false

    // Composite key for duplicate detection
    var duplicateKey: String {
        let dateStr = ISO8601DateFormatter().string(from: date)
        return "\(dateStr)_\(String(format: "%.8f", btcAmount))_\(String(format: "%.2f", usdSpent))"
    }
}

// MARK: - Import Result

struct CSVImportResult {
    var platform: CSVPlatform
    var purchases: [ParsedPurchase]
    var skippedRows: Int
    var errors: [String]
}

// MARK: - CSV Import Service

final class CSVImportService {

    // MARK: - Public

    static func parseCSV(from url: URL, existingPurchases: [DuplicateInfo] = []) throws -> CSVImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseRows(content)

        guard rows.count > 1 else {
            throw ImportError.emptyFile
        }

        let headers = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let platform = detectPlatform(headers: headers)
        let dataRows = Array(rows.dropFirst())

        var purchases: [ParsedPurchase] = []
        var skipped = 0
        var errors: [String] = []

        // Build existing duplicate keys
        let existingKeys = Set(existingPurchases.map { $0.duplicateKey })

        for (index, row) in dataRows.enumerated() {
            do {
                if let purchase = try parseRow(row, headers: headers, platform: platform, rowIndex: index + 2) {
                    var p = purchase
                    if existingKeys.contains(p.duplicateKey) {
                        p.isDuplicate = true
                        p.isSelected = false
                    }
                    purchases.append(p)
                }
            } catch ImportError.skippedRow(let reason) {
                skipped += 1
                errors.append("Row \(index + 2): \(reason)")
            } catch {
                skipped += 1
                errors.append("Row \(index + 2): \(error.localizedDescription)")
            }
        }

        return CSVImportResult(
            platform: platform,
            purchases: purchases,
            skippedRows: skipped,
            errors: errors
        )
    }

    // MARK: - Platform Detection

    private static func detectPlatform(headers: [String]) -> CSVPlatform {
        let joined = headers.joined(separator: " ")

        // Coinbase: "timestamp", "transaction type", "asset", "quantity purchased", "spot price"
        if joined.contains("transaction type") && joined.contains("asset") && joined.contains("spot price") {
            return .coinbase
        }
        if joined.contains("quantity purchased") || joined.contains("quantity sold") {
            return .coinbase
        }

        // Cash App: "transaction id", "date", "transaction type", "currency", "amount", "asset type", "asset amount"
        if joined.contains("asset type") && joined.contains("asset amount") {
            return .cashApp
        }
        if joined.contains("transaction id") && joined.contains("asset") {
            return .cashApp
        }

        // Strike: "type", "amount", "currency", "btc amount"
        if joined.contains("btc amount") || (joined.contains("type") && joined.contains("amount") && joined.contains("btc")) {
            return .strike
        }

        // Swan: "btc amount", "usd amount" or "btc", "usd"
        if joined.contains("btc amount") && joined.contains("usd amount") {
            return .swan
        }

        // River: "date", "amount", "price"
        if joined.contains("amount") && joined.contains("price") && !joined.contains("asset") {
            return .river
        }

        // StackTracker's own export format
        if joined.contains("btc amount") && joined.contains("price per btc") && joined.contains("wallet") {
            return .stackTracker
        }

        return .unknown
    }

    // MARK: - Row Parsing

    private static func parseRow(_ row: [String], headers: [String], platform: CSVPlatform, rowIndex: Int) throws -> ParsedPurchase? {
        guard row.count >= 2 else {
            throw ImportError.skippedRow("Too few columns")
        }

        switch platform {
        case .coinbase:
            return try parseCoinbaseRow(row, headers: headers)
        case .cashApp:
            return try parseCashAppRow(row, headers: headers)
        case .strike:
            return try parseStrikeRow(row, headers: headers)
        case .swan:
            return try parseSwanRow(row, headers: headers)
        case .river:
            return try parseRiverRow(row, headers: headers)
        case .stackTracker:
            return try parseStackTrackerRow(row, headers: headers)
        case .unknown:
            return try parseGenericRow(row, headers: headers)
        }
    }

    // MARK: - Coinbase

    private static func parseCoinbaseRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        // Only import buys
        let txType = get("transaction type")?.lowercased() ?? ""
        guard txType.contains("buy") || txType.contains("receive") || txType.contains("advance trade buy") else {
            throw ImportError.skippedRow("Not a buy transaction: \(txType)")
        }

        // Only BTC
        let asset = get("asset")?.uppercased() ?? ""
        guard asset == "BTC" || asset == "BITCOIN" else {
            throw ImportError.skippedRow("Not BTC: \(asset)")
        }

        guard let dateStr = get("timestamp") ?? get("date"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No valid date")
        }

        let quantity = parseDouble(get("quantity purchased") ?? get("quantity") ?? "0")
        let spotPrice = parseDouble(get("spot price") ?? get("spot price at transaction") ?? "0")
        let subtotal = parseDouble(get("subtotal") ?? get("total") ?? "0")

        guard quantity > 0 else {
            throw ImportError.skippedRow("No BTC quantity")
        }

        let price = spotPrice > 0 ? spotPrice : (subtotal > 0 && quantity > 0 ? subtotal / quantity : 0)
        let usd = subtotal > 0 ? subtotal : quantity * price

        guard price > 0 else {
            throw ImportError.skippedRow("Could not determine price")
        }

        return ParsedPurchase(
            date: date, btcAmount: quantity, pricePerBTC: price,
            usdSpent: usd, walletName: "Coinbase", notes: "Imported from Coinbase"
        )
    }

    // MARK: - Cash App

    private static func parseCashAppRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        let txType = get("transaction type")?.lowercased() ?? ""
        guard txType.contains("bitcoin buy") || txType.contains("bitcoin purchase") || txType == "buy" else {
            throw ImportError.skippedRow("Not a BTC buy: \(txType)")
        }

        guard let dateStr = get("date"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No valid date")
        }

        let btcAmount = abs(parseDouble(get("asset amount") ?? get("btc amount") ?? "0"))
        let usdAmount = abs(parseDouble(get("amount") ?? get("usd amount") ?? "0"))

        guard btcAmount > 0 else {
            throw ImportError.skippedRow("No BTC amount")
        }

        let price = usdAmount > 0 && btcAmount > 0 ? usdAmount / btcAmount : 0
        guard price > 0 else {
            throw ImportError.skippedRow("Could not determine price")
        }

        return ParsedPurchase(
            date: date, btcAmount: btcAmount, pricePerBTC: price,
            usdSpent: usdAmount, walletName: "Cash App", notes: "Imported from Cash App"
        )
    }

    // MARK: - Strike

    private static func parseStrikeRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        let txType = get("type")?.lowercased() ?? ""
        guard txType.contains("buy") || txType.contains("purchase") || txType.contains("dca") else {
            throw ImportError.skippedRow("Not a buy: \(txType)")
        }

        guard let dateStr = get("date") ?? get("timestamp"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No valid date")
        }

        let btcAmount = abs(parseDouble(get("btc amount") ?? get("btc") ?? "0"))
        let usdAmount = abs(parseDouble(get("amount") ?? get("usd amount") ?? get("usd") ?? "0"))

        guard btcAmount > 0 else {
            throw ImportError.skippedRow("No BTC amount")
        }

        let price = usdAmount / btcAmount

        return ParsedPurchase(
            date: date, btcAmount: btcAmount, pricePerBTC: price,
            usdSpent: usdAmount, walletName: "Strike", notes: "Imported from Strike"
        )
    }

    // MARK: - Swan

    private static func parseSwanRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        guard let dateStr = get("date") ?? get("timestamp"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No valid date")
        }

        let btcAmount = abs(parseDouble(get("btc amount") ?? get("btc") ?? "0"))
        let usdAmount = abs(parseDouble(get("usd amount") ?? get("usd") ?? "0"))

        guard btcAmount > 0 else {
            throw ImportError.skippedRow("No BTC amount")
        }

        let price = usdAmount > 0 ? usdAmount / btcAmount : 0
        guard price > 0 else {
            throw ImportError.skippedRow("Could not determine price")
        }

        return ParsedPurchase(
            date: date, btcAmount: btcAmount, pricePerBTC: price,
            usdSpent: usdAmount, walletName: "Swan", notes: "Imported from Swan"
        )
    }

    // MARK: - River

    private static func parseRiverRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        guard let dateStr = get("date") ?? get("timestamp"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No valid date")
        }

        let btcAmount = abs(parseDouble(get("amount") ?? get("btc") ?? "0"))
        let price = abs(parseDouble(get("price") ?? "0"))

        guard btcAmount > 0 && price > 0 else {
            throw ImportError.skippedRow("Missing amount or price")
        }

        return ParsedPurchase(
            date: date, btcAmount: btcAmount, pricePerBTC: price,
            usdSpent: btcAmount * price, walletName: "River", notes: "Imported from River"
        )
    }

    // MARK: - StackTracker (reimport)

    private static func parseStackTrackerRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        guard let dateStr = get("date"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No valid date")
        }

        let btcAmount = parseDouble(get("btc amount") ?? "0")
        let price = parseDouble(get("price per btc") ?? "0")
        let usd = parseDouble(get("usd spent") ?? "0")
        let wallet = get("wallet") ?? "Default"
        let notes = get("notes") ?? ""

        guard btcAmount > 0 else {
            throw ImportError.skippedRow("No BTC amount")
        }

        return ParsedPurchase(
            date: date, btcAmount: btcAmount, pricePerBTC: price,
            usdSpent: usd, walletName: wallet, notes: notes
        )
    }

    // MARK: - Generic (best effort)

    private static func parseGenericRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        // Try to find date
        guard let dateStr = get("date") ?? get("timestamp") ?? get("time"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No date column found")
        }

        // Try to find BTC amount
        let btcAmount = abs(parseDouble(
            get("btc") ?? get("btc amount") ?? get("quantity") ?? get("amount") ?? get("bitcoin") ?? "0"
        ))

        guard btcAmount > 0 && btcAmount < 100 else { // sanity: < 100 BTC per tx
            throw ImportError.skippedRow("Invalid BTC amount")
        }

        // Try to find price or USD
        let price = abs(parseDouble(get("price") ?? get("price per btc") ?? get("spot price") ?? "0"))
        let usd = abs(parseDouble(get("usd") ?? get("usd spent") ?? get("subtotal") ?? get("total") ?? get("cost") ?? "0"))

        let finalPrice: Double
        let finalUSD: Double

        if price > 0 {
            finalPrice = price
            finalUSD = usd > 0 ? usd : btcAmount * price
        } else if usd > 0 {
            finalPrice = usd / btcAmount
            finalUSD = usd
        } else {
            throw ImportError.skippedRow("No price or USD amount found")
        }

        return ParsedPurchase(
            date: date, btcAmount: btcAmount, pricePerBTC: finalPrice,
            usdSpent: finalUSD, walletName: "Imported", notes: "CSV Import"
        )
    }

    // MARK: - CSV Parsing

    private static func parseRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in content {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if (char == "\n" || char == "\r") && !inQuotes {
                if !currentField.isEmpty || !currentRow.isEmpty {
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                }
            } else {
                currentField.append(char)
            }
        }

        // Last row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }

    // MARK: - Date Parsing

    private static func parseDate(_ string: String) -> Date? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines)

        let formatters: [String] = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd/MM/yyyy",
            "MMM d, yyyy",
            "MMMM d, yyyy",
        ]

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        for format in formatters {
            df.dateFormat = format
            if let date = df.date(from: clean) {
                return date
            }
        }

        // Try ISO8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: clean) { return date }

        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: clean)
    }

    // MARK: - Number Parsing

    private static func parseDouble(_ string: String) -> Double {
        let clean = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean) ?? 0
    }
}

// MARK: - Duplicate Info (from existing purchases)

struct DuplicateInfo {
    let duplicateKey: String

    init(date: Date, btcAmount: Double, usdSpent: Double) {
        let dateStr = ISO8601DateFormatter().string(from: date)
        self.duplicateKey = "\(dateStr)_\(String(format: "%.8f", btcAmount))_\(String(format: "%.2f", usdSpent))"
    }
}

// MARK: - Errors

enum ImportError: LocalizedError {
    case emptyFile
    case skippedRow(String)
    case noValidPurchases

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "The CSV file is empty."
        case .skippedRow(let reason): return reason
        case .noValidPurchases: return "No valid BTC purchases found in this file."
        }
    }
}

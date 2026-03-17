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
    var transactionType: TransactionType = .buy
    var isSelected: Bool = true
    var isDuplicate: Bool = false

    /// Shared ISO8601 formatter for duplicate key generation (avoids creating one per row)
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // Composite key for duplicate detection
    var duplicateKey: String {
        let dateStr = Self.iso8601.string(from: date)
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

    static func parseCSVContent(_ content: String, existingPurchases: [DuplicateInfo] = []) throws -> CSVImportResult {
        guard !content.isEmpty else {
            throw ImportError.emptyFile
        }

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

    static func parseCSV(from url: URL, existingPurchases: [DuplicateInfo] = []) throws -> CSVImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        // Try multiple encodings and coordinate file access
        var content: String?

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            if let data = try? Data(contentsOf: readURL) {
                content = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .ascii)
                    ?? String(data: data, encoding: .isoLatin1)
            }
        }

        if content == nil || content?.isEmpty == true {
            // Fallback: try direct read
            content = try? String(contentsOf: url, encoding: .utf8)
        }

        guard let content = content, !content.isEmpty else {
            throw ImportError.emptyFile
        }

        return try parseCSVContent(content, existingPurchases: existingPurchases)
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

        // Cash App: "date", "transaction id", "transaction type", "currency", "amount", "asset type", "asset price", "asset amount"
        if joined.contains("asset type") && joined.contains("asset amount") && joined.contains("asset price") {
            return .cashApp
        }
        if joined.contains("transaction id") && joined.contains("asset type") {
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

        let txType = get("transaction type")?.lowercased() ?? ""

        // Determine transaction category
        let txCategory: TransactionType
        if txType.contains("buy") || txType.contains("receive") || txType.contains("advance trade buy") {
            txCategory = .buy
        } else if txType.contains("sell") || txType.contains("advance trade sell") {
            txCategory = .sell
        } else if txType.contains("send") {
            txCategory = .withdrawal
        } else {
            throw ImportError.skippedRow("Not a relevant transaction: \(txType)")
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

        let label = txCategory == .buy ? "Buy" : txCategory == .sell ? "Sell" : "Withdrawal"
        return ParsedPurchase(
            date: date, btcAmount: quantity, pricePerBTC: price,
            usdSpent: usd, walletName: "Coinbase", notes: "Coinbase \(label)",
            transactionType: txCategory
        )
    }

    // MARK: - Cash App

    private static func parseCashAppRow(_ row: [String], headers: [String]) throws -> ParsedPurchase? {
        let get = { (name: String) -> String? in
            guard let i = headers.firstIndex(where: { $0.contains(name) }), i < row.count else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        let txType = get("transaction type")?.lowercased() ?? ""
        let status = get("status")?.lowercased() ?? ""

        // Skip canceled/failed transactions
        guard status == "complete" else {
            throw ImportError.skippedRow("Transaction not complete: \(status)")
        }

        // Determine transaction type
        let txCategory: TransactionType
        let txLabel: String

        if txType.contains("bitcoin") && (txType.contains("buy") || txType.contains("recurring buy")) {
            txCategory = .buy
            txLabel = "Buy"
        } else if txType.contains("bitcoin") && txType.contains("sell") {
            txCategory = .sell
            txLabel = "Sell"
        } else if txType.contains("bitcoin") && txType.contains("withdrawal") {
            txCategory = .withdrawal
            txLabel = "Withdrawal"
        } else if txType.contains("bitcoin") && txType.contains("payment") {
            txCategory = .payment
            txLabel = "Payment"
        } else {
            throw ImportError.skippedRow("Not a BTC transaction: \(txType)")
        }

        // Verify asset type is BTC
        let assetType = get("asset type")?.uppercased() ?? ""
        guard assetType == "BTC" || assetType == "BITCOIN" || assetType.isEmpty else {
            throw ImportError.skippedRow("Not BTC: \(assetType)")
        }

        guard let dateStr = get("date"),
              let date = parseDate(dateStr) else {
            throw ImportError.skippedRow("No valid date")
        }

        var btcAmount = abs(parseDouble(get("asset amount") ?? "0"))
        let usdAmount = abs(parseDouble(get("amount") ?? get("net amount") ?? "0"))
        let assetPrice = parseDouble(get("asset price") ?? "0")

        // Fallback: parse BTC amount from Notes field (older Cash App exports)
        // e.g. "purchase of BTC 0.00085556" or "sale of BTC 0.00043260"
        if btcAmount == 0 {
            let notes = get("notes") ?? ""
            if let range = notes.range(of: "BTC ") {
                let after = String(notes[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                btcAmount = abs(parseDouble(after))
            }
        }

        // For withdrawals, BTC amount might be in the Amount column directly
        if btcAmount == 0 && txCategory == .withdrawal {
            btcAmount = abs(parseDouble(get("amount") ?? "0"))
        }

        guard btcAmount > 0 else {
            throw ImportError.skippedRow("No BTC amount")
        }

        // Determine price
        let price: Double
        if assetPrice > 0 {
            price = assetPrice
        } else if usdAmount > 0 && btcAmount > 0 && txCategory != .withdrawal {
            price = usdAmount / btcAmount
        } else if txCategory == .withdrawal {
            price = 0 // Price not relevant for transfers
        } else {
            throw ImportError.skippedRow("Could not determine price")
        }

        let finalUSD = usdAmount > 0 ? usdAmount : btcAmount * price

        return ParsedPurchase(
            date: date, btcAmount: btcAmount, pricePerBTC: price,
            usdSpent: finalUSD, walletName: "Cash App",
            notes: "Cash App \(txLabel)",
            transactionType: txCategory
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

        // Use unicodeScalars to avoid Swift's Character grapheme clustering
        // which merges \r\n into a single Character
        for scalar in content.unicodeScalars {
            if scalar == "\"" {
                inQuotes.toggle()
            } else if scalar == "," && !inQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if (scalar == "\n" || scalar == "\r") && !inQuotes {
                if !currentField.isEmpty || !currentRow.isEmpty {
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                }
            } else {
                currentField.append(Character(scalar))
            }
        }

        // Last row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }

    // MARK: - Date Parsing (cached formatters for performance)

    /// Cached DateFormatters - these are expensive to create, so we reuse them.
    /// Each formatter is created once and stored as a static property.
    private static let cachedDateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss zzz",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd/MM/yyyy",
            "MMM d, yyyy",
            "MMMM d, yyyy",
        ]
        return formats.map { format in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = format
            return df
        }
    }()

    private static let cachedISO8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let cachedISO8601Standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines)

        for formatter in cachedDateFormatters {
            if let date = formatter.date(from: clean) {
                return date
            }
        }

        // Try ISO8601 variants
        if let date = cachedISO8601Fractional.date(from: clean) { return date }
        return cachedISO8601Standard.date(from: clean)
    }

    // MARK: - Number Parsing

    private static func parseDouble(_ string: String) -> Double {
        var clean = string
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle parentheses for negative numbers: ($15.00) -> -15.00
        if clean.hasPrefix("(") && clean.hasSuffix(")") {
            clean = "-" + clean.dropFirst().dropLast()
        }

        return Double(clean) ?? 0
    }

    // MARK: - Manual Column Mapping

    static func parseWithMapping(_ content: String, mapping: ColumnMapping, existingPurchases: [DuplicateInfo] = []) throws -> CSVImportResult {
        guard !content.isEmpty else { throw ImportError.emptyFile }

        let rows = parseRows(content)
        guard rows.count > 1 else { throw ImportError.emptyFile }

        // Headers not needed for manual mapping (columns are specified by index)
        let dataRows = Array(rows.dropFirst())

        var purchases: [ParsedPurchase] = []
        var skipped = 0
        let existingKeys = Set(existingPurchases.map { $0.duplicateKey })

        for (index, row) in dataRows.enumerated() {
            // Get date
            guard let dateCol = mapping.dateColumn, dateCol < row.count,
                  let date = parseDate(row[dateCol]) else {
                skipped += 1
                continue
            }

            // Get BTC amount
            guard let btcCol = mapping.btcAmountColumn, btcCol < row.count else {
                skipped += 1
                continue
            }
            let btcAmount = abs(parseDouble(row[btcCol]))
            guard btcAmount > 0 && btcAmount < 1000 else {
                skipped += 1
                continue
            }

            // Get price and/or USD
            var price = 0.0
            var usd = 0.0

            if let priceCol = mapping.priceColumn, priceCol < row.count {
                price = abs(parseDouble(row[priceCol]))
            }
            if let usdCol = mapping.usdSpentColumn, usdCol < row.count {
                usd = abs(parseDouble(row[usdCol]))
            }

            // Derive missing value
            if price == 0 && usd > 0 {
                price = usd / btcAmount
            } else if usd == 0 && price > 0 {
                usd = btcAmount * price
            }

            guard price > 0 else {
                skipped += 1
                continue
            }

            // Determine transaction type
            var txType: TransactionType = .buy
            if let typeCol = mapping.typeColumn, typeCol < row.count {
                let typeStr = row[typeCol].lowercased().trimmingCharacters(in: .whitespaces)
                if typeStr.contains("sell") || typeStr.contains("sale") {
                    txType = .sell
                } else if typeStr.contains("send") || typeStr.contains("withdraw") || typeStr.contains("transfer") {
                    txType = .withdrawal
                } else if typeStr.contains("payment") || typeStr.contains("spend") || typeStr.contains("spent") {
                    txType = .payment
                }
            }

            var purchase = ParsedPurchase(
                date: date, btcAmount: btcAmount, pricePerBTC: price,
                usdSpent: usd, walletName: "Imported",
                notes: "CSV Import (Row \(index + 2))",
                transactionType: txType
            )

            if existingKeys.contains(purchase.duplicateKey) {
                purchase.isDuplicate = true
                purchase.isSelected = false
            }

            purchases.append(purchase)
        }

        return CSVImportResult(
            platform: .unknown,
            purchases: purchases,
            skippedRows: skipped,
            errors: []
        )
    }

    /// Expose row parsing for the column mapper preview
    static func extractHeadersAndPreview(_ content: String) -> (headers: [String], preview: [[String]])? {
        let rows = parseRows(content)
        guard rows.count > 1 else { return nil }
        let headers = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        let preview = Array(rows.dropFirst().prefix(3).map { $0 })
        return (headers, preview)
    }
}

// MARK: - Column Mapping

struct ColumnMapping {
    var dateColumn: Int?
    var btcAmountColumn: Int?
    var priceColumn: Int?
    var usdSpentColumn: Int?
    var typeColumn: Int?
}

// MARK: - Duplicate Info (from existing purchases)

struct DuplicateInfo {
    let duplicateKey: String

    /// Shared ISO8601 formatter (avoids creating one per existing purchase)
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(date: Date, btcAmount: Double, usdSpent: Double) {
        let dateStr = Self.iso8601.string(from: date)
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

import Foundation

// MARK: - Accounting Method

enum AccountingMethod: String, CaseIterable, Identifiable {
    case fifo = "FIFO"
    case lifo = "LIFO"
    case hifo = "HIFO"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .fifo: return "First In, First Out"
        case .lifo: return "Last In, First Out"
        case .hifo: return "Highest Cost First"
        }
    }
}

// MARK: - Tax Lot

/// Represents a purchase lot with remaining BTC available for matching
struct TaxLot: Identifiable {
    let id: UUID
    let date: Date
    let originalBTC: Double
    var remainingBTC: Double
    let pricePerBTC: Double
    let walletName: String

    var costBasis: Double { remainingBTC * pricePerBTC }
    var originalCostBasis: Double { originalBTC * pricePerBTC }

    init(from purchase: Purchase) {
        self.id = purchase.id
        self.date = purchase.date
        self.originalBTC = purchase.btcAmount
        self.remainingBTC = purchase.btcAmount
        self.pricePerBTC = purchase.pricePerBTC
        self.walletName = purchase.walletName
    }
}

// MARK: - Disposal (Sell or Payment)

struct Disposal: Identifiable {
    let id: UUID
    let date: Date
    let btcAmount: Double
    let proceedsPerBTC: Double
    let type: TransactionType // .sell or .payment
    let walletName: String
    let notes: String

    var totalProceeds: Double { btcAmount * proceedsPerBTC }

    init(from purchase: Purchase) {
        self.id = purchase.id
        self.date = purchase.date
        self.btcAmount = purchase.btcAmount
        self.proceedsPerBTC = purchase.pricePerBTC
        self.type = purchase.transactionType
        self.walletName = purchase.walletName
        self.notes = purchase.notes
    }
}

// MARK: - Lot Match

/// A single match between a disposal and a tax lot
struct LotMatch: Identifiable {
    let id = UUID()
    let lotDate: Date
    let lotPricePerBTC: Double
    let btcAmount: Double
    let costBasis: Double
    let proceeds: Double
    let gain: Double
    let holdingDays: Int
    let isLongTerm: Bool

    var gainPercent: Double {
        costBasis > 0 ? (gain / costBasis) * 100 : 0
    }
}

// MARK: - Disposal Result

/// Full result of matching a disposal against lots
struct DisposalResult: Identifiable {
    let id: UUID
    let disposal: Disposal
    let matches: [LotMatch]

    var totalProceeds: Double { matches.reduce(0) { $0 + $1.proceeds } }
    var totalCostBasis: Double { matches.reduce(0) { $0 + $1.costBasis } }
    var totalGain: Double { matches.reduce(0) { $0 + $1.gain } }

    var shortTermGain: Double {
        matches.filter { !$0.isLongTerm }.reduce(0) { $0 + $1.gain }
    }

    var longTermGain: Double {
        matches.filter { $0.isLongTerm }.reduce(0) { $0 + $1.gain }
    }

    var isLongTerm: Bool {
        // If all matches are long-term
        matches.allSatisfy { $0.isLongTerm }
    }

    var holdingPeriodLabel: String {
        let hasShort = matches.contains { !$0.isLongTerm }
        let hasLong = matches.contains { $0.isLongTerm }
        if hasShort && hasLong { return "Mixed" }
        if hasLong { return "Long-term" }
        return "Short-term"
    }
}

// MARK: - Tax Year Summary

struct TaxYearSummary: Identifiable {
    let year: Int
    let shortTermGain: Double
    let shortTermLoss: Double
    let longTermGain: Double
    let longTermLoss: Double
    let disposalCount: Int

    var id: Int { year }

    var netShortTerm: Double { shortTermGain + shortTermLoss }
    var netLongTerm: Double { longTermGain + longTermLoss }
    var netTotal: Double { netShortTerm + netLongTerm }
    var totalProceeds: Double { 0 } // calculated separately if needed
}

// MARK: - Sell Simulation Result

struct SellSimulationResult {
    let btcToSell: Double
    let pricePerBTC: Double
    let proceeds: Double
    let costBasis: Double
    let totalGain: Double
    let shortTermGain: Double
    let longTermGain: Double
    let matches: [LotMatch]
    let insufficientBTC: Bool // true if user tried to sell more than available
}

// MARK: - Tax Lot Engine

struct TaxLotEngine {

    /// Run full lot matching on all transactions
    static func computeDisposals(
        purchases: [Purchase],
        method: AccountingMethod
    ) -> [DisposalResult] {
        let buys = purchases
            .filter { $0.transactionType == .buy }
            .sorted { $0.date < $1.date }

        let disposals = purchases
            .filter { $0.transactionType == .sell || $0.transactionType == .payment }
            .sorted { $0.date < $1.date }
            .map { Disposal(from: $0) }

        // Create mutable lots
        var lots = buys.map { TaxLot(from: $0) }

        var results: [DisposalResult] = []

        for disposal in disposals {
            let matches = matchLots(
                disposal: disposal,
                lots: &lots,
                method: method
            )

            results.append(DisposalResult(
                id: disposal.id,
                disposal: disposal,
                matches: matches
            ))
        }

        return results
    }

    /// Compute tax year summaries from disposal results
    static func yearSummaries(from disposals: [DisposalResult]) -> [TaxYearSummary] {
        let calendar = Calendar.current
        var byYear: [Int: (stGain: Double, stLoss: Double, ltGain: Double, ltLoss: Double, count: Int)] = [:]

        for result in disposals {
            let year = calendar.component(.year, from: result.disposal.date)
            var entry = byYear[year, default: (0, 0, 0, 0, 0)]

            for match in result.matches {
                if match.isLongTerm {
                    if match.gain >= 0 {
                        entry.ltGain += match.gain
                    } else {
                        entry.ltLoss += match.gain
                    }
                } else {
                    if match.gain >= 0 {
                        entry.stGain += match.gain
                    } else {
                        entry.stLoss += match.gain
                    }
                }
            }
            entry.count += 1
            byYear[year] = entry
        }

        return byYear.map { year, data in
            TaxYearSummary(
                year: year,
                shortTermGain: data.stGain,
                shortTermLoss: data.stLoss,
                longTermGain: data.ltGain,
                longTermLoss: data.ltLoss,
                disposalCount: data.count
            )
        }.sorted { $0.year > $1.year } // newest first
    }

    /// Simulate selling X BTC at a given price without mutating real data
    static func simulateSell(
        btcAmount: Double,
        atPrice: Double,
        purchases: [Purchase],
        method: AccountingMethod
    ) -> SellSimulationResult {
        let buys = purchases
            .filter { $0.transactionType == .buy }
            .sorted { $0.date < $1.date }

        // Subtract already-disposed BTC from lots
        let existingDisposals = purchases
            .filter { $0.transactionType == .sell || $0.transactionType == .payment }
            .sorted { $0.date < $1.date }
            .map { Disposal(from: $0) }

        var lots = buys.map { TaxLot(from: $0) }

        // Replay existing disposals to get current lot state
        for disposal in existingDisposals {
            _ = matchLots(disposal: disposal, lots: &lots, method: method)
        }

        let availableBTC = lots.reduce(0) { $0 + $1.remainingBTC }
        let actualSell = min(btcAmount, availableBTC)
        let insufficient = btcAmount > availableBTC + 0.00000001

        // Create hypothetical disposal
        let hypothetical = Disposal(
            id: UUID(),
            date: Date(),
            btcAmount: actualSell,
            proceedsPerBTC: atPrice,
            type: .sell,
            walletName: "",
            notes: ""
        )

        let matches = matchLots(disposal: hypothetical, lots: &lots, method: method)

        let totalProceeds = matches.reduce(0) { $0 + $1.proceeds }
        let totalCostBasis = matches.reduce(0) { $0 + $1.costBasis }
        let totalGain = matches.reduce(0) { $0 + $1.gain }
        let stGain = matches.filter { !$0.isLongTerm }.reduce(0) { $0 + $1.gain }
        let ltGain = matches.filter { $0.isLongTerm }.reduce(0) { $0 + $1.gain }

        return SellSimulationResult(
            btcToSell: actualSell,
            pricePerBTC: atPrice,
            proceeds: totalProceeds,
            costBasis: totalCostBasis,
            totalGain: totalGain,
            shortTermGain: stGain,
            longTermGain: ltGain,
            matches: matches,
            insufficientBTC: insufficient
        )
    }

    // MARK: - Private: Lot Matching

    /// Match a disposal against available lots, consuming BTC from lots
    @discardableResult
    private static func matchLots(
        disposal: Disposal,
        lots: inout [TaxLot],
        method: AccountingMethod
    ) -> [LotMatch] {
        var remaining = disposal.btcAmount
        var matches: [LotMatch] = []

        while remaining > 0.00000001 {
            // Sort/pick lot based on method
            guard let lotIndex = pickLot(from: lots, method: method) else { break }

            let lot = lots[lotIndex]
            let consumed = min(remaining, lot.remainingBTC)

            let costBasis = consumed * lot.pricePerBTC
            let proceeds = consumed * disposal.proceedsPerBTC
            let gain = proceeds - costBasis
            let holdingDays = Calendar.current.dateComponents(
                [.day], from: lot.date, to: disposal.date
            ).day ?? 0
            let isLongTerm = holdingDays > 365

            matches.append(LotMatch(
                lotDate: lot.date,
                lotPricePerBTC: lot.pricePerBTC,
                btcAmount: consumed,
                costBasis: costBasis,
                proceeds: proceeds,
                gain: gain,
                holdingDays: holdingDays,
                isLongTerm: isLongTerm
            ))

            lots[lotIndex].remainingBTC -= consumed
            remaining -= consumed
        }

        return matches
    }

    /// Pick the next lot index based on accounting method
    private static func pickLot(from lots: [TaxLot], method: AccountingMethod) -> Int? {
        let available = lots.enumerated().filter { $0.element.remainingBTC > 0.00000001 }
        guard !available.isEmpty else { return nil }

        switch method {
        case .fifo:
            // Earliest date first
            return available.min(by: { $0.element.date < $1.element.date })?.offset
        case .lifo:
            // Latest date first
            return available.max(by: { $0.element.date < $1.element.date })?.offset
        case .hifo:
            // Highest cost basis first (minimizes gains)
            return available.max(by: { $0.element.pricePerBTC < $1.element.pricePerBTC })?.offset
        }
    }
}

// Private init for Disposal (used in simulation)
private extension Disposal {
    init(id: UUID, date: Date, btcAmount: Double, proceedsPerBTC: Double, type: TransactionType, walletName: String, notes: String) {
        self.id = id
        self.date = date
        self.btcAmount = btcAmount
        self.proceedsPerBTC = proceedsPerBTC
        self.type = type
        self.walletName = walletName
        self.notes = notes
    }
}

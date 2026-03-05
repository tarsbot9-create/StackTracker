import Foundation
import SwiftData

struct PortfolioSummary {
    let totalBTC: Double          // total stack (exchange + cold storage)
    let totalSats: Int
    let exchangeBTC: Double       // BTC still on exchanges
    let coldStorageBTC: Double    // BTC withdrawn to cold storage
    let totalInvested: Double
    let currentValue: Double
    let totalPL: Double
    let totalPLPercent: Double
    let averageCostBasis: Double
    let purchaseCount: Int
    let sellCount: Int
    let withdrawalCount: Int
    let realizedPL: Double
    let dcaStreak: Int
    let firstPurchaseDate: Date?

    var isProfit: Bool { totalPL >= 0 }
}

struct PortfolioCalculator {
    static func summary(purchases: [Purchase], currentPrice: Double) -> PortfolioSummary {
        guard !purchases.isEmpty else {
            return PortfolioSummary(
                totalBTC: 0, totalSats: 0, exchangeBTC: 0, coldStorageBTC: 0,
                totalInvested: 0, currentValue: 0, totalPL: 0, totalPLPercent: 0,
                averageCostBasis: 0, purchaseCount: 0,
                sellCount: 0, withdrawalCount: 0, realizedPL: 0,
                dcaStreak: 0, firstPurchaseDate: nil
            )
        }

        let buys = purchases.filter { $0.isStackPositive }
        let sells = purchases.filter { $0.isStackNegative }
        let withdrawals = purchases.filter { $0.isTransfer }

        let boughtBTC = buys.reduce(0.0) { $0 + $1.btcAmount }
        let soldBTC = sells.reduce(0.0) { $0 + $1.btcAmount }
        let withdrawnBTC = withdrawals.reduce(0.0) { $0 + $1.btcAmount }

        // Total stack = bought - sold (withdrawals are still yours, just in cold storage)
        let totalStackBTC = max(0, boughtBTC - soldBTC)
        // Exchange stack = total - withdrawn
        let exchangeStackBTC = max(0, totalStackBTC - withdrawnBTC)
        // Cold storage = withdrawn amount
        let coldStorageBTC = withdrawnBTC

        // Total invested = money spent buying - money received selling
        let totalBought = buys.reduce(0.0) { $0 + $1.usdSpent }
        let totalSold = sells.reduce(0.0) { $0 + $1.usdSpent }
        let netInvested = totalBought - totalSold

        // Average cost basis across all buys
        let avgBuyCost = boughtBTC > 0 ? totalBought / boughtBTC : 0

        // Realized P&L from sells
        let realizedPL = sells.reduce(0.0) { total, sell in
            let sellRevenue = sell.btcAmount * sell.pricePerBTC
            let costOfSold = sell.btcAmount * avgBuyCost
            return total + (sellRevenue - costOfSold)
        }

        // Current value of ENTIRE stack (exchange + cold storage)
        let currentValue = totalStackBTC * currentPrice
        let unrealizedPL = currentValue - (totalStackBTC * avgBuyCost)
        let totalPL = unrealizedPL + realizedPL
        let totalPLPercent = netInvested > 0 ? (totalPL / netInvested) * 100 : 0

        let sorted = buys.sorted { $0.date < $1.date }

        return PortfolioSummary(
            totalBTC: totalStackBTC,
            totalSats: Int(totalStackBTC * 100_000_000),
            exchangeBTC: exchangeStackBTC,
            coldStorageBTC: coldStorageBTC,
            totalInvested: netInvested,
            currentValue: currentValue,
            totalPL: totalPL,
            totalPLPercent: totalPLPercent,
            averageCostBasis: avgBuyCost,
            purchaseCount: buys.count,
            sellCount: sells.count,
            withdrawalCount: withdrawals.count,
            realizedPL: realizedPL,
            dcaStreak: calculateStreak(purchases: sorted),
            firstPurchaseDate: sorted.first?.date
        )
    }

    static func calculateStreak(purchases: [Purchase]) -> Int {
        let buys = purchases.filter { $0.transactionType == .buy }
        guard !buys.isEmpty else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        var streak = 0
        var checkDate = now

        // Check consecutive weeks going backwards (buys only)
        while true {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: checkDate)?.start ?? checkDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? checkDate

            let hasBuyThisWeek = buys.contains { purchase in
                purchase.date >= weekStart && purchase.date < weekEnd
            }

            if hasBuyThisWeek {
                streak += 1
                checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) ?? checkDate
            } else if streak == 0 {
                // Current week might not have a buy yet, check previous week
                checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) ?? checkDate
                let prevWeekStart = calendar.dateInterval(of: .weekOfYear, for: checkDate)?.start ?? checkDate
                let prevWeekEnd = calendar.date(byAdding: .day, value: 7, to: prevWeekStart) ?? checkDate
                let hasPrevWeek = buys.contains { $0.date >= prevWeekStart && $0.date < prevWeekEnd }
                if hasPrevWeek {
                    streak += 1
                    checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            } else {
                break
            }
        }

        return streak
    }

    // Data for DCA cost basis line chart
    static func costBasisOverTime(purchases: [Purchase]) -> [(date: Date, costBasis: Double, totalInvested: Double, totalBTC: Double)] {
        let sorted = purchases.filter { $0.transactionType == .buy }.sorted { $0.date < $1.date }
        var runningBTC = 0.0
        var runningUSD = 0.0
        var result: [(date: Date, costBasis: Double, totalInvested: Double, totalBTC: Double)] = []

        for purchase in sorted {
            runningBTC += purchase.btcAmount
            runningUSD += purchase.usdSpent
            let costBasis = runningBTC > 0 ? runningUSD / runningBTC : 0
            result.append((purchase.date, costBasis, runningUSD, runningBTC))
        }

        return result
    }
}

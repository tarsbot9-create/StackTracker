import Foundation
import SwiftData

struct PortfolioSummary {
    let totalBTC: Double
    let totalSats: Int
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
                totalBTC: 0, totalSats: 0, totalInvested: 0,
                currentValue: 0, totalPL: 0, totalPLPercent: 0,
                averageCostBasis: 0, purchaseCount: 0,
                sellCount: 0, withdrawalCount: 0, realizedPL: 0,
                dcaStreak: 0, firstPurchaseDate: nil
            )
        }

        let buys = purchases.filter { $0.isStackPositive }
        let sells = purchases.filter { $0.isStackNegative }
        let withdrawals = purchases.filter { $0.isTransfer }

        // Total BTC on exchanges = buys - sells/payments - withdrawals
        let boughtBTC = buys.reduce(0.0) { $0 + $1.btcAmount }
        let soldBTC = sells.reduce(0.0) { $0 + $1.btcAmount }
        let withdrawnBTC = withdrawals.reduce(0.0) { $0 + $1.btcAmount }

        // Stack = bought - sold - withdrawn (withdrawn is on cold storage, tracked separately)
        let exchangeStackBTC = max(0, boughtBTC - soldBTC - withdrawnBTC)

        // Total invested = money in - money out from sells
        let totalBought = buys.reduce(0.0) { $0 + $1.usdSpent }
        let totalSold = sells.reduce(0.0) { $0 + $1.usdSpent }

        // Net invested (cost basis for remaining stack)
        let netInvested = totalBought - totalSold

        // Realized P&L from sells
        let avgBuyCost = boughtBTC > 0 ? totalBought / boughtBTC : 0
        let realizedPL = sells.reduce(0.0) { total, sell in
            let sellRevenue = sell.btcAmount * sell.pricePerBTC
            let costOfSold = sell.btcAmount * avgBuyCost
            return total + (sellRevenue - costOfSold)
        }

        // Current value of remaining exchange stack
        let currentValue = exchangeStackBTC * currentPrice
        let unrealizedPL = currentValue - (exchangeStackBTC * avgBuyCost)
        let totalPL = unrealizedPL + realizedPL
        let totalPLPercent = netInvested > 0 ? (totalPL / netInvested) * 100 : 0

        let sorted = buys.sorted { $0.date < $1.date }

        return PortfolioSummary(
            totalBTC: exchangeStackBTC,
            totalSats: Int(exchangeStackBTC * 100_000_000),
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
        guard !purchases.isEmpty else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        var streak = 0
        var checkDate = now

        // Check consecutive weeks going backwards
        while true {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: checkDate)?.start ?? checkDate
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? checkDate

            let hasPurchaseThisWeek = purchases.contains { purchase in
                purchase.date >= weekStart && purchase.date < weekEnd
            }

            if hasPurchaseThisWeek {
                streak += 1
                checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) ?? checkDate
            } else if streak == 0 {
                // Current week might not have a purchase yet, skip it
                checkDate = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) ?? checkDate
                let prevWeekStart = calendar.dateInterval(of: .weekOfYear, for: checkDate)?.start ?? checkDate
                let prevWeekEnd = calendar.date(byAdding: .day, value: 7, to: prevWeekStart) ?? checkDate
                let hasPrevWeek = purchases.contains { $0.date >= prevWeekStart && $0.date < prevWeekEnd }
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
        let sorted = purchases.sorted { $0.date < $1.date }
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

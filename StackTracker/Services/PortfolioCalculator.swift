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
                averageCostBasis: 0, purchaseCount: 0, dcaStreak: 0,
                firstPurchaseDate: nil
            )
        }

        let totalBTC = purchases.reduce(0) { $0 + $1.btcAmount }
        let totalInvested = purchases.reduce(0) { $0 + $1.usdSpent }
        let currentValue = totalBTC * currentPrice
        let totalPL = currentValue - totalInvested
        let totalPLPercent = totalInvested > 0 ? (totalPL / totalInvested) * 100 : 0
        let averageCostBasis = totalBTC > 0 ? totalInvested / totalBTC : 0
        let sorted = purchases.sorted { $0.date < $1.date }

        return PortfolioSummary(
            totalBTC: totalBTC,
            totalSats: Int(totalBTC * 100_000_000),
            totalInvested: totalInvested,
            currentValue: currentValue,
            totalPL: totalPL,
            totalPLPercent: totalPLPercent,
            averageCostBasis: averageCostBasis,
            purchaseCount: purchases.count,
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

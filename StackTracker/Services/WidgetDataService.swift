import Foundation

/// Writes portfolio summary data to shared UserDefaults for the widget extension to read.
/// The main app calls `update()` whenever portfolio data changes.
///
/// Setup: Both the app and widget must belong to the same App Group.
/// In Xcode: Target > Signing & Capabilities > + App Groups > "group.com.stacktracker.shared"
struct WidgetDataService {
    static let appGroupID = "group.com.stacktracker.shared"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Keys
    private enum Keys {
        static let totalBTC = "widget_totalBTC"
        static let totalSats = "widget_totalSats"
        static let currentPrice = "widget_currentPrice"
        static let change24h = "widget_change24h"
        static let currentValue = "widget_currentValue"
        static let totalInvested = "widget_totalInvested"
        static let totalPL = "widget_totalPL"
        static let totalPLPercent = "widget_totalPLPercent"
        static let averageCostBasis = "widget_averageCostBasis"
        static let purchaseCount = "widget_purchaseCount"
        static let dcaStreak = "widget_dcaStreak"
        static let lastUpdated = "widget_lastUpdated"
    }

    // MARK: - Write (called from main app)

    static func update(summary: PortfolioSummary, price: Double, change24h: Double) {
        guard let defaults = sharedDefaults else { return }

        defaults.set(summary.totalBTC, forKey: Keys.totalBTC)
        defaults.set(summary.totalSats, forKey: Keys.totalSats)
        defaults.set(price, forKey: Keys.currentPrice)
        defaults.set(change24h, forKey: Keys.change24h)
        defaults.set(summary.currentValue, forKey: Keys.currentValue)
        defaults.set(summary.totalInvested, forKey: Keys.totalInvested)
        defaults.set(summary.totalPL, forKey: Keys.totalPL)
        defaults.set(summary.totalPLPercent, forKey: Keys.totalPLPercent)
        defaults.set(summary.averageCostBasis, forKey: Keys.averageCostBasis)
        defaults.set(summary.purchaseCount, forKey: Keys.purchaseCount)
        defaults.set(summary.dcaStreak, forKey: Keys.dcaStreak)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
    }

    // MARK: - Read (called from widget)

    static func read() -> WidgetData {
        guard let defaults = sharedDefaults else { return .empty }

        return WidgetData(
            totalBTC: defaults.double(forKey: Keys.totalBTC),
            totalSats: defaults.integer(forKey: Keys.totalSats),
            currentPrice: defaults.double(forKey: Keys.currentPrice),
            change24h: defaults.double(forKey: Keys.change24h),
            currentValue: defaults.double(forKey: Keys.currentValue),
            totalInvested: defaults.double(forKey: Keys.totalInvested),
            totalPL: defaults.double(forKey: Keys.totalPL),
            totalPLPercent: defaults.double(forKey: Keys.totalPLPercent),
            averageCostBasis: defaults.double(forKey: Keys.averageCostBasis),
            purchaseCount: defaults.integer(forKey: Keys.purchaseCount),
            dcaStreak: defaults.integer(forKey: Keys.dcaStreak),
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: Keys.lastUpdated))
        )
    }
}

// MARK: - Widget Data Model

struct WidgetData {
    let totalBTC: Double
    let totalSats: Int
    let currentPrice: Double
    let change24h: Double
    let currentValue: Double
    let totalInvested: Double
    let totalPL: Double
    let totalPLPercent: Double
    let averageCostBasis: Double
    let purchaseCount: Int
    let dcaStreak: Int
    let lastUpdated: Date

    var isProfit: Bool { totalPL >= 0 }
    var hasData: Bool { purchaseCount > 0 }

    static let empty = WidgetData(
        totalBTC: 0, totalSats: 0, currentPrice: 0, change24h: 0,
        currentValue: 0, totalInvested: 0, totalPL: 0, totalPLPercent: 0,
        averageCostBasis: 0, purchaseCount: 0, dcaStreak: 0,
        lastUpdated: .distantPast
    )

    /// Preview data for widget gallery
    static let preview = WidgetData(
        totalBTC: 0.04817500,
        totalSats: 4_817_500,
        currentPrice: 69_400,
        change24h: 2.34,
        currentValue: 3_343.35,
        totalInvested: 2_850.00,
        totalPL: 493.35,
        totalPLPercent: 17.31,
        averageCostBasis: 59_150,
        purchaseCount: 87,
        dcaStreak: 12,
        lastUpdated: Date()
    )
}

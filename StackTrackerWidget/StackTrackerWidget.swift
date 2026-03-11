import WidgetKit
import SwiftUI

// MARK: - Shared Data Reader

struct WidgetPortfolioData {
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

    static var cached: WidgetPortfolioData {
        let defaults = UserDefaults(suiteName: "group.com.stacktracker.shared") ?? .standard
        return WidgetPortfolioData(
            totalBTC: defaults.double(forKey: "widget_totalBTC"),
            totalSats: defaults.integer(forKey: "widget_totalSats"),
            currentPrice: defaults.double(forKey: "widget_currentPrice"),
            change24h: defaults.double(forKey: "widget_change24h"),
            currentValue: defaults.double(forKey: "widget_currentValue"),
            totalInvested: defaults.double(forKey: "widget_totalInvested"),
            totalPL: defaults.double(forKey: "widget_totalPL"),
            totalPLPercent: defaults.double(forKey: "widget_totalPLPercent"),
            averageCostBasis: defaults.double(forKey: "widget_averageCostBasis"),
            purchaseCount: defaults.integer(forKey: "widget_purchaseCount"),
            dcaStreak: defaults.integer(forKey: "widget_dcaStreak"),
            lastUpdated: Date(timeIntervalSince1970: defaults.double(forKey: "widget_lastUpdated"))
        )
    }

    static let preview = WidgetPortfolioData(
        totalBTC: 0.04817500,
        totalSats: 4_817_500,
        currentPrice: 85_400,
        change24h: 2.34,
        currentValue: 4_113.35,
        totalInvested: 2_850.00,
        totalPL: 1_263.35,
        totalPLPercent: 44.33,
        averageCostBasis: 59_150,
        purchaseCount: 87,
        dcaStreak: 12,
        lastUpdated: Date()
    )
}

// MARK: - Timeline Entry

struct StackTrackerEntry: TimelineEntry {
    let date: Date
    let data: WidgetPortfolioData
    let liveBTCPrice: Double?
    let liveChange24h: Double?

    var btcPrice: Double { liveBTCPrice ?? data.currentPrice }
    var change24h: Double { liveChange24h ?? data.change24h }
    var currentValue: Double { data.totalBTC * btcPrice }
    var totalPL: Double { currentValue - data.totalInvested }
    var plPercent: Double { data.totalInvested > 0 ? (totalPL / data.totalInvested) * 100 : 0 }

    static var placeholder: StackTrackerEntry {
        StackTrackerEntry(date: .now, data: .preview, liveBTCPrice: nil, liveChange24h: nil)
    }
}

// MARK: - Timeline Provider

struct StackTrackerProvider: TimelineProvider {
    func placeholder(in context: Context) -> StackTrackerEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StackTrackerEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        fetchEntry(completion: completion)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StackTrackerEntry>) -> Void) {
        fetchEntry { entry in
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date)!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchEntry(completion: @escaping (StackTrackerEntry) -> Void) {
        let portfolio = WidgetPortfolioData.cached
        let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true")!

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            var price: Double?
            var change: Double?

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let btc = json["bitcoin"] as? [String: Any] {
                price = btc["usd"] as? Double
                change = btc["usd_24h_change"] as? Double
            }

            // Cache the price for next time
            if let price = price {
                let defaults = UserDefaults(suiteName: "group.com.stacktracker.shared") ?? .standard
                defaults.set(price, forKey: "widget_lastKnownPrice")
                defaults.set(change ?? 0, forKey: "widget_lastKnownChange")
            }

            // Fall back to last known price if fetch failed
            if price == nil {
                let defaults = UserDefaults(suiteName: "group.com.stacktracker.shared") ?? .standard
                let cached = defaults.double(forKey: "widget_lastKnownPrice")
                if cached > 0 {
                    price = cached
                    change = defaults.double(forKey: "widget_lastKnownChange")
                }
            }

            completion(StackTrackerEntry(
                date: .now,
                data: portfolio,
                liveBTCPrice: price,
                liveChange24h: change
            ))
        }
        task.resume()

        // Timeout fallback - if network takes too long, return with cached data
        DispatchQueue.global().asyncAfter(deadline: .now() + 12) {
            task.cancel()
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: StackTrackerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "F7931A"))
                Spacer()
                if entry.btcPrice > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: entry.change24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(formatPercent(entry.change24h))
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                    }
                    .foregroundColor(entry.change24h >= 0 ? Color(hex: "3FB950") : Color(hex: "F85149"))
                }
            }

            if entry.btcPrice > 0 {
                Text(formatUSD(entry.btcPrice))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("--")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }

            Spacer()

            if entry.data.hasData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatBTC(entry.data.totalBTC) + " BTC")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundColor(Color(hex: "F7931A"))

                    if entry.btcPrice > 0 {
                        Text(formatUSD(entry.currentValue))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(Color(hex: "8B949E"))
                    }
                }
            } else {
                Text("Open app to start")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "8B949E"))
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(hex: "0D1117")
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: StackTrackerEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: BTC Price
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color(hex: "F7931A"))
                    Text("Bitcoin")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8B949E"))
                }

                if entry.btcPrice > 0 {
                    Text(formatUSD(entry.btcPrice))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 3) {
                        Image(systemName: entry.change24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(formatPercent(entry.change24h) + " 24h")
                            .font(.caption.bold())
                    }
                    .foregroundColor(entry.change24h >= 0 ? Color(hex: "3FB950") : Color(hex: "F85149"))
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color(hex: "30363D"))
                .frame(width: 1)
                .padding(.vertical, 8)

            // Right: Portfolio
            VStack(alignment: .leading, spacing: 6) {
                Text("My Stack")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8B949E"))

                if entry.data.hasData {
                    Text(formatBTC(entry.data.totalBTC) + " BTC")
                        .font(.system(.headline, design: .monospaced, weight: .bold))
                        .foregroundColor(Color(hex: "F7931A"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if entry.btcPrice > 0 {
                        Text(formatUSD(entry.currentValue))
                            .font(.subheadline)
                            .foregroundColor(.white)

                        HStack(spacing: 3) {
                            Image(systemName: entry.totalPL >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(formatUSD(entry.totalPL))
                                .font(.caption.bold())
                            Text("(" + formatPercent(entry.plPercent) + ")")
                                .font(.caption2)
                        }
                        .foregroundColor(entry.totalPL >= 0 ? Color(hex: "3FB950") : Color(hex: "F85149"))
                    }
                } else {
                    Text("No data yet")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8B949E"))
                    Text("Open app to import")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "8B949E").opacity(0.7))
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(hex: "0D1117")
        }
    }
}

// MARK: - Widget Configuration

struct StackTrackerWidget: Widget {
    let kind: String = "StackTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StackTrackerProvider()) { entry in
            StackTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("StackTracker")
        .description("Live BTC price and your portfolio at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StackTrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StackTrackerEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Formatters

private func formatUSD(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.maximumFractionDigits = value >= 1000 ? 0 : 2
    return f.string(from: NSNumber(value: value)) ?? "$0"
}

private func formatBTC(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 8
    return f.string(from: NSNumber(value: value)) ?? "0"
}

private func formatPercent(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    f.positivePrefix = "+"
    return (f.string(from: NSNumber(value: value)) ?? "0.00") + "%"
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    StackTrackerWidget()
} timeline: {
    StackTrackerEntry.placeholder
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    StackTrackerWidget()
} timeline: {
    StackTrackerEntry.placeholder
}

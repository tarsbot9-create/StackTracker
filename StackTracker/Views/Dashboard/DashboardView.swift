import SwiftUI
import SwiftData
import WidgetKit

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @ObservedObject private var priceService = PriceService.shared

    private var summary: PortfolioSummary {
        PortfolioCalculator.summary(purchases: purchases, currentPrice: priceService.currentPrice)
    }

    @State private var showNetworkError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Network error banner
                    if showNetworkError {
                        NetworkErrorBanner("Couldn't fetch BTC price. Check your connection.") {
                            await fetchPriceData()
                        }
                    }

                    // BTC Price Ticker
                    PriceTickerView(
                        price: priceService.currentPrice,
                        change24h: priceService.change24h
                    )

                    // Price Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("30 Day Price")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 4)

                        BitcoinChartView(data: priceService.chartData, height: 130)
                            .padding(8)
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                    }

                    // Stack Summary
                    if !purchases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Stack")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 4)

                            // Main value card
                            VStack(spacing: 4) {
                                Text(Formatters.formatBTC(summary.totalBTC) + " BTC")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundColor(Theme.bitcoinOrange)

                                Text(Formatters.formatSats(summary.totalBTC) + " sats")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)

                                Text(Formatters.formatUSD(summary.currentValue))
                                    .font(.system(.title2, design: .rounded, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.top, 4)

                                HStack(spacing: 4) {
                                    Image(systemName: summary.isProfit ? "arrow.up.right" : "arrow.down.right")
                                        .font(.caption.bold())
                                    Text(Formatters.formatUSD(abs(summary.totalPL)))
                                    Text("(\(Formatters.formatPercent(summary.totalPLPercent)))")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(summary.isProfit ? Theme.profitGreen : Theme.lossRed)
                                .padding(.top, 2)

                                // Exchange vs Cold Storage breakdown
                                if summary.coldStorageBTC > 0 {
                                    Divider().background(Theme.cardBorder).padding(.vertical, 4)

                                    HStack(spacing: 24) {
                                        VStack(spacing: 2) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "building.columns")
                                                    .font(.caption2)
                                                Text("Exchange")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(Theme.textSecondary)
                                            Text(Formatters.formatBTC(summary.exchangeBTC) + " BTC")
                                                .font(.caption.bold())
                                                .foregroundColor(Theme.textPrimary)
                                        }

                                        VStack(spacing: 2) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "lock.shield")
                                                    .font(.caption2)
                                                Text("Cold Storage")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(Theme.textSecondary)
                                            Text(Formatters.formatBTC(summary.coldStorageBTC) + " BTC")
                                                .font(.caption.bold())
                                                .foregroundColor(Theme.bitcoinOrange)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                        }

                        // Stats Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            StatCard(
                                title: "Avg Cost Basis",
                                value: Formatters.formatUSDCompact(summary.averageCostBasis),
                                icon: "target"
                            )
                            StatCard(
                                title: "Total Invested",
                                value: Formatters.formatUSD(summary.totalInvested),
                                icon: "dollarsign.circle"
                            )
                        }

                        // DCA Streak - full width thin bar
                        HStack {
                            Image(systemName: "flame")
                                .font(.caption)
                                .foregroundColor(Theme.bitcoinOrange)
                            Text("DCA Streak")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(summary.dcaStreak) weeks")
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.bitcoinOrange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.cardBackground)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                    } else {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "bitcoinsign.circle")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.bitcoinOrange.opacity(0.5))

                            Text("Start Tracking Your Stack")
                                .font(.title3.bold())
                                .foregroundColor(Theme.textPrimary)

                            Text("Add your first Bitcoin purchase to see your portfolio stats, DCA performance, and milestone progress.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(16)
            }
            .background(Theme.darkBackground)
            .navigationTitle("StackTracker")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await fetchPriceData()
        }
        .refreshable {
            Haptics.tap()
            await fetchPriceData()
        }
        .onChange(of: purchases.count) { _, _ in
            updateWidgetData()
        }
    }

    private func fetchPriceData() async {
        let priceBefore = priceService.currentPrice
        await priceService.fetchCurrentPrice()
        await priceService.fetchChartData(days: 30)
        // Show error if price is still 0 after fetch
        withAnimation {
            showNetworkError = priceService.currentPrice == 0 && priceBefore == 0
        }
        updateWidgetData()
    }

    /// Push current portfolio data to the widget via shared UserDefaults
    private func updateWidgetData() {
        let currentSummary = summary
        WidgetDataService.update(
            summary: currentSummary,
            price: priceService.currentPrice,
            change24h: priceService.change24h
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "StackTrackerWidget")
    }
}

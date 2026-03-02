import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @StateObject private var priceService = PriceService()

    private var summary: PortfolioSummary {
        PortfolioCalculator.summary(purchases: purchases, currentPrice: priceService.currentPrice)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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

                        BitcoinChartView(data: priceService.chartData, height: 180)
                            .padding(12)
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
                            StatCard(
                                title: "Purchases",
                                value: "\(summary.purchaseCount)",
                                icon: "cart"
                            )
                            StatCard(
                                title: "DCA Streak",
                                value: "\(summary.dcaStreak) weeks",
                                icon: "flame"
                            )
                        }
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
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await priceService.fetchCurrentPrice()
            await priceService.fetchChartData(days: 30)
        }
        .refreshable {
            await priceService.fetchCurrentPrice()
            await priceService.fetchChartData(days: 30)
        }
    }
}

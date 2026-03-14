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
    @State private var showDCACalculator = false

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
                            // Avg Cost Basis with 7d change
                            avgCostBasisCard

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

                        // Next Milestone Card
                        nextMilestoneCard
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDCACalculator = true
                        Haptics.tap()
                    } label: {
                        Image(systemName: "function")
                            .foregroundColor(Theme.bitcoinOrange)
                    }
                }
            }
            .sheet(isPresented: $showDCACalculator) {
                NavigationStack {
                    DCACalculatorView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") {
                                    showDCACalculator = false
                                }
                                .foregroundColor(Theme.bitcoinOrange)
                            }
                        }
                }
            }
        }
        .task {
            await fetchPriceData()

            // Check review prompt conditions
            ReviewPromptService.requestReviewIfAppropriate(transactionCount: purchases.count)

            // Check milestone notifications
            NotificationService.shared.checkMilestoneReached(totalSats: summary.totalSats)

            // Check price alerts
            if priceService.currentPrice > 0 {
                NotificationService.shared.checkPriceAlerts(currentPrice: priceService.currentPrice)
            }
        }
        .refreshable {
            Haptics.tap()
            await fetchPriceData()
        }
        .onChange(of: purchases.count) { _, _ in
            updateWidgetData()
        }
    }

    // MARK: - Next Milestone Card

    /// Named milestones for early stackers (under 1 BTC)
    private static let namedMilestones: [(sats: Int, name: String)] = [
        (100_000, "100K Sats"),
        (500_000, "500K Sats"),
        (1_000_000, "1M Sats"),
        (5_000_000, "5M Sats"),
        (10_000_000, "0.1 BTC"),
        (25_000_000, "0.25 BTC"),
        (50_000_000, "0.5 BTC"),
        (100_000_000, "1 BTC"),
    ]

    /// The ultimate milestone: 21 BTC = one-millionth of total supply
    private static let ultimateMilestoneSats = 2_100_000_000 // 21 BTC

    /// Compute the next milestone dynamically based on current stack
    private func nextMilestone(totalBTC: Double, totalSats: Int) -> (targetSats: Int, name: String)? {
        // Check named milestones first (under 1 BTC)
        if let named = Self.namedMilestones.first(where: { $0.sats > totalSats }) {
            return (named.sats, named.name)
        }

        // Already past 21 BTC - no more milestones
        if totalSats >= Self.ultimateMilestoneSats {
            return nil
        }

        // Dynamic milestones based on stack size (BTC)
        // Find the next "nice number" above current stack
        let increment: Double
        if totalBTC < 10 {
            increment = 0.5   // 1 BTC - 10 BTC: steps of 0.5
        } else {
            increment = 1.0   // 10 BTC - 21 BTC: steps of 1.0
        }

        let nextBTC = (totalBTC / increment).rounded(.up) * increment
        // Make sure we actually moved forward
        let targetBTC = nextBTC <= totalBTC ? nextBTC + increment : nextBTC

        // Cap at 21 BTC
        let cappedBTC = min(targetBTC, 21.0)
        let targetSats = Int(cappedBTC * 100_000_000)

        // Format the name
        let name: String
        if cappedBTC == 21.0 {
            name = "21 BTC"
        } else if cappedBTC == cappedBTC.rounded() {
            name = "\(Int(cappedBTC)) BTC"
        } else {
            name = String(format: "%.1f BTC", cappedBTC)
        }

        return (targetSats, name)
    }

    @ViewBuilder
    private var nextMilestoneCard: some View {
        let totalSats = summary.totalSats
        let totalBTC = summary.totalBTC

        if let milestone = nextMilestone(totalBTC: totalBTC, totalSats: totalSats) {
            let progress = Double(totalSats) / Double(milestone.targetSats)
            let remaining = milestone.targetSats - totalSats

            let isUltimate = milestone.targetSats == Self.ultimateMilestoneSats
            let subtitle = isUltimate ? "One in a Million" : nil

            NavigationLink(destination: MilestonesView()) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "trophy")
                            .font(.caption)
                            .foregroundColor(Theme.bitcoinOrange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Next Milestone: \(milestone.name)")
                                .font(.caption.bold())
                                .foregroundColor(Theme.textPrimary)
                            if let subtitle {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundColor(Theme.bitcoinOrange.opacity(0.7))
                            }
                        }
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(Theme.bitcoinOrange)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.darkBackground)
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.bitcoinOrange)
                                .frame(width: geo.size.width * min(progress, 1.0), height: 5)
                                .animation(.easeOut(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 5)

                    let remainingBTC = Double(remaining) / 100_000_000.0
                    if remainingBTC >= 0.01 {
                        Text("\(Formatters.formatBTC(remainingBTC)) BTC to go")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Text("\(Formatters.satsFormatter.string(from: NSNumber(value: remaining)) ?? "0") sats to go")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(14)
                .background(Theme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else if totalSats >= Self.ultimateMilestoneSats {
            // 21+ BTC - ultimate achievement
            NavigationLink(destination: MilestonesView()) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundColor(Theme.bitcoinOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ONE IN A MILLION")
                            .font(.caption.bold())
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("21 BTC - All milestones complete!")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(14)
                .background(Theme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.bitcoinOrange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Avg Cost Basis Card with 7d Change

    private var avgCostBasisCard: some View {
        let change7d: Double = {
            guard let firstPoint = priceService.chartData.first(where: {
                $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            }), firstPoint.price > 0 else { return 0 }
            return (priceService.currentPrice - firstPoint.price) / firstPoint.price
        }()
        let isUp = change7d >= 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text("Avg Cost Basis")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Text(Formatters.formatUSDCompact(summary.averageCostBasis))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if priceService.currentPrice > 0 && summary.averageCostBasis > 0 {
                HStack(spacing: 4) {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(Formatters.formatPercent(change7d * 100)) 7d")
                        .font(.caption2.bold())
                }
                .foregroundColor(isUp ? Theme.profitGreen : Theme.lossRed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
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

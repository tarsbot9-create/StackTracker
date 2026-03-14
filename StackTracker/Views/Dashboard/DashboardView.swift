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
    @State private var show7dChange = false

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

                                // Cost basis change indicator
                                if priceService.currentPrice > 0 && summary.averageCostBasis > 0 {
                                    costBasisChangeView
                                }

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

    @ViewBuilder
    private var nextMilestoneCard: some View {
        let totalSats = summary.totalSats
        let milestoneTargets = [
            100_000, 500_000, 1_000_000, 5_000_000,
            10_000_000, 25_000_000, 50_000_000, 100_000_000
        ]
        let milestoneNames: [Int: String] = [
            100_000: "100K Sats",
            500_000: "500K Sats",
            1_000_000: "1M Sats",
            5_000_000: "5M Sats",
            10_000_000: "0.1 BTC",
            25_000_000: "0.25 BTC",
            50_000_000: "0.5 BTC",
            100_000_000: "1 BTC"
        ]

        if let nextTarget = milestoneTargets.first(where: { $0 > totalSats }) {
            let progress = Double(totalSats) / Double(nextTarget)
            let remaining = nextTarget - totalSats
            let name = milestoneNames[nextTarget] ?? "\(nextTarget) sats"

            NavigationLink(destination: MilestonesView()) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "trophy")
                            .font(.caption)
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("Next Milestone: \(name)")
                            .font(.caption.bold())
                            .foregroundColor(Theme.textPrimary)
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
                                .frame(width: geo.size.width * progress, height: 5)
                                .animation(.easeOut(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 5)

                    Text("\(Formatters.satsFormatter.string(from: NSNumber(value: remaining)) ?? "0") sats to go")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
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
        } else if totalSats >= 100_000_000 {
            // Whole coiner - show celebration
            NavigationLink(destination: MilestonesView()) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundColor(Theme.bitcoinOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WHOLE COINER")
                            .font(.caption.bold())
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("All milestones complete!")
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

    // MARK: - Cost Basis Change

    private var costBasisChangeView: some View {
        let change24h = priceService.change24h / 100.0 // convert from percent
        let valueChange24h = summary.currentValue * change24h / (1 + change24h)

        // For 7d, estimate from chart data
        let change7d: Double = {
            guard let firstPoint = priceService.chartData.first(where: {
                $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            }), firstPoint.price > 0 else { return 0 }
            return (priceService.currentPrice - firstPoint.price) / firstPoint.price
        }()
        let valueChange7d = summary.currentValue * change7d / (1 + change7d)

        let activeChange = show7dChange ? change7d : change24h
        let activeValueChange = show7dChange ? valueChange7d : valueChange24h
        let isUp = activeChange >= 0

        return Button {
            Haptics.select()
            withAnimation(.easeInOut(duration: 0.2)) { show7dChange.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(show7dChange ? "7d" : "24h")
                    .font(.caption2.bold())
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.darkBackground)
                    .cornerRadius(4)

                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text("\(Formatters.formatUSD(abs(activeValueChange))) (\(Formatters.formatPercent(activeChange * 100)))")
                    .font(.caption.bold())
            }
            .foregroundColor(isUp ? Theme.profitGreen.opacity(0.8) : Theme.lossRed.opacity(0.8))
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
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

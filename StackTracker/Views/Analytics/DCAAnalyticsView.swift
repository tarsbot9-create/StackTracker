import SwiftUI
import SwiftData
import Charts

struct DCAAnalyticsView: View {
    @Query(sort: \Purchase.date) private var purchases: [Purchase]
    @ObservedObject private var priceService = PriceService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @State private var showPaywall = false

    private var summary: PortfolioSummary {
        PortfolioCalculator.summary(purchases: purchases, currentPrice: priceService.currentPrice)
    }

    private var costBasisData: [(date: Date, costBasis: Double, totalInvested: Double, totalBTC: Double)] {
        PortfolioCalculator.costBasisOverTime(purchases: purchases)
    }

    private var buyPurchases: [Purchase] {
        purchases.filter { $0.transactionType == .buy }
    }

    private var yearlyStacking: [(year: String, btc: Double, isCurrent: Bool)] {
        let buys = buyPurchases
        guard !buys.isEmpty else { return [] }

        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        var byYear: [Int: Double] = [:]

        for p in buys {
            let y = cal.component(.year, from: p.date)
            byYear[y, default: 0] += p.btcAmount
        }

        return byYear.keys.sorted().map { year in
            (year: String(year), btc: byYear[year] ?? 0, isCurrent: year == currentYear)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if purchases.count < 2 {
                    emptyState
                } else if subscriptionService.isPro {
                    analyticsContent
                } else {
                    ZStack {
                        analyticsContent
                            .blur(radius: 6)
                            .allowsHitTesting(false)

                        VStack(spacing: 16) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.bitcoinOrange)

                            Text("Unlock Analytics")
                                .font(.title3.bold())
                                .foregroundColor(Theme.textPrimary)

                            Text("Get DCA charts, cost basis tracking, and performance analytics with Pro.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Button {
                                showPaywall = true
                            } label: {
                                Text("Unlock Pro")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Theme.bitcoinOrange)
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .background(Theme.darkBackground)
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .task {
            await priceService.fetchCurrentPrice()
            await priceService.fetchChartData(days: 365)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 50))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("Need More Data")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            Text("Add at least 2 purchases to see DCA analytics.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var analyticsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Grid - top of page
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    StatCard(
                        title: "Total Stack",
                        value: Formatters.formatBTC(summary.totalBTC) + " BTC",
                        subtitle: Formatters.formatUSD(summary.currentValue),
                        valueColor: Theme.bitcoinOrange,
                        icon: "bitcoinsign.circle"
                    )

                    StatCard(
                        title: "Total Return",
                        value: Formatters.formatPercent(summary.totalPLPercent),
                        subtitle: Formatters.formatUSD(summary.totalPL),
                        valueColor: summary.isProfit ? Theme.profitGreen : Theme.lossRed,
                        icon: "chart.line.uptrend.xyaxis"
                    )

                    if let first = summary.firstPurchaseDate {
                        let days = Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0
                        StatCard(
                            title: "Stacking Since",
                            value: Formatters.formatDate(first),
                            subtitle: "\(days) days",
                            icon: "calendar"
                        )
                    }

                    StatCard(
                        title: "Purchases",
                        value: "\(summary.purchaseCount)",
                        subtitle: "Total buys",
                        icon: "cart"
                    )
                }

                // BTC Stacked by Year
                chartCard(title: "BTC Stacked by Year") {
                    yearlyStackingChart
                }

                // Invested vs Value
                chartCard(title: "Total Invested vs Current Value") {
                    investedVsValueChart
                }
                HStack(spacing: 16) {
                    legendDot(color: Theme.textSecondary, label: "Invested")
                    legendDot(color: Theme.bitcoinOrange, label: "Current Value")
                }
                .padding(.horizontal, 4)
                .padding(.top, -12)

            }
            .padding(16)
        }
    }

    // MARK: - Chart Card wrapper
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 4)

            content()
                .padding(12)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Cost Basis Chart
    private var costBasisChart: some View {
        let allPrices = priceService.chartData.map(\.price) + costBasisData.map(\.costBasis)
        let lo = allPrices.min() ?? 0
        let hi = allPrices.max() ?? 1
        let range = hi - lo
        let padding = max(range * 0.15, 1000)

        return Chart {
            ForEach(priceService.chartData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price),
                    series: .value("Series", "BTC Price")
                )
                .foregroundStyle(Theme.bitcoinOrange)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Theme.bitcoinOrange.opacity(0.15), Theme.bitcoinOrange.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            ForEach(Array(costBasisData.enumerated()), id: \.offset) { _, item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Price", item.costBasis),
                    series: .value("Series", "Cost Basis")
                )
                .foregroundStyle(Theme.profitGreen)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Price", item.costBasis)
                )
                .foregroundStyle(Theme.profitGreen)
                .symbolSize(20)
            }
        }
        .chartYScale(domain: (lo - padding)...(hi + padding))
        .chartPlotStyle { plot in plot.clipped() }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cardBorder)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 180)
    }

    // MARK: - Yearly Stacking Chart
    private var yearlyStackingChart: some View {
        Chart(yearlyStacking, id: \.year) { item in
            BarMark(
                x: .value("Year", item.year),
                y: .value("BTC", item.btc)
            )
            .foregroundStyle(item.isCurrent ? Theme.bitcoinOrange : Theme.profitGreen)
            .cornerRadius(6)
            .annotation(position: .top, spacing: 4) {
                Text(Formatters.formatBTC(item.btc))
                    .font(.caption2.bold())
                    .foregroundColor(item.isCurrent ? Theme.bitcoinOrange : Theme.profitGreen)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cardBorder)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 160)
    }

    // MARK: - Invested vs Value Chart
    private var investedVsValueChart: some View {
        let allValues = costBasisData.flatMap { [$0.totalInvested, $0.totalBTC * priceService.currentPrice] }
        let lo = allValues.min() ?? 0
        let hi = allValues.max() ?? 1
        let range = hi - lo
        let padding = max(range * 0.15, 100)

        return Chart {
            ForEach(Array(costBasisData.enumerated()), id: \.offset) { _, item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("USD", item.totalInvested),
                    series: .value("Series", "Invested")
                )
                .foregroundStyle(Theme.textSecondary)
                .lineStyle(StrokeStyle(lineWidth: 2))

                LineMark(
                    x: .value("Date", item.date),
                    y: .value("USD", item.totalBTC * priceService.currentPrice),
                    series: .value("Series", "Value")
                )
                .foregroundStyle(Theme.bitcoinOrange)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("USD", item.totalBTC * priceService.currentPrice)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Theme.bitcoinOrange.opacity(0.12), Theme.bitcoinOrange.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartYScale(domain: max(0, lo - padding)...(hi + padding))
        .chartPlotStyle { plot in plot.clipped() }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cardBorder)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 170)
    }

    // MARK: - Purchase Performance Chart
    private var purchasePerformanceChart: some View {
        let buys = buyPurchases
        return Chart(buys) { purchase in
            let pl = priceService.currentPrice > 0 ? purchase.currentPL(priceService.currentPrice) : 0

            BarMark(
                x: .value("Date", purchase.date),
                y: .value("P&L %", pl)
            )
            .foregroundStyle(pl >= 0 ? Theme.profitGreen : Theme.lossRed)
            .cornerRadius(3)
        }
        .chartPlotStyle { plot in plot.clipped() }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cardBorder)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 150)
    }
}

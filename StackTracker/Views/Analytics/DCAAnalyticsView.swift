import SwiftUI
import SwiftData
import Charts

struct DCAAnalyticsView: View {
    @Query(sort: \Purchase.date) private var purchases: [Purchase]
    @StateObject private var priceService = PriceService()

    private var summary: PortfolioSummary {
        PortfolioCalculator.summary(purchases: purchases, currentPrice: priceService.currentPrice)
    }

    private var costBasisData: [(date: Date, costBasis: Double, totalInvested: Double, totalBTC: Double)] {
        PortfolioCalculator.costBasisOverTime(purchases: purchases)
    }

    var body: some View {
        NavigationStack {
            Group {
                if purchases.count < 2 {
                    emptyState
                } else {
                    analyticsContent
                }
            }
            .background(Theme.darkBackground)
            .navigationTitle("Analytics")
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                // Cost Basis vs BTC Price Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Cost Basis vs BTC Price")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 4)

                    costBasisChart
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )

                    // Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.bitcoinOrange).frame(width: 8, height: 8)
                            Text("BTC Price").font(.caption2).foregroundColor(Theme.textSecondary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Theme.profitGreen).frame(width: 8, height: 8)
                            Text("Your Avg Cost").font(.caption2).foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // Invested vs Value Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Invested vs Current Value")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 4)

                    investedVsValueChart
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                }

                // Per-Purchase Performance
                VStack(alignment: .leading, spacing: 8) {
                    Text("Per-Purchase Performance")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 4)

                    purchasePerformanceChart
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                }

                // DCA Stats
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    StatCard(
                        title: "Avg Cost Basis",
                        value: Formatters.formatUSDCompact(summary.averageCostBasis),
                        subtitle: priceService.currentPrice > summary.averageCostBasis ? "Below market" : "Above market",
                        valueColor: priceService.currentPrice > summary.averageCostBasis ? Theme.profitGreen : Theme.lossRed,
                        icon: "target"
                    )

                    StatCard(
                        title: "DCA Streak",
                        value: "\(summary.dcaStreak) weeks",
                        subtitle: summary.dcaStreak > 4 ? "Keep stacking!" : "Stay consistent",
                        valueColor: Theme.bitcoinOrange,
                        icon: "flame"
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
                        title: "Total Return",
                        value: Formatters.formatPercent(summary.totalPLPercent),
                        subtitle: Formatters.formatUSD(summary.totalPL),
                        valueColor: summary.isProfit ? Theme.profitGreen : Theme.lossRed,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
            }
            .padding(16)
        }
    }

    private var costBasisChart: some View {
        Chart {
            // BTC price line from API data
            ForEach(priceService.chartData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price),
                    series: .value("Series", "BTC Price")
                )
                .foregroundStyle(Theme.bitcoinOrange)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Cost basis line from purchases
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
                .symbolSize(30)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cardBorder)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 220)
    }

    private var investedVsValueChart: some View {
        Chart {
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
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cardBorder)
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel().foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(height: 200)
    }

    private var purchasePerformanceChart: some View {
        Chart(purchases) { purchase in
            let pl = priceService.currentPrice > 0 ? purchase.currentPL(priceService.currentPrice) : 0

            BarMark(
                x: .value("Date", purchase.date),
                y: .value("P&L %", pl)
            )
            .foregroundStyle(pl >= 0 ? Theme.profitGreen : Theme.lossRed)
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
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
}

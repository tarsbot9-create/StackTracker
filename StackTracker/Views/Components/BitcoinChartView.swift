import SwiftUI
import Charts

struct BitcoinChartView: View {
    let data: [PricePoint]
    var height: CGFloat = 200
    var showAxis: Bool = true
    var lineColor: Color = Theme.bitcoinOrange

    private var yDomain: ClosedRange<Double> {
        let prices = data.map(\.price)
        guard let lo = prices.min(), let hi = prices.max(), hi > lo else {
            let p = prices.first ?? 0
            return (p * 0.95)...(p * 1.05)
        }
        let range = hi - lo
        let padding = range * 0.25
        return (lo - padding)...(hi + padding)
    }

    var body: some View {
        if data.isEmpty {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground)
                .frame(height: height)
                .overlay(
                    ProgressView()
                        .tint(Theme.bitcoinOrange)
                )
        } else {
            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(lineColor)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [lineColor.opacity(0.3), lineColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: yDomain)
            .chartPlotStyle { plotArea in
                plotArea.clipped()
            }
            .chartXAxis(showAxis ? .automatic : .hidden)
            .chartYAxis(showAxis ? .automatic : .hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.cardBorder)
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.cardBorder)
                    AxisValueLabel()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: height)
        }
    }
}

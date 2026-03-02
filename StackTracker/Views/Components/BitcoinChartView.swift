import SwiftUI
import Charts

struct BitcoinChartView: View {
    let data: [PricePoint]
    var height: CGFloat = 200
    var showAxis: Bool = true
    var lineColor: Color = Theme.bitcoinOrange

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

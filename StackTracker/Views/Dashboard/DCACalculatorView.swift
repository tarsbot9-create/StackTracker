import SwiftUI

/// A simple DCA planning calculator accessible from the Dashboard.
/// Helps users visualize how much BTC they'll accumulate at different
/// weekly/monthly contribution levels at current prices.
struct DCACalculatorView: View {
    @ObservedObject private var priceService = PriceService.shared

    @State private var weeklyAmount: String = "50"
    @State private var months: Double = 12
    @State private var selectedPreset: Int? = nil

    private let presets = [25, 50, 100, 200, 500]

    private var weeklyUSD: Double {
        Double(weeklyAmount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var totalWeeks: Int {
        Int(months * 4.33)
    }

    private var totalInvested: Double {
        weeklyUSD * Double(totalWeeks)
    }

    private var btcAccumulated: Double {
        guard priceService.currentPrice > 0 else { return 0 }
        return totalInvested / priceService.currentPrice
    }

    private var satsAccumulated: Int {
        Int(btcAccumulated * 100_000_000)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Weekly amount
                VStack(alignment: .leading, spacing: 10) {
                    Text("Weekly DCA Amount")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                weeklyAmount = "\(preset)"
                                selectedPreset = preset
                                Haptics.select()
                            } label: {
                                Text("$\(preset)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(selectedPreset == preset ? .black : Theme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedPreset == preset ? Theme.bitcoinOrange : Theme.cardBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedPreset == preset ? Color.clear : Theme.cardBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }

                    HStack {
                        Text("$")
                            .foregroundColor(Theme.textSecondary)
                        TextField("Custom amount", text: $weeklyAmount)
                            .keyboardType(.numberPad)
                            .foregroundColor(Theme.textPrimary)
                            .onChange(of: weeklyAmount) { _, _ in
                                selectedPreset = nil
                            }
                    }
                    .padding(12)
                    .background(Theme.cardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                }

                // Time horizon slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Time Horizon")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(Int(months)) months")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.bitcoinOrange)
                    }

                    Slider(value: $months, in: 1...60, step: 1) {
                        Text("Months")
                    }
                    .tint(Theme.bitcoinOrange)

                    HStack {
                        Text("1 mo")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("5 years")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                // Results card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("Projection at Current Price")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }

                    Divider().background(Theme.cardBorder)

                    // BTC accumulated
                    VStack(spacing: 4) {
                        Text(Formatters.formatBTC(btcAccumulated))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("BTC")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text(Formatters.satsFormatter.string(from: NSNumber(value: satsAccumulated)) ?? "0" + " sats")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    Divider().background(Theme.cardBorder)

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        resultStat(title: "Total Invested", value: Formatters.formatUSD(totalInvested))
                        resultStat(title: "Weeks", value: "\(totalWeeks)")
                        resultStat(title: "Monthly", value: Formatters.formatUSD(weeklyUSD * 4.33))
                        resultStat(title: "Sats per $1", value: satsPerDollar)
                    }
                }
                .padding(16)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )

                // Disclaimer
                Text("Assumes constant BTC price of \(Formatters.formatUSD(priceService.currentPrice)). Actual results will vary based on price changes. DCA means you buy at many prices over time.")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(16)
        }
        .background(Theme.darkBackground)
        .navigationTitle("DCA Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var satsPerDollar: String {
        guard priceService.currentPrice > 0 else { return "0" }
        let sats = Int(100_000_000 / priceService.currentPrice)
        return Formatters.satsFormatter.string(from: NSNumber(value: sats)) ?? "0"
    }

    private func resultStat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(Theme.textPrimary)
        }
    }
}

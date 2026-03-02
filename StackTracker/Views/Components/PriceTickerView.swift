import SwiftUI

struct PriceTickerView: View {
    let price: Double
    let change24h: Double

    var isPositive: Bool { change24h >= 0 }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bitcoin")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(Formatters.formatUSDCompact(price))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.bold())
                Text(Formatters.formatPercent(change24h))
                    .font(.subheadline.bold())
            }
            .foregroundColor(isPositive ? Theme.profitGreen : Theme.lossRed)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (isPositive ? Theme.profitGreen : Theme.lossRed).opacity(0.15)
            )
            .cornerRadius(8)
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

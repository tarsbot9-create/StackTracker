import SwiftUI

struct DisposalDetailView: View {
    let result: DisposalResult
    let method: AccountingMethod

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Card
                headerCard

                // Summary Row
                summaryGrid

                // Lot Matches
                lotMatchesSection
            }
            .padding(16)
        }
        .background(Theme.darkBackground)
        .navigationTitle(result.disposal.type == .sell ? "Sale Details" : "Payment Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: result.disposal.type == .sell ? "arrow.up.circle.fill" : "creditcard.fill")
                    .font(.title2)
                    .foregroundColor(Theme.lossRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.disposal.type == .sell ? "Bitcoin Sale" : "Bitcoin Payment")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Text(Formatters.formatDate(result.disposal.date))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Formatters.formatBTC(result.disposal.btcAmount)) BTC")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(Theme.bitcoinOrange)
                    Text("@ \(Formatters.formatUSD(result.disposal.proceedsPerBTC))")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Divider().background(Theme.cardBorder)

            // Net Gain/Loss
            VStack(spacing: 4) {
                Text("Net Capital Gain/Loss")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(Formatters.formatUSD(result.totalGain))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(result.totalGain >= 0 ? Theme.profitGreen : Theme.lossRed)
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Summary Grid

    private var summaryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            miniCard(
                title: "Proceeds",
                value: Formatters.formatUSD(result.totalProceeds),
                color: Theme.textPrimary
            )

            miniCard(
                title: "Cost Basis",
                value: Formatters.formatUSD(result.totalCostBasis),
                color: Theme.textPrimary
            )

            miniCard(
                title: "Short-Term",
                value: Formatters.formatUSD(result.shortTermGain),
                color: result.shortTermGain >= 0 ? Theme.profitGreen : Theme.lossRed
            )

            miniCard(
                title: "Long-Term",
                value: Formatters.formatUSD(result.longTermGain),
                color: result.longTermGain >= 0 ? Theme.profitGreen : Theme.lossRed
            )

            miniCard(
                title: "Method",
                value: method.rawValue,
                color: Theme.bitcoinOrange
            )

            miniCard(
                title: "Lots Used",
                value: "\(result.matches.count)",
                color: Theme.textPrimary
            )
        }
    }

    private func miniCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Lot Matches

    private var lotMatchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lot Matching (\(method.rawValue))")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 4)

            ForEach(result.matches) { match in
                lotMatchRow(match)
            }
        }
    }

    private func lotMatchRow(_ match: LotMatch) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Purchased \(Formatters.formatDate(match.lotDate))")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)

                    Text("@ \(Formatters.formatUSD(match.lotPricePerBTC)) per BTC")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Formatters.formatBTC(match.btcAmount)) BTC")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundColor(Theme.bitcoinOrange)

                    Text(match.isLongTerm ? "Long-term" : "Short-term")
                        .font(.caption2)
                        .foregroundColor(match.isLongTerm ? Theme.profitGreen : Theme.bitcoinOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (match.isLongTerm ? Theme.profitGreen : Theme.bitcoinOrange).opacity(0.15)
                        )
                        .cornerRadius(4)
                }
            }

            Divider().background(Theme.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cost Basis")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(match.costBasis))
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Held")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(match.holdingDays)d")
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Gain/Loss")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(match.gain))
                        .font(.caption.bold())
                        .foregroundColor(match.gain >= 0 ? Theme.profitGreen : Theme.lossRed)
                }
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

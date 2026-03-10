import SwiftUI
import SwiftData

struct OpenLotsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Purchase.date) private var purchases: [Purchase]
    @ObservedObject private var priceService = PriceService.shared

    @State private var sortBy: LotSort = .dateOldest

    enum LotSort: String, CaseIterable, Identifiable {
        case dateOldest = "Oldest"
        case dateNewest = "Newest"
        case sizeDesc = "Largest"
        case gainDesc = "Most Gain"

        var id: String { rawValue }
    }

    private var openLots: [OpenLot] {
        let buys = purchases.filter { $0.transactionType == .buy }.sorted { $0.date < $1.date }
        let disposals = purchases
            .filter { $0.transactionType == .sell || $0.transactionType == .payment }
            .sorted { $0.date < $1.date }
            .map { Disposal(from: $0) }

        var lots = buys.map { TaxLot(from: $0) }

        // Replay all disposals using FIFO to find remaining lots
        for disposal in disposals {
            var remaining = disposal.btcAmount
            while remaining > 0.00000001 {
                guard let idx = lots.enumerated()
                    .filter({ $0.element.remainingBTC > 0.00000001 })
                    .min(by: { $0.element.date < $1.element.date })?.offset
                else { break }
                let consumed = min(remaining, lots[idx].remainingBTC)
                lots[idx].remainingBTC -= consumed
                remaining -= consumed
            }
        }

        let now = Date()
        let calendar = Calendar.current

        return lots
            .filter { $0.remainingBTC > 0.00000001 }
            .map { lot in
                let holdingDays = calendar.dateComponents([.day], from: lot.date, to: now).day ?? 0
                let isLongTerm = holdingDays > 365
                let currentValue = lot.remainingBTC * priceService.currentPrice
                let costBasis = lot.remainingBTC * lot.pricePerBTC
                let gain = currentValue - costBasis

                return OpenLot(
                    id: lot.id,
                    date: lot.date,
                    remainingBTC: lot.remainingBTC,
                    originalBTC: lot.originalBTC,
                    pricePerBTC: lot.pricePerBTC,
                    costBasis: costBasis,
                    currentValue: currentValue,
                    gain: gain,
                    holdingDays: holdingDays,
                    isLongTerm: isLongTerm,
                    walletName: lot.walletName
                )
            }
    }

    private var sortedLots: [OpenLot] {
        switch sortBy {
        case .dateOldest: return openLots.sorted { $0.date < $1.date }
        case .dateNewest: return openLots.sorted { $0.date > $1.date }
        case .sizeDesc: return openLots.sorted { $0.remainingBTC > $1.remainingBTC }
        case .gainDesc: return openLots.sorted { $0.gain > $1.gain }
        }
    }

    private var totalRemaining: Double {
        openLots.reduce(0) { $0 + $1.remainingBTC }
    }

    private var totalCostBasis: Double {
        openLots.reduce(0) { $0 + $1.costBasis }
    }

    private var totalValue: Double {
        openLots.reduce(0) { $0 + $1.currentValue }
    }

    private var longTermCount: Int {
        openLots.filter { $0.isLongTerm }.count
    }

    private var shortTermCount: Int {
        openLots.filter { !$0.isLongTerm }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary card
                    summaryCard

                    // Sort picker
                    sortPicker

                    // Lots list
                    if sortedLots.isEmpty {
                        emptyState
                    } else {
                        ForEach(sortedLots) { lot in
                            lotCard(lot)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.darkBackground)
            .navigationTitle("Open Lots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.bitcoinOrange)
                }
            }
        }
        .task {
            await priceService.fetchCurrentPrice()
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundColor(Theme.bitcoinOrange)
                Text("\(openLots.count) Open Lots")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(Formatters.formatBTC(totalRemaining)) BTC")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundColor(Theme.bitcoinOrange)
            }

            Divider().background(Theme.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost Basis")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(totalCostBasis))
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Value")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(totalValue))
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                }
            }

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.profitGreen)
                        .frame(width: 8, height: 8)
                    Text("\(longTermCount) long-term")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.bitcoinOrange)
                        .frame(width: 8, height: 8)
                    Text("\(shortTermCount) short-term")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Sort Picker

    private var sortPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LotSort.allCases) { sort in
                    let isSelected = sortBy == sort
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { sortBy = sort }
                    } label: {
                        Text(sort.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(isSelected ? .black : Theme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Theme.bitcoinOrange : Theme.cardBackground)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(isSelected ? Color.clear : Theme.cardBorder, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    // MARK: - Lot Card

    private func lotCard(_ lot: OpenLot) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.formatDate(lot.date))
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text(lot.walletName)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Formatters.formatBTC(lot.remainingBTC)) BTC")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundColor(Theme.bitcoinOrange)

                    if lot.remainingBTC < lot.originalBTC {
                        Text("of \(Formatters.formatBTC(lot.originalBTC)) original")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            // Progress bar to long-term
            if !lot.isLongTerm {
                VStack(alignment: .leading, spacing: 4) {
                    let progress = min(1.0, Double(lot.holdingDays) / 365.0)
                    let daysLeft = max(0, 366 - lot.holdingDays)

                    HStack {
                        Text("\(daysLeft) days until long-term")
                            .font(.caption2)
                            .foregroundColor(Theme.bitcoinOrange)
                        Spacer()
                        Text("\(lot.holdingDays)/365 days")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.cardBorder)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.bitcoinOrange)
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }

            Divider().background(Theme.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cost Basis")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(lot.costBasis))
                        .font(.caption.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("@ \(Formatters.formatUSD(lot.pricePerBTC))")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Status")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(lot.isLongTerm ? "Long-term" : "Short-term")
                        .font(.caption.bold())
                        .foregroundColor(lot.isLongTerm ? Theme.profitGreen : Theme.bitcoinOrange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (lot.isLongTerm ? Theme.profitGreen : Theme.bitcoinOrange).opacity(0.15)
                        )
                        .cornerRadius(6)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Gain/Loss")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(lot.gain))
                        .font(.caption.bold())
                        .foregroundColor(lot.gain >= 0 ? Theme.profitGreen : Theme.lossRed)
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("No open lots")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Text("Import purchases to see your lot holdings.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Open Lot Model

struct OpenLot: Identifiable {
    let id: UUID
    let date: Date
    let remainingBTC: Double
    let originalBTC: Double
    let pricePerBTC: Double
    let costBasis: Double
    let currentValue: Double
    let gain: Double
    let holdingDays: Int
    let isLongTerm: Bool
    let walletName: String
}

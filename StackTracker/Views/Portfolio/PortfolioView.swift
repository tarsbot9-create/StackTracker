import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @StateObject private var priceService = PriceService()

    @State private var sortBy: SortOption = .dateDesc
    @State private var filterWallet: String? = nil
    @State private var purchaseToDelete: Purchase?

    enum SortOption: String, CaseIterable {
        case dateDesc = "Newest"
        case dateAsc = "Oldest"
        case amountDesc = "Largest"
        case plDesc = "Best P&L"
        case plAsc = "Worst P&L"
    }

    private var wallets: [String] {
        Array(Set(purchases.map(\.walletName))).sorted()
    }

    private var sortedPurchases: [Purchase] {
        let filtered = filterWallet == nil ? purchases : purchases.filter { $0.walletName == filterWallet }
        let price = priceService.currentPrice

        switch sortBy {
        case .dateDesc: return filtered.sorted { $0.date > $1.date }
        case .dateAsc: return filtered.sorted { $0.date < $1.date }
        case .amountDesc: return filtered.sorted { $0.btcAmount > $1.btcAmount }
        case .plDesc: return filtered.sorted { $0.currentPL(price) > $1.currentPL(price) }
        case .plAsc: return filtered.sorted { $0.currentPL(price) < $1.currentPL(price) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if purchases.isEmpty {
                    emptyState
                } else {
                    purchaseList
                }
            }
            .background(Theme.darkBackground)
            .navigationTitle("Portfolio")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await priceService.fetchCurrentPrice()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(Theme.textSecondary.opacity(0.5))
            Text("No purchases yet")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            Text("Add your first BTC purchase to start tracking.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var purchaseList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Filters
                VStack(spacing: 10) {
                    // Sort
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    withAnimation { sortBy = option }
                                } label: {
                                    Text(option.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(sortBy == option ? Theme.bitcoinOrange : Theme.cardBackground)
                                        .foregroundColor(sortBy == option ? .black : Theme.textSecondary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // Wallet filter
                    if wallets.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation { filterWallet = nil }
                                } label: {
                                    Text("All")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(filterWallet == nil ? Theme.bitcoinOrange : Theme.cardBackground)
                                        .foregroundColor(filterWallet == nil ? .black : Theme.textSecondary)
                                        .cornerRadius(8)
                                }

                                ForEach(wallets, id: \.self) { wallet in
                                    Button {
                                        withAnimation { filterWallet = wallet }
                                    } label: {
                                        Text(wallet)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(filterWallet == wallet ? Theme.bitcoinOrange : Theme.cardBackground)
                                            .foregroundColor(filterWallet == wallet ? .black : Theme.textSecondary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Purchase Cards
                ForEach(sortedPurchases) { purchase in
                    PurchaseCard(purchase: purchase, currentPrice: priceService.currentPrice)
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(purchase)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
    }
}

struct PurchaseCard: View {
    let purchase: Purchase
    let currentPrice: Double

    private var pl: Double {
        guard currentPrice > 0 else { return 0 }
        return purchase.currentPL(currentPrice)
    }

    private var plUSD: Double {
        guard currentPrice > 0 else { return 0 }
        return (currentPrice - purchase.pricePerBTC) * purchase.btcAmount
    }

    private var isProfit: Bool { pl >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatters.formatDate(purchase.date))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(purchase.walletName)
                        .font(.caption2)
                        .foregroundColor(Theme.bitcoinOrange.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(Formatters.formatPercent(pl))
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(isProfit ? Theme.profitGreen : Theme.lossRed)

                    Text(Formatters.formatUSD(plUSD))
                        .font(.caption)
                        .foregroundColor(isProfit ? Theme.profitGreen.opacity(0.7) : Theme.lossRed.opacity(0.7))
                }
            }

            Divider().background(Theme.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatBTC(purchase.btcAmount) + " BTC")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text(Formatters.formatSats(purchase.btcAmount) + " sats")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Cost")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(purchase.usdSpent))
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Price/BTC")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSDCompact(purchase.pricePerBTC))
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                }
            }

            if !purchase.notes.isEmpty {
                Text(purchase.notes)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .italic()
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

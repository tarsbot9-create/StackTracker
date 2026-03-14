import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @ObservedObject private var priceService = PriceService.shared

    @State private var sortBy: SortOption = .dateDesc
    @State private var typeFilter: TypeFilter = .all
    @State private var searchText: String = ""
    @State private var showAddPurchase = false

    enum SortOption: String, CaseIterable {
        case dateDesc = "Newest"
        case dateAsc = "Oldest"
        case amountDesc = "Largest"
        case amountAsc = "Smallest"
        case plDesc = "Top Performers"
        case plAsc = "Worst Performers"
        case flagged = "Flagged"
    }

    enum TypeFilter: String, CaseIterable {
        case all = "All"
        case buys = "Buys"
        case sells = "Sells"
    }

    private var filteredPurchases: [Purchase] {
        let price = priceService.currentPrice

        // Type filter
        var result: [Purchase]
        switch typeFilter {
        case .all:
            result = purchases.filter { $0.transactionType == .buy || $0.transactionType == .sell }
        case .buys:
            result = purchases.filter { $0.transactionType == .buy }
        case .sells:
            result = purchases.filter { $0.transactionType == .sell }
        }

        // Flagged filter (from sort chip)
        if sortBy == .flagged {
            result = result.filter { $0.isFlagged }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium

            result = result.filter { purchase in
                if purchase.walletName.lowercased().contains(query) { return true }
                if purchase.notes.lowercased().contains(query) { return true }
                if dateFormatter.string(from: purchase.date).lowercased().contains(query) { return true }
                if String(format: "%.8f", purchase.btcAmount).contains(query) { return true }
                if String(format: "%.2f", purchase.usdSpent).contains(query) { return true }
                if String(format: "%.0f", purchase.pricePerBTC).contains(query) { return true }
                return false
            }
        }

        // Sort (flagged keeps default date descending)
        switch sortBy {
        case .dateDesc, .flagged: result.sort { $0.date > $1.date }
        case .dateAsc: result.sort { $0.date < $1.date }
        case .amountDesc: result.sort { $0.btcAmount > $1.btcAmount }
        case .amountAsc: result.sort { $0.btcAmount < $1.btcAmount }
        case .plDesc: result.sort { $0.currentPL(price) > $1.currentPL(price) }
        case .plAsc: result.sort { $0.currentPL(price) < $1.currentPL(price) }
        }

        return result
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        typeFilterMenu

                        Button {
                            showAddPurchase = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.bitcoinOrange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddPurchase) {
                AddPurchaseView()
            }
        }
        .task {
            await priceService.fetchCurrentPrice()
        }
        .refreshable {
            Haptics.tap()
            await priceService.fetchCurrentPrice()
        }
    }

    // MARK: - Type Filter Menu

    private var typeFilterMenu: some View {
        Menu {
            ForEach(TypeFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation { typeFilter = filter }
                } label: {
                    HStack {
                        Text(filter.rawValue)
                        if typeFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                if typeFilter != .all {
                    Text(typeFilter.rawValue)
                        .font(.caption.bold())
                }
            }
            .foregroundColor(typeFilter == .all ? Theme.bitcoinOrange : Theme.bitcoinOrange)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 60))
                .foregroundColor(Theme.bitcoinOrange.opacity(0.5))

            Text("No Transactions Yet")
                .font(.title3.bold())
                .foregroundColor(Theme.textPrimary)

            Text("Add your first Bitcoin purchase manually, or import from CSV to see your full transaction history.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showAddPurchase = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add First Purchase")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.bitcoinOrange)
                .foregroundColor(.black)
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Portfolio Summary Card

    private var portfolioSummaryCard: some View {
        let buys = purchases.filter { $0.transactionType == .buy }
        let totalInvested = buys.reduce(0.0) { $0 + $1.usdSpent }
        let totalBTC = buys.reduce(0.0) { $0 + $1.btcAmount } - purchases.filter { $0.transactionType == .sell }.reduce(0.0) { $0 + $1.btcAmount }
        let currentValue = totalBTC * priceService.currentPrice
        let totalPL = currentValue - totalInvested
        let plPercent = totalInvested > 0 ? (totalPL / totalInvested) * 100 : 0
        let avgCost = totalBTC > 0 ? totalInvested / totalBTC : 0
        let isProfit = totalPL >= 0

        return HStack(spacing: 0) {
            // Left: invested vs value
            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text("Invested")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(totalInvested))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                VStack(spacing: 2) {
                    Text("Value")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(currentValue))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1, height: 50)

            // Center: P/L
            VStack(spacing: 4) {
                Text("Total P/L")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Text(Formatters.formatUSD(totalPL))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(isProfit ? Theme.profitGreen : Theme.lossRed)
                Text(Formatters.formatPercent(plPercent))
                    .font(.caption2.bold())
                    .foregroundColor(isProfit ? Theme.profitGreen : Theme.lossRed)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1, height: 50)

            // Right: avg cost basis
            VStack(spacing: 4) {
                Text("Avg Cost")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Text(Formatters.formatUSDCompact(avgCost))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("per BTC")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Purchase List

    private var purchaseList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Portfolio summary
                portfolioSummaryCard

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                    TextField("Search wallet, notes, amount...", text: $searchText)
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(10)
                .background(Theme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)

                // Sort chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            sortChip(option)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Results count
                HStack {
                    Text("\(filteredPurchases.count) transaction\(filteredPurchases.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    if typeFilter != .all {
                        Text(typeFilter.rawValue)
                            .font(.caption)
                            .foregroundColor(Theme.bitcoinOrange)
                    }
                }
                .padding(.horizontal, 20)

                // Purchase cards
                if filteredPurchases.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: sortBy == .flagged ? "flag" : "magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                        Text(sortBy == .flagged ? "No flagged transactions" : "No results found")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        if sortBy == .flagged {
                            Text("Swipe right on a transaction to flag it.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ForEach(filteredPurchases) { purchase in
                        NavigationLink(destination: TransactionDetailView(purchase: purchase)) {
                            PurchaseCard(purchase: purchase, currentPrice: priceService.currentPrice, onToggleFlag: {
                                toggleFlag(purchase)
                            })
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                toggleFlag(purchase)
                            } label: {
                                Label(
                                    purchase.isFlagged ? "Unflag" : "Flag",
                                    systemImage: purchase.isFlagged ? "flag.slash" : "flag.fill"
                                )
                            }

                            Button(role: .destructive) {
                                context.delete(purchase)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                toggleFlag(purchase)
                            } label: {
                                Label(
                                    purchase.isFlagged ? "Unflag" : "Flag",
                                    systemImage: purchase.isFlagged ? "flag.slash.fill" : "flag.fill"
                                )
                            }
                            .tint(Theme.bitcoinOrange)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(purchase)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Sort Chip

    private func sortChip(_ option: SortOption) -> some View {
        let isSelected = sortBy == option

        return Button {
            Haptics.select()
            withAnimation(.easeInOut(duration: 0.2)) { sortBy = option }
        } label: {
            HStack(spacing: 4) {
                if option == .flagged {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                }
                Text(option.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .black : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.bitcoinOrange : Theme.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Theme.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func toggleFlag(_ purchase: Purchase) {
        Haptics.tap()
        withAnimation {
            purchase.isFlagged.toggle()
        }
    }
}

// MARK: - Purchase Card

struct PurchaseCard: View {
    let purchase: Purchase
    let currentPrice: Double
    var onToggleFlag: (() -> Void)? = nil

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
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                    .foregroundColor(isProfit ? Theme.profitGreen : Theme.lossRed)

                    Text(Formatters.formatUSD(plUSD))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(isProfit ? Theme.profitGreen.opacity(0.7) : Theme.lossRed.opacity(0.7))
                }

                // Flag button
                Button {
                    onToggleFlag?()
                } label: {
                    Image(systemName: purchase.isFlagged ? "flag.fill" : "flag")
                        .font(.caption)
                        .foregroundColor(purchase.isFlagged ? Theme.bitcoinOrange : Theme.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }

            Divider().background(Theme.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatBTC(purchase.btcAmount) + " BTC")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(Formatters.formatSats(purchase.btcAmount) + " sats")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Cost")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(purchase.usdSpent))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Price/BTC")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSDCompact(purchase.pricePerBTC))
                        .font(.system(.subheadline, design: .rounded))
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
                .stroke(purchase.isFlagged ? Theme.bitcoinOrange.opacity(0.3) : Theme.cardBorder, lineWidth: 1)
        )
    }
}

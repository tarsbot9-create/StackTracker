import SwiftUI
import SwiftData

struct AddressDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date) private var purchases: [Purchase]
    @StateObject private var blockchain = BlockchainService()
    @StateObject private var priceService = PriceService()

    let address: WatchedAddress

    @State private var transactions: [AddressTransaction] = []
    @State private var isLoading = true
    @State private var showManualEntry = false
    @State private var selectedTx: AddressTransaction?
    @State private var manualPrice = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Balance Card
                VStack(spacing: 8) {
                    Text(address.label)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text("\(Formatters.formatBTC(address.cachedBalance)) BTC")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(Theme.bitcoinOrange)

                    Text(Formatters.formatSats(address.cachedBalance) + " sats")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    if priceService.currentPrice > 0 {
                        Text(Formatters.formatUSD(address.cachedBalance * priceService.currentPrice))
                            .font(.title3.bold())
                            .foregroundColor(Theme.textPrimary)
                    }

                    // Address (truncated)
                    Text(truncateAddress(address.address))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 4)

                    if let synced = address.lastSyncedAt {
                        Text("Synced \(synced, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )

                // Cost Basis Summary
                if !transactions.isEmpty {
                    let incoming = transactions.filter { $0.isIncoming }
                    let matched = incoming.filter { $0.costBasisSource == "matched" }
                    let manual = incoming.filter { $0.costBasisSource == "manual" }
                    let historical = incoming.filter { $0.costBasisSource == "historical" }
                    let unset = incoming.filter { $0.costBasisSource == "unset" }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cost Basis Coverage")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        HStack(spacing: 16) {
                            costBadge("Matched", count: matched.count, color: .green)
                            costBadge("Manual", count: manual.count, color: .blue)
                            costBadge("Historical", count: historical.count, color: .yellow)
                            costBadge("Unknown", count: unset.count, color: Theme.lossRed)
                        }

                        if !incoming.isEmpty {
                            let coveredBTC = incoming.filter { $0.costBasisSource != "unset" }.reduce(0.0) { $0 + $1.btcAmount }
                            let totalBTC = incoming.reduce(0.0) { $0 + $1.btcAmount }
                            let pct = totalBTC > 0 ? coveredBTC / totalBTC * 100 : 0

                            ProgressView(value: coveredBTC, total: totalBTC)
                                .tint(Theme.bitcoinOrange)

                            Text("\(String(format: "%.0f", pct))% of incoming BTC has cost basis")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                }

                // Transactions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transactions")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 4)

                    if isLoading {
                        ProgressView("Loading transactions...")
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else if transactions.isEmpty {
                        Text("No transactions found.")
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    } else {
                        ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                            transactionRow(tx, index: index)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.darkBackground)
        .navigationTitle("Address")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await priceService.fetchCurrentPrice()
            await loadTransactions()
        }
        .sheet(isPresented: $showManualEntry) {
            manualCostBasisSheet
        }
    }

    // MARK: - Transaction Row

    private func transactionRow(_ tx: AddressTransaction, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tx.isIncoming ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                .foregroundColor(tx.isIncoming ? Theme.profitGreen : Theme.lossRed)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tx.isIncoming ? "Received" : "Sent")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)

                    if tx.isIncoming {
                        costBasisTag(tx.costBasisSource)
                    }
                }

                Text(tx.date, style: .date)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                if tx.costBasisSource != "unset" && tx.pricePerBTC > 0 {
                    Text("@ \(Formatters.formatUSDCompact(tx.pricePerBTC)) per BTC")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(tx.isIncoming ? "+" : "-")\(Formatters.formatBTC(tx.btcAmount))")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundColor(tx.isIncoming ? Theme.profitGreen : Theme.lossRed)

                if tx.isIncoming && tx.costBasisSource == "unset" {
                    Button("Set Cost") {
                        selectedTx = tx
                        showManualEntry = true
                    }
                    .font(.caption.bold())
                    .foregroundColor(Theme.bitcoinOrange)
                }
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    private func costBasisTag(_ source: String) -> some View {
        let (text, color): (String, Color) = {
            switch source {
            case "matched": return ("Auto-matched", .green)
            case "manual": return ("Manual", .blue)
            case "historical": return ("Historical", .yellow)
            default: return ("No cost basis", Theme.lossRed)
            }
        }()

        return Text(text)
            .font(.caption2.bold())
            .foregroundColor(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }

    private func costBadge(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Manual Cost Basis Sheet

    private var manualCostBasisSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let tx = selectedTx {
                    VStack(spacing: 8) {
                        Text("Set Cost Basis")
                            .font(.title3.bold())
                            .foregroundColor(Theme.textPrimary)

                        Text("\(Formatters.formatBTC(tx.btcAmount)) BTC received on")
                            .foregroundColor(Theme.textSecondary)

                        Text(tx.date, style: .date)
                            .font(.headline)
                            .foregroundColor(Theme.bitcoinOrange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price per BTC at time of purchase")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        HStack {
                            Text("$")
                                .foregroundColor(Theme.textSecondary)
                            TextField("e.g. 42000", text: $manualPrice)
                                .keyboardType(.decimalPad)
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(10)
                    }

                    Button {
                        applyManualCostBasis(tx)
                    } label: {
                        Text("Save Cost Basis")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.bitcoinOrange)
                            .cornerRadius(12)
                    }

                    Button {
                        applyHistoricalCostBasis(tx)
                    } label: {
                        Text("Use Historical Price (\(tx.date, style: .date))")
                            .font(.subheadline)
                            .foregroundColor(Theme.bitcoinOrange)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Theme.darkBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showManualEntry = false
                        selectedTx = nil
                        manualPrice = ""
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let txs = try await blockchain.fetchTransactions(address.address)
            var parsed = blockchain.parseTransactions(txs: txs, forAddress: address.address)

            // Auto-match with existing purchases
            let candidates = purchases.map { p in
                ExchangeWithdrawalCandidate(
                    id: p.id,
                    date: p.date,
                    btcAmount: p.btcAmount,
                    pricePerBTC: p.pricePerBTC
                )
            }
            parsed = blockchain.autoMatchTransactions(addressTxs: parsed, purchases: candidates)

            // Check if we have any already saved in the DB
            let addrString = address.address
            let descriptor = FetchDescriptor<AddressTransaction>(
                predicate: #Predicate { $0.address == addrString }
            )
            let existing = (try? context.fetch(descriptor)) ?? []
            let existingTxids = Set(existing.map(\.txid))

            // Merge: keep existing cost basis data, add new txs
            for i in parsed.indices {
                if let saved = existing.first(where: { $0.txid == parsed[i].txid }) {
                    parsed[i].costBasisSource = saved.costBasisSource
                    parsed[i].pricePerBTC = saved.pricePerBTC
                    parsed[i].usdValue = saved.usdValue
                    parsed[i].matchedPurchaseID = saved.matchedPurchaseID
                }
            }

            // Save new transactions
            for tx in parsed where !existingTxids.contains(tx.txid) {
                context.insert(tx)
            }

            transactions = parsed

            // Update address balance
            let info = try await blockchain.fetchAddressInfo(address.address)
            address.cachedBalance = info.confirmedBalanceBTC
            address.lastSyncedAt = .now
        } catch {
            blockchain.lastError = error.localizedDescription
        }
    }

    private func refresh() async {
        await loadTransactions()
    }

    private func applyManualCostBasis(_ tx: AddressTransaction) {
        guard let price = Double(manualPrice), price > 0 else { return }

        if let idx = transactions.firstIndex(where: { $0.id == tx.id }) {
            transactions[idx].costBasisSource = "manual"
            transactions[idx].pricePerBTC = price
            transactions[idx].usdValue = transactions[idx].btcAmount * price

            // Update in DB
            let txid = tx.txid
            let addr = address.address
            let descriptor = FetchDescriptor<AddressTransaction>(
                predicate: #Predicate { $0.txid == txid && $0.address == addr }
            )
            if let saved = try? context.fetch(descriptor).first {
                saved.costBasisSource = "manual"
                saved.pricePerBTC = price
                saved.usdValue = tx.btcAmount * price
            }
        }

        showManualEntry = false
        selectedTx = nil
        manualPrice = ""
    }

    private func applyHistoricalCostBasis(_ tx: AddressTransaction) {
        Task {
            if let price = await priceService.historicalPrice(for: tx.date) {
                if let idx = transactions.firstIndex(where: { $0.id == tx.id }) {
                    transactions[idx].costBasisSource = "historical"
                    transactions[idx].pricePerBTC = price
                    transactions[idx].usdValue = transactions[idx].btcAmount * price

                    let txid = tx.txid
                    let addr = address.address
                    let descriptor = FetchDescriptor<AddressTransaction>(
                        predicate: #Predicate { $0.txid == txid && $0.address == addr }
                    )
                    if let saved = try? context.fetch(descriptor).first {
                        saved.costBasisSource = "historical"
                        saved.pricePerBTC = price
                        saved.usdValue = tx.btcAmount * price
                    }
                }
            }

            showManualEntry = false
            selectedTx = nil
            manualPrice = ""
        }
    }

    private func truncateAddress(_ addr: String) -> String {
        guard addr.count > 16 else { return addr }
        return "\(addr.prefix(8))...\(addr.suffix(8))"
    }
}

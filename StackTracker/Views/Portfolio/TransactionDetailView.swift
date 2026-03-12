import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var priceService = PriceService.shared

    @Bindable var purchase: Purchase

    @State private var isEditing = false
    @State private var showDeleteAlert = false

    // Edit state
    @State private var editDate: Date = .now
    @State private var editBTCAmount: String = ""
    @State private var editPricePerBTC: String = ""
    @State private var editWalletName: String = ""
    @State private var editNotes: String = ""
    @State private var editTransactionType: TransactionType = .buy

    private var currentValue: Double {
        purchase.btcAmount * priceService.currentPrice
    }

    private var plUSD: Double {
        guard priceService.currentPrice > 0 else { return 0 }
        return (priceService.currentPrice - purchase.pricePerBTC) * purchase.btcAmount
    }

    private var plPercent: Double {
        guard purchase.pricePerBTC > 0 else { return 0 }
        return (priceService.currentPrice - purchase.pricePerBTC) / purchase.pricePerBTC * 100
    }

    private var isProfit: Bool { plPercent >= 0 }

    private var holdingDays: Int {
        Calendar.current.dateComponents([.day], from: purchase.date, to: Date()).day ?? 0
    }

    private var holdingPeriod: String {
        if holdingDays < 30 {
            return "\(holdingDays) day\(holdingDays == 1 ? "" : "s")"
        } else if holdingDays < 365 {
            let months = holdingDays / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = holdingDays / 365
            let remaining = (holdingDays % 365) / 30
            if remaining > 0 {
                return "\(years)y \(remaining)m"
            }
            return "\(years) year\(years == 1 ? "" : "s")"
        }
    }

    private var isLongTerm: Bool {
        holdingDays >= 365
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isEditing {
                    editForm
                } else {
                    detailContent
                }
            }
            .padding(16)
        }
        .background(Theme.darkBackground)
        .navigationTitle(isEditing ? "Edit Transaction" : "Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveEdits()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.bitcoinOrange)
                } else {
                    Menu {
                        Button {
                            startEditing()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            toggleFlag()
                        } label: {
                            Label(
                                purchase.isFlagged ? "Unflag" : "Flag",
                                systemImage: purchase.isFlagged ? "flag.slash" : "flag.fill"
                            )
                        }

                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.bitcoinOrange)
                    }
                }
            }

            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        withAnimation { isEditing = false }
                    }
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .alert("Delete Transaction?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                context.delete(purchase)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this transaction. This cannot be undone.")
        }
        .task {
            await priceService.fetchCurrentPrice()
        }
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        VStack(spacing: 16) {
            // Type + Flag badge
            HStack(spacing: 8) {
                typeBadge
                if purchase.isFlagged {
                    flagBadge
                }
                Spacer()
                Text(Formatters.formatDate(purchase.date))
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            // Main value card
            VStack(spacing: 8) {
                Text(Formatters.formatBTC(purchase.btcAmount) + " BTC")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundColor(Theme.bitcoinOrange)

                Text(Formatters.formatSats(purchase.btcAmount) + " sats")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)

                if purchase.transactionType == .buy && priceService.currentPrice > 0 {
                    Divider().background(Theme.cardBorder)

                    Text("Current Value")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(Formatters.formatUSD(currentValue))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.bold())
                        Text(Formatters.formatUSD(abs(plUSD)))
                        Text("(\(Formatters.formatPercent(plPercent)))")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(isProfit ? Theme.profitGreen : Theme.lossRed)
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

            // Details grid
            VStack(spacing: 0) {
                detailRow(label: "Price per BTC", value: Formatters.formatUSDCompact(purchase.pricePerBTC))
                Divider().background(Theme.cardBorder)
                detailRow(label: "USD Spent", value: Formatters.formatUSD(purchase.usdSpent))
                Divider().background(Theme.cardBorder)
                detailRow(label: "Wallet / Source", value: purchase.walletName)
                Divider().background(Theme.cardBorder)
                detailRow(label: "Holding Period", value: holdingPeriod)

                if purchase.transactionType == .buy {
                    Divider().background(Theme.cardBorder)
                    HStack {
                        Text("Tax Status")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Text(isLongTerm ? "Long-Term" : "Short-Term")
                                .font(.subheadline.bold())
                                .foregroundColor(isLongTerm ? Theme.profitGreen : Theme.bitcoinOrange)

                            if !isLongTerm {
                                Text("\(365 - holdingDays)d to LT")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.cardBorder.opacity(0.5))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if !isLongTerm {
                        // Progress bar to long-term
                        let progress = Double(holdingDays) / 365.0
                        VStack(spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.cardBorder)
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.bitcoinOrange)
                                        .frame(width: geo.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("Purchased")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .font(.caption2.bold())
                                    .foregroundColor(Theme.bitcoinOrange)
                                Spacer()
                                Text("365 days")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
            }
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )

            // Notes
            if !purchase.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(purchase.notes)
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(purchase.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                HStack {
                    Text("ID")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(purchase.id.uuidString.prefix(8) + "...")
                        .font(.caption.monospaced())
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Edit Form

    private var editForm: some View {
        VStack(spacing: 16) {
            // Transaction Type
            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Type")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Picker("Type", selection: $editTransactionType) {
                    Text("Buy").tag(TransactionType.buy)
                    Text("Sell").tag(TransactionType.sell)
                    Text("Withdrawal").tag(TransactionType.withdrawal)
                    Text("Payment").tag(TransactionType.payment)
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(12)

            // Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Date")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                DatePicker("", selection: $editDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Theme.bitcoinOrange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(12)

            // BTC Amount
            VStack(alignment: .leading, spacing: 8) {
                InputField(
                    label: "BTC Amount",
                    placeholder: "0.005",
                    text: $editBTCAmount,
                    prefix: "\u{20BF}",
                    keyboardType: .decimalPad
                )

                InputField(
                    label: "Price per BTC",
                    placeholder: "66000",
                    text: $editPricePerBTC,
                    prefix: "$",
                    keyboardType: .decimalPad
                )

                if let btc = Double(editBTCAmount), let price = Double(editPricePerBTC), btc > 0, price > 0 {
                    Text("Total: \(Formatters.formatUSD(btc * price))")
                        .font(.caption)
                        .foregroundColor(Theme.bitcoinOrange)
                }
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(12)

            // Wallet
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet / Source")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                TextField("Wallet name", text: $editWalletName)
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(Theme.darkBackground)
                    .cornerRadius(8)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(12)

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                TextField("Optional notes", text: $editNotes)
                    .foregroundColor(Theme.textPrimary)
                    .padding(12)
                    .background(Theme.darkBackground)
                    .cornerRadius(8)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Components

    private var typeBadge: some View {
        let (label, color, icon) = typeInfo(purchase.transactionType)
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption.bold())
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private var flagBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.caption2)
            Text("Flagged")
                .font(.caption.bold())
        }
        .foregroundColor(Theme.bitcoinOrange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.bitcoinOrange.opacity(0.15))
        .cornerRadius(8)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func typeInfo(_ type: TransactionType) -> (String, Color, String) {
        switch type {
        case .buy: return ("Buy", Theme.profitGreen, "arrow.down.circle.fill")
        case .sell: return ("Sell", Theme.lossRed, "arrow.up.circle.fill")
        case .withdrawal: return ("Transfer", Color.blue, "arrow.right.circle.fill")
        case .payment: return ("Payment", Theme.lossRed, "creditcard.fill")
        }
    }

    // MARK: - Actions

    private func startEditing() {
        editDate = purchase.date
        editBTCAmount = String(format: "%.8f", purchase.btcAmount)
        editPricePerBTC = String(format: "%.2f", purchase.pricePerBTC)
        editWalletName = purchase.walletName
        editNotes = purchase.notes
        editTransactionType = purchase.transactionType
        withAnimation { isEditing = true }
    }

    private func saveEdits() {
        guard let btc = Double(editBTCAmount), btc > 0,
              let price = Double(editPricePerBTC), price > 0 else { return }

        purchase.date = editDate
        purchase.btcAmount = btc
        purchase.pricePerBTC = price
        purchase.usdSpent = btc * price
        purchase.walletName = editWalletName.isEmpty ? "Default" : editWalletName
        purchase.notes = editNotes
        purchase.transactionType = editTransactionType

        Haptics.success()

        withAnimation { isEditing = false }
    }

    private func toggleFlag() {
        purchase.isFlagged.toggle()
        Haptics.tap()
    }
}

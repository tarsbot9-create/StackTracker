import SwiftUI
import SwiftData

struct AddPurchaseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var priceService = PriceService.shared

    @State private var date = Date()
    @State private var inputMode: InputMode = .usd
    @State private var usdAmount = ""
    @State private var btcAmount = ""
    @State private var pricePerBTC = ""
    @State private var walletName = "Default"
    @State private var notes = ""
    @State private var showSuccess = false
    @State private var customWallet = ""
    @State private var showCustomWallet = false

    enum InputMode: String, CaseIterable {
        case usd = "USD Spent"
        case btc = "BTC Amount"
    }

    let walletOptions = ["Default", "Cold Storage", "Strike", "Swan", "Coinbase", "Cash App", "Custom"]

    private var computedBTC: Double {
        let price = Double(pricePerBTC) ?? 0
        guard price > 0 else { return 0 }
        if inputMode == .usd {
            return (Double(usdAmount) ?? 0) / price
        } else {
            return Double(btcAmount) ?? 0
        }
    }

    private var computedUSD: Double {
        let price = Double(pricePerBTC) ?? 0
        if inputMode == .btc {
            return (Double(btcAmount) ?? 0) * price
        } else {
            return Double(usdAmount) ?? 0
        }
    }

    private var isValid: Bool {
        let price = Double(pricePerBTC) ?? 0
        guard price > 0 else { return false }
        if inputMode == .usd {
            return (Double(usdAmount) ?? 0) > 0
        } else {
            return (Double(btcAmount) ?? 0) > 0
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Purchase Date")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Theme.bitcoinOrange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.cardBackground)
                    .cornerRadius(12)

                    // Input Mode Toggle
                    Picker("Input Mode", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Amount Input
                    VStack(alignment: .leading, spacing: 12) {
                        if inputMode == .usd {
                            InputField(
                                label: "USD Spent",
                                placeholder: "100.00",
                                text: $usdAmount,
                                prefix: "$",
                                keyboardType: .decimalPad
                            )

                            if computedBTC > 0 {
                                Text("= \(Formatters.formatBTC(computedBTC)) BTC (\(Formatters.formatSats(computedBTC)) sats)")
                                    .font(.caption)
                                    .foregroundColor(Theme.bitcoinOrange)
                            }
                        } else {
                            InputField(
                                label: "BTC Amount",
                                placeholder: "0.005",
                                text: $btcAmount,
                                prefix: "₿",
                                keyboardType: .decimalPad
                            )

                            if computedUSD > 0 {
                                Text("= \(Formatters.formatUSD(computedUSD))")
                                    .font(.caption)
                                    .foregroundColor(Theme.bitcoinOrange)
                            }
                        }

                        InputField(
                            label: "Price per BTC",
                            placeholder: priceService.currentPrice > 0 ? String(format: "%.0f", priceService.currentPrice) : "66000",
                            text: $pricePerBTC,
                            prefix: "$",
                            keyboardType: .decimalPad
                        )

                        if priceService.currentPrice > 0 {
                            Button {
                                pricePerBTC = String(format: "%.2f", priceService.currentPrice)
                            } label: {
                                Label("Use current price: \(Formatters.formatUSDCompact(priceService.currentPrice))", systemImage: "arrow.down.circle")
                                    .font(.caption)
                                    .foregroundColor(Theme.bitcoinOrange)
                            }
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

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(walletOptions, id: \.self) { option in
                                    Button {
                                        if option == "Custom" {
                                            showCustomWallet = true
                                        } else {
                                            walletName = option
                                        }
                                    } label: {
                                        Text(option)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(walletName == option ? Theme.bitcoinOrange : Theme.cardBorder)
                                            .foregroundColor(walletName == option ? .black : Theme.textSecondary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.cardBackground)
                    .cornerRadius(12)

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        TextField("e.g., Weekly DCA", text: $notes)
                            .textFieldStyle(.plain)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(16)
                    .background(Theme.cardBackground)
                    .cornerRadius(12)

                    // Save Button
                    Button {
                        savePurchase()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Purchase")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(isValid ? Theme.bitcoinOrange : Theme.cardBorder)
                        .foregroundColor(isValid ? .black : Theme.textSecondary)
                        .cornerRadius(12)
                    }
                    .disabled(!isValid)
                }
                .padding(16)
            }
            .background(Theme.darkBackground)
            .navigationTitle("Add Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .alert("Custom Wallet", isPresented: $showCustomWallet) {
                TextField("Wallet name", text: $customWallet)
                Button("Save") {
                    if !customWallet.isEmpty {
                        walletName = customWallet
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .overlay {
                if showSuccess {
                    SuccessOverlay()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showSuccess = false }
                            }
                        }
                }
            }
        }
        .task {
            await priceService.fetchCurrentPrice()
            if pricePerBTC.isEmpty && priceService.currentPrice > 0 {
                pricePerBTC = String(format: "%.2f", priceService.currentPrice)
            }
        }
    }

    private func savePurchase() {
        let price = Double(pricePerBTC) ?? 0
        let btc = computedBTC
        guard btc > 0 && price > 0 else { return }

        let purchase = Purchase(
            date: date,
            btcAmount: btc,
            pricePerBTC: price,
            walletName: walletName,
            notes: notes
        )

        context.insert(purchase)

        // Reset form
        usdAmount = ""
        btcAmount = ""
        notes = ""
        date = Date()

        withAnimation { showSuccess = true }
    }
}

struct InputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var prefix: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 6) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .foregroundColor(Theme.textSecondary)
                        .font(.body.bold())
                }
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .foregroundColor(Theme.textPrimary)
                    .font(.body)
            }
            .padding(12)
            .background(Theme.darkBackground)
            .cornerRadius(8)
        }
    }
}

struct SuccessOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(Theme.profitGreen)
            Text("Purchase Added!")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .transition(.scale.combined(with: .opacity))
    }
}

import SwiftUI
import SwiftData

struct SellCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Purchase.date) private var purchases: [Purchase]
    @ObservedObject private var priceService = PriceService.shared

    @State private var btcInput: String = ""
    @State private var priceInput: String = ""
    @State private var method: AccountingMethod = .fifo
    @State private var useCurrentPrice: Bool = true
    @State private var result: SellSimulationResult?
    @State private var showLotBreakdown: Bool = false

    private var availableBTC: Double {
        let buys = purchases.filter { $0.transactionType == .buy }.reduce(0.0) { $0 + $1.btcAmount }
        let sold = purchases.filter { $0.transactionType == .sell || $0.transactionType == .payment }.reduce(0.0) { $0 + $1.btcAmount }
        return max(0, buys - sold)
    }

    private var sellPrice: Double {
        if useCurrentPrice {
            return priceService.currentPrice
        }
        return Double(priceInput.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var btcAmount: Double {
        Double(btcInput) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Available BTC
                    availableCard

                    // Input Section
                    inputSection

                    // Simulate Button
                    simulateButton

                    // Results
                    if let result = result {
                        resultsCard(result)

                        if showLotBreakdown && !result.matches.isEmpty {
                            lotBreakdownSection(result)
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.darkBackground)
            .navigationTitle("Sell Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .foregroundColor(Theme.bitcoinOrange)
                        .font(.body.bold())
                    }
                }
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

    // MARK: - Available BTC Card

    private var availableCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Available to Sell")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text("\(Formatters.formatBTC(availableBTC)) BTC")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(Theme.bitcoinOrange)
            }

            Spacer()

            if priceService.currentPrice > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Price")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(Formatters.formatUSD(priceService.currentPrice))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
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

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 14) {
            // BTC Amount
            VStack(alignment: .leading, spacing: 6) {
                Text("BTC to Sell")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                HStack {
                    TextField("0.00000000", text: $btcInput)
                        .keyboardType(.decimalPad)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)

                    // Quick-fill buttons
                    Button("25%") { btcInput = String(format: "%.8f", availableBTC * 0.25) }
                        .quickFillStyle()
                    Button("50%") { btcInput = String(format: "%.8f", availableBTC * 0.50) }
                        .quickFillStyle()
                    Button("All") { btcInput = String(format: "%.8f", availableBTC) }
                        .quickFillStyle()
                }
                .padding(12)
                .background(Theme.darkBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            }

            // Price
            VStack(alignment: .leading, spacing: 6) {
                Text("Sell Price (USD)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Toggle("Use current market price", isOn: $useCurrentPrice)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .tint(Theme.bitcoinOrange)

                if !useCurrentPrice {
                    HStack {
                        Text("$")
                            .foregroundColor(Theme.textSecondary)
                        TextField("0.00", text: $priceInput)
                            .keyboardType(.decimalPad)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(12)
                    .background(Theme.darkBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                }
            }

            // Accounting Method
            VStack(alignment: .leading, spacing: 6) {
                Text("Accounting Method")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Picker("Method", selection: $method) {
                    ForEach(AccountingMethod.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
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

    // MARK: - Simulate Button

    private var simulateButton: some View {
        Button {
            runSimulation()
        } label: {
            Text("Calculate Tax Impact")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    (btcAmount > 0 && sellPrice > 0)
                    ? Theme.bitcoinOrange
                    : Theme.bitcoinOrange.opacity(0.3)
                )
                .cornerRadius(12)
        }
        .disabled(btcAmount <= 0 || sellPrice <= 0)
    }

    // MARK: - Results Card

    private func resultsCard(_ sim: SellSimulationResult) -> some View {
        VStack(spacing: 16) {
            // Warning if insufficient
            if sim.insufficientBTC {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("You only have \(Formatters.formatBTC(sim.btcToSell)) BTC available. Showing results for that amount.")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }

            // Main result
            VStack(spacing: 4) {
                Text("If You Sell \(Formatters.formatBTC(sim.btcToSell)) BTC")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(Formatters.formatUSD(sim.totalGain))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(sim.totalGain >= 0 ? Theme.profitGreen : Theme.lossRed)
                Text(sim.totalGain >= 0 ? "capital gain" : "capital loss")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Divider().background(Theme.cardBorder)

            // Breakdown
            VStack(spacing: 10) {
                resultRow("Proceeds", Formatters.formatUSD(sim.proceeds), Theme.textPrimary)
                resultRow("Cost Basis", Formatters.formatUSD(sim.costBasis), Theme.textPrimary)

                Divider().background(Theme.cardBorder)

                resultRow("Short-Term Gain", Formatters.formatUSD(sim.shortTermGain),
                          sim.shortTermGain >= 0 ? Theme.profitGreen : Theme.lossRed)
                resultRow("Long-Term Gain", Formatters.formatUSD(sim.longTermGain),
                          sim.longTermGain >= 0 ? Theme.profitGreen : Theme.lossRed)

                Divider().background(Theme.cardBorder)

                resultRow("Net After Sale",
                          Formatters.formatUSD(sim.proceeds),
                          Theme.bitcoinOrange)
            }

            // Toggle lot breakdown
            Button {
                withAnimation { showLotBreakdown.toggle() }
            } label: {
                HStack {
                    Text(showLotBreakdown ? "Hide Lot Breakdown" : "Show Lot Breakdown")
                        .font(.caption)
                    Image(systemName: showLotBreakdown ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(Theme.bitcoinOrange)
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

    private func resultRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundColor(color)
        }
    }

    // MARK: - Lot Breakdown

    private func lotBreakdownSection(_ sim: SellSimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lots Consumed (\(method.rawValue))")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 4)

            ForEach(sim.matches) { match in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatters.formatDate(match.lotDate))
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                        Text("\(Formatters.formatBTC(match.btcAmount)) BTC @ \(Formatters.formatUSD(match.lotPricePerBTC))")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Formatters.formatUSD(match.gain))
                            .font(.subheadline.bold())
                            .foregroundColor(match.gain >= 0 ? Theme.profitGreen : Theme.lossRed)
                        Text(match.isLongTerm ? "LT \(match.holdingDays)d" : "ST \(match.holdingDays)d")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
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
        }
    }

    // MARK: - Actions

    private func runSimulation() {
        result = TaxLotEngine.simulateSell(
            btcAmount: btcAmount,
            atPrice: sellPrice,
            purchases: purchases,
            method: method
        )
    }
}

// MARK: - Quick Fill Button Style

extension View {
    func quickFillStyle() -> some View {
        self
            .font(.caption.bold())
            .foregroundColor(Theme.bitcoinOrange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.bitcoinOrange.opacity(0.15))
            .cornerRadius(6)
    }
}

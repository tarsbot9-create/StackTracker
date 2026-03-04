import SwiftUI
import SwiftData

struct AddAddressView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var blockchain = BlockchainService()

    @State private var addressInput = ""
    @State private var label = "Cold Storage"
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var addressInfo: MempoolAddressInfo?

    private let labelOptions = ["Cold Storage", "Hardware Wallet", "Paper Wallet", "Multisig", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Address Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bitcoin Address")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        TextField("bc1q... or 1... or 3...", text: $addressInput)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Theme.cardBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(validationError != nil ? Theme.lossRed : Theme.cardBorder, lineWidth: 1)
                            )

                        if let error = validationError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Theme.lossRed)
                        }
                    }

                    // Label Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Label")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(labelOptions, id: \.self) { option in
                                    Button {
                                        label = option
                                    } label: {
                                        Text(option)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(label == option ? Theme.bitcoinOrange : Theme.cardBackground)
                                            .foregroundColor(label == option ? .white : Theme.textPrimary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }

                    // Validate Button
                    Button {
                        Task { await validateAndPreview() }
                    } label: {
                        HStack {
                            if isValidating {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isValidating ? "Checking..." : "Look Up Address")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(addressInput.count > 20 ? Theme.bitcoinOrange : Theme.cardBackground)
                        .cornerRadius(12)
                    }
                    .disabled(addressInput.count < 20 || isValidating)

                    // Preview Card
                    if let info = addressInfo {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Address Found")
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                            }

                            Divider().background(Theme.cardBorder)

                            HStack {
                                Text("Balance")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Formatters.formatBTC(info.confirmedBalanceBTC)) BTC")
                                    .font(.system(.body, design: .monospaced, weight: .semibold))
                                    .foregroundColor(Theme.bitcoinOrange)
                            }

                            HStack {
                                Text("Transactions")
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(info.chain_stats.funded_txo_count) received")
                                    .foregroundColor(Theme.textPrimary)
                            }

                            if info.unconfirmedBalanceSats != 0 {
                                HStack {
                                    Text("Pending")
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(Formatters.formatBTC(Double(info.unconfirmedBalanceSats) / 100_000_000.0)) BTC")
                                        .foregroundColor(.yellow)
                                }
                            }

                            Button {
                                Task { await addAddress(balance: info.confirmedBalanceBTC) }
                            } label: {
                                Text("Add to Stack")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.bitcoinOrange)
                                    .cornerRadius(12)
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

                    // Info footer
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.title2)
                            .foregroundColor(Theme.textSecondary)
                        Text("Read-only. Your private keys are never needed.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("Data from mempool.space")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
                .padding()
            }
            .background(Theme.darkBackground)
            .navigationTitle("Add Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func validateAndPreview() async {
        let trimmed = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        validationError = nil
        addressInfo = nil

        guard BlockchainService.isValidBitcoinAddress(trimmed) else {
            validationError = "Invalid Bitcoin address format."
            return
        }

        isValidating = true
        defer { isValidating = false }

        do {
            let info = try await blockchain.fetchAddressInfo(trimmed)
            addressInfo = info
        } catch {
            validationError = error.localizedDescription
        }
    }

    private func addAddress(balance: Double) async {
        let trimmed = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let watched = WatchedAddress(address: trimmed, label: label)
        watched.cachedBalance = balance
        watched.lastSyncedAt = .now
        context.insert(watched)
        dismiss()
    }
}

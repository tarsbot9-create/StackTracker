import SwiftUI
import SwiftData

struct AddressListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchedAddress.addedAt) private var addresses: [WatchedAddress]
    @ObservedObject private var priceService = PriceService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @State private var showAddSheet = false
    @State private var showPaywall = false
    @State private var showDeleteAlert = false
    @State private var addressToDelete: WatchedAddress?

    var totalColdBalance: Double {
        addresses.reduce(0) { $0 + $1.cachedBalance }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if subscriptionService.isPro {
                    VStack(spacing: 16) {
                        if !addresses.isEmpty {
                            // Total cold storage card
                            VStack(spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.bitcoinOrange)

                                Text("Cold Storage Total")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)

                                Text("\(Formatters.formatBTC(totalColdBalance)) BTC")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundColor(Theme.bitcoinOrange)

                                Text(Formatters.formatSats(totalColdBalance) + " sats")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)

                                if priceService.currentPrice > 0 {
                                    Text(Formatters.formatUSD(totalColdBalance * priceService.currentPrice))
                                        .font(.headline)
                                        .foregroundColor(Theme.textPrimary)
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

                            // Address cards
                            ForEach(addresses) { addr in
                                NavigationLink(destination: AddressDetailView(address: addr)) {
                                    addressCard(addr)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 50))
                                    .foregroundColor(Theme.bitcoinOrange.opacity(0.5))

                                Text("Track Cold Storage")
                                    .font(.title3.bold())
                                    .foregroundColor(Theme.textPrimary)

                                Text("Add a Bitcoin address to track your cold storage balance alongside your exchange purchases. Read-only -- no private keys needed.")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Theme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                        }

                        // Add button
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("Add Address", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.bitcoinOrange)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                } else {
                    // Locked state for free users
                    VStack(spacing: 20) {
                        Spacer()
                            .frame(height: 60)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.bitcoinOrange)

                        Text("Cold Storage Tracking")
                            .font(.title3.bold())
                            .foregroundColor(Theme.textPrimary)

                        Text("Monitor your Bitcoin addresses and track cold storage balances with StackTracker Pro.")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            showPaywall = true
                        } label: {
                            Text("Unlock Pro")
                                .fontWeight(.bold)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Theme.bitcoinOrange)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .background(Theme.darkBackground)
            .navigationTitle("Addresses")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showAddSheet) {
                AddAddressView()
            }
            .alert("Remove Address?", isPresented: $showDeleteAlert) {
                Button("Remove", role: .destructive) {
                    if let addr = addressToDelete {
                        // Delete associated transactions
                        let address = addr.address
                        let descriptor = FetchDescriptor<AddressTransaction>(
                            predicate: #Predicate { $0.address == address }
                        )
                        if let txs = try? context.fetch(descriptor) {
                            for tx in txs { context.delete(tx) }
                        }
                        context.delete(addr)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the address and its transaction history from the app.")
            }
        }
        .task {
            await priceService.fetchCurrentPrice()
        }
    }

    private func addressCard(_ addr: WatchedAddress) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.circle.fill")
                .font(.title2)
                .foregroundColor(Theme.bitcoinOrange)

            VStack(alignment: .leading, spacing: 4) {
                Text(addr.label)
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.textPrimary)

                Text(truncateAddress(addr.address))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Formatters.formatBTC(addr.cachedBalance)) BTC")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundColor(Theme.bitcoinOrange)

                if priceService.currentPrice > 0 {
                    Text(Formatters.formatUSD(addr.cachedBalance * priceService.currentPrice))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                addressToDelete = addr
                showDeleteAlert = true
            } label: {
                Label("Remove Address", systemImage: "trash")
            }
        }
    }

    private func truncateAddress(_ addr: String) -> String {
        guard addr.count > 16 else { return addr }
        return "\(addr.prefix(8))...\(addr.suffix(8))"
    }
}

import SwiftUI

struct PriceAlertsView: View {
    @ObservedObject private var notificationService = NotificationService.shared
    @ObservedObject private var priceService = PriceService.shared

    @State private var showAddAlert = false
    @State private var newPrice: String = ""
    @State private var newDirection: NotificationService.PriceAlert.Direction = .above

    var body: some View {
        List {
            // Current price context
            Section {
                HStack {
                    Text("Current BTC Price")
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(Formatters.formatUSD(priceService.currentPrice))
                        .font(.headline)
                        .foregroundColor(Theme.bitcoinOrange)
                }
                .listRowBackground(Theme.cardBackground)
            }

            // Active alerts
            Section("Active Alerts") {
                let activeAlerts = notificationService.priceAlerts.filter { !$0.isTriggered }
                if activeAlerts.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "bell.slash")
                                .font(.title2)
                                .foregroundColor(Theme.textSecondary.opacity(0.5))
                            Text("No active alerts")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Theme.cardBackground)
                } else {
                    ForEach(activeAlerts) { alert in
                        alertRow(alert)
                    }
                    .onDelete { indexSet in
                        let active = notificationService.priceAlerts.filter { !$0.isTriggered }
                        for index in indexSet {
                            notificationService.removePriceAlert(active[index])
                        }
                    }
                }
            }

            // Triggered alerts
            let triggered = notificationService.priceAlerts.filter { $0.isTriggered }
            if !triggered.isEmpty {
                Section("Triggered") {
                    ForEach(triggered) { alert in
                        alertRow(alert)
                            .opacity(0.6)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            notificationService.removePriceAlert(triggered[index])
                        }
                    }
                }
            }

            // Notification permission
            if !notificationService.isAuthorized {
                Section {
                    Button {
                        Task {
                            await notificationService.requestAuthorization()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(Theme.bitcoinOrange)
                            Text("Enable Notifications")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .listRowBackground(Theme.cardBackground)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.darkBackground)
        .navigationTitle("Price Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Pre-fill with a round number near current price
                    let rounded = (priceService.currentPrice / 5000).rounded() * 5000
                    newPrice = String(Int(rounded + 5000))
                    newDirection = .above
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Theme.bitcoinOrange)
                }
            }
        }
        .alert("New Price Alert", isPresented: $showAddAlert) {
            TextField("Price (USD)", text: $newPrice)
                .keyboardType(.numberPad)

            Button("Above") {
                addAlert(direction: .above)
            }
            Button("Below") {
                addAlert(direction: .below)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Get notified when BTC crosses this price. Current: \(Formatters.formatUSD(priceService.currentPrice))")
        }
        .task {
            await notificationService.checkAuthorizationStatus()
        }
    }

    private func alertRow(_ alert: NotificationService.PriceAlert) -> some View {
        HStack(spacing: 12) {
            Image(systemName: alert.direction == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundColor(alert.direction == .above ? Theme.profitGreen : Theme.lossRed)

            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.formatUSD(alert.targetPrice))
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Text(alert.direction == .above ? "Crosses above" : "Drops below")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            if alert.isTriggered {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.profitGreen)
            }
        }
        .listRowBackground(Theme.cardBackground)
    }

    private func addAlert(direction: NotificationService.PriceAlert.Direction) {
        guard let price = Double(newPrice.replacingOccurrences(of: ",", with: "")),
              price > 0 else { return }

        Task {
            // Ensure notification permission
            if !notificationService.isAuthorized {
                _ = await notificationService.requestAuthorization()
            }
            notificationService.addPriceAlert(targetPrice: price, direction: direction)
        }
        newPrice = ""
    }
}

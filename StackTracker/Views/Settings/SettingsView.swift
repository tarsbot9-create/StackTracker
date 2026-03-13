import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date) private var purchases: [Purchase]
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @AppStorage("denomination") private var denomination = "BTC"
    @AppStorage("currency") private var currency = "USD"
    @AppStorage("appearanceMode") private var appearanceMode = "dark"

    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showDeleteAlert = false
    @State private var showPaywall = false
    @State private var csvURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                        Text("StackTracker")
                            .font(.title3.bold())
                        Text("Track your Bitcoin savings journey.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("Your data never leaves your device.")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("Auto").tag("auto")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appearanceMode) { _, _ in
                        Haptics.select()
                    }
                }

                Section("Display") {
                    Picker("Denomination", selection: $denomination) {
                        Text("BTC").tag("BTC")
                        Text("Sats").tag("Sats")
                    }

                    Picker("Currency", selection: $currency) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                        Text("CAD").tag("CAD")
                        Text("AUD").tag("AUD")
                    }
                }

                Section("Notifications") {
                    NavigationLink {
                        PriceAlertsView()
                    } label: {
                        HStack {
                            Label("Price Alerts", systemImage: "bell.badge")
                            Spacer()
                            let activeCount = NotificationService.shared.priceAlerts.filter { !$0.isTriggered }.count
                            if activeCount > 0 {
                                Text("\(activeCount)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }

                Section("Data") {
                    Button {
                        if subscriptionService.isPro {
                            showImportSheet = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Import from CSV", systemImage: "square.and.arrow.down")
                            if !subscriptionService.isPro {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                    Button {
                        if subscriptionService.isPro {
                            exportCSV()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Export to CSV", systemImage: "square.and.arrow.up")
                            if !subscriptionService.isPro {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                }

                Section("Subscription") {
                    if subscriptionService.isPro {
                        HStack {
                            Label("StackTracker Pro", systemImage: "checkmark.seal.fill")
                                .foregroundColor(Theme.bitcoinOrange)
                            Spacer()
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(Theme.profitGreen)
                        }

                        Button {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Manage Subscription", systemImage: "creditcard")
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Upgrade to Pro", systemImage: "star.fill")
                                    .foregroundColor(Theme.bitcoinOrange)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(Theme.textSecondary)
                    }

                    HStack {
                        Text("Purchases")
                        Spacer()
                        Text("\(purchases.count)")
                            .foregroundColor(Theme.textSecondary)
                    }

                    Link(destination: URL(string: "https://tarsbot9-create.github.io/stacktracker-site/")!) {
                        Label("Website", systemImage: "globe")
                    }

                    Link(destination: URL(string: "https://twitter.com/CreditToBitcoin")!) {
                        Label("Follow on X", systemImage: "person.circle")
                    }
                }

                Section("Legal") {
                    Link(destination: URL(string: "https://tarsbot9-create.github.io/stacktracker-site/privacy.html")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .background(Theme.darkBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete All Data?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your purchase history. This cannot be undone.")
            }
            .sheet(isPresented: $showImportSheet) {
                CSVImportView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportCSV() {
        var csv = "Date,Type,BTC Amount,Sats,Price Per BTC,USD Spent,Wallet,Notes,Flagged\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for purchase in purchases {
            let line = [
                dateFormatter.string(from: purchase.date),
                purchase.transactionType.rawValue,
                String(purchase.btcAmount),
                String(purchase.satsAmount),
                String(format: "%.2f", purchase.pricePerBTC),
                String(format: "%.2f", purchase.usdSpent),
                purchase.walletName.replacingOccurrences(of: ",", with: ";"),
                purchase.notes.replacingOccurrences(of: ",", with: ";"),
                purchase.isFlagged ? "yes" : ""
            ].joined(separator: ",")
            csv += line + "\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("stacktracker-export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        csvURL = tempURL
        showExportSheet = true
        Haptics.success()
    }

    private func deleteAllData() {
        Haptics.heavy()
        for purchase in purchases {
            context.delete(purchase)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

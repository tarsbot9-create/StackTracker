import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date) private var purchases: [Purchase]

    @AppStorage("denomination") private var denomination = "BTC"
    @AppStorage("currency") private var currency = "USD"
    @AppStorage("appearanceMode") private var appearanceMode = "dark"

    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showDeleteAlert = false
    @State private var csvURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("Auto").tag("auto")
                    }
                    .pickerStyle(.segmented)
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

                Section("Data") {
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import from CSV", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        exportCSV()
                    } label: {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
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

                    Link(destination: URL(string: "https://stacktracker.app")!) {
                        Label("Website", systemImage: "globe")
                    }

                    Link(destination: URL(string: "https://twitter.com/CreditToBitcoin")!) {
                        Label("Follow on X", systemImage: "person.circle")
                    }
                }

                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(Theme.bitcoinOrange)
                        Text("StackTracker")
                            .font(.headline)
                        Text("Track your Bitcoin savings journey.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("Your data never leaves your device.")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
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
            .sheet(isPresented: $showExportSheet) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportCSV() {
        var csv = "Date,BTC Amount,Sats,Price Per BTC,USD Spent,Wallet,Notes\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for purchase in purchases {
            let line = [
                dateFormatter.string(from: purchase.date),
                String(purchase.btcAmount),
                String(purchase.satsAmount),
                String(format: "%.2f", purchase.pricePerBTC),
                String(format: "%.2f", purchase.usdSpent),
                purchase.walletName,
                purchase.notes.replacingOccurrences(of: ",", with: ";")
            ].joined(separator: ",")
            csv += line + "\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("stacktracker-export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        csvURL = tempURL
        showExportSheet = true
    }

    private func deleteAllData() {
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

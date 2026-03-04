import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

// MARK: - Document Picker (copies file into app sandbox)

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText, .plainText], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct CSVImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Purchase.date) private var existingPurchases: [Purchase]

    @State private var importResult: CSVImportResult?
    @State private var parsedPurchases: [ParsedPurchase] = []
    @State private var showFilePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isImporting = false
    @State private var importComplete = false
    @State private var importedCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if let result = importResult {
                    previewView(result)
                } else {
                    emptyState
                }
            }
            .background(Theme.darkBackground)
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if importResult != nil && !importComplete {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") { performImport() }
                            .bold()
                            .disabled(selectedCount == 0)
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    handlePickedFile(url)
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.bitcoinOrange)

            Text("Import Purchase History")
                .font(.title2.bold())
                .foregroundColor(Theme.textPrimary)

            Text("Import your BTC purchases from CSV files exported by your exchange or wallet.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                supportedPlatformRow("Coinbase")
                supportedPlatformRow("Cash App")
                supportedPlatformRow("Strike")
                supportedPlatformRow("Swan")
                supportedPlatformRow("River")
                supportedPlatformRow("Generic CSV")
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)

            Button {
                showFilePicker = true
            } label: {
                Label("Choose CSV File", systemImage: "folder.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.bitcoinOrange)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func supportedPlatformRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(name)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
        }
    }

    // MARK: - Preview View

    private func previewView(_ result: CSVImportResult) -> some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 8) {
                if importComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("\(importedCount) purchases imported!")
                        .font(.title3.bold())
                        .foregroundColor(Theme.textPrimary)
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Theme.bitcoinOrange)
                        .cornerRadius(10)
                        .padding(.top, 8)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Detected: \(result.platform.rawValue)")
                                .font(.headline)
                                .foregroundColor(Theme.bitcoinOrange)
                            let buyCount = parsedPurchases.filter { $0.transactionType == .buy }.count
                            let sellCount = parsedPurchases.filter { $0.transactionType == .sell || $0.transactionType == .payment }.count
                            let xferCount = parsedPurchases.filter { $0.transactionType == .withdrawal }.count
                            Text("\(buyCount) buys\(sellCount > 0 ? ", \(sellCount) sells" : "")\(xferCount > 0 ? ", \(xferCount) transfers" : "")")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(selectedCount) selected")
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.textPrimary)
                            if duplicateCount > 0 {
                                Text("\(duplicateCount) duplicates")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }

                    if result.skippedRows > 0 {
                        Text("\(result.skippedRows) non-BTC rows skipped")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Select/Deselect all
                    HStack {
                        Button("Select All") { toggleAll(true) }
                            .font(.caption.bold())
                            .foregroundColor(Theme.bitcoinOrange)
                        Spacer()
                        Button("Deselect All") { toggleAll(false) }
                            .font(.caption.bold())
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)

            if !importComplete {
                // Purchase list
                List {
                    ForEach(Array(parsedPurchases.enumerated()), id: \.element.id) { index, purchase in
                        purchaseRow(purchase, index: index)
                            .listRowBackground(Theme.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func purchaseRow(_ purchase: ParsedPurchase, index: Int) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                parsedPurchases[index].isSelected.toggle()
            } label: {
                Image(systemName: purchase.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(purchase.isSelected ? Theme.bitcoinOrange : Theme.textSecondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(purchase.date, style: .date)
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)

                    // Transaction type badge
                    if purchase.transactionType == .sell {
                        Text("SELL")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.lossRed)
                            .cornerRadius(4)
                    } else if purchase.transactionType == .withdrawal {
                        Text("TRANSFER")
                            .font(.caption2.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue)
                            .cornerRadius(4)
                    } else if purchase.transactionType == .payment {
                        Text("SPENT")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.purple)
                            .cornerRadius(4)
                    }

                    if purchase.isDuplicate {
                        Text("DUPLICATE")
                            .font(.caption2.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.yellow)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 16) {
                    let prefix = purchase.transactionType == .buy ? "+" : "-"
                    Text("\(prefix)\(purchase.btcAmount, specifier: "%.8f") BTC")
                        .font(.caption)
                        .foregroundColor(purchase.transactionType == .buy ? Theme.bitcoinOrange : Theme.lossRed)

                    if purchase.usdSpent > 0 {
                        Text("$\(purchase.usdSpent, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                if purchase.pricePerBTC > 0 {
                    Text("@ $\(purchase.pricePerBTC, specifier: "%.0f") per BTC")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(purchase.isSelected ? 1.0 : 0.5)
    }

    // MARK: - Computed

    private var selectedCount: Int {
        parsedPurchases.filter(\.isSelected).count
    }

    private var duplicateCount: Int {
        parsedPurchases.filter(\.isDuplicate).count
    }

    // MARK: - Actions

    private func toggleAll(_ selected: Bool) {
        for i in parsedPurchases.indices {
            parsedPurchases[i].isSelected = selected
        }
    }

    private func handlePickedFile(_ url: URL) {
        // asCopy: true means the file is already copied into our tmp directory -- full access
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Could not read the file."
            showError = true
            return
        }

        guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii)
                ?? String(data: data, encoding: .isoLatin1),
              !content.isEmpty else {
            errorMessage = "File appears to be empty or unreadable."
            showError = true
            return
        }

        do {
            let dupInfos = existingPurchases.map {
                DuplicateInfo(date: $0.date, btcAmount: $0.btcAmount, usdSpent: $0.usdSpent)
            }
            let parsed = try CSVImportService.parseCSVContent(content, existingPurchases: dupInfos)
            if parsed.purchases.isEmpty {
                errorMessage = "No valid BTC purchases found in this file."
                showError = true
            } else {
                importResult = parsed
                parsedPurchases = parsed.purchases
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performImport() {
        let selected = parsedPurchases.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        isImporting = true

        for p in selected {
            let purchase = Purchase(
                date: p.date,
                btcAmount: p.btcAmount,
                pricePerBTC: p.pricePerBTC,
                walletName: p.walletName,
                notes: p.notes,
                transactionType: p.transactionType
            )
            context.insert(purchase)
        }

        importedCount = selected.count
        importComplete = true
        isImporting = false
    }
}

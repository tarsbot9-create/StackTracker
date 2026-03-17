import SwiftUI

struct ColumnMapperView: View {
    let headers: [String]
    let previewRows: [[String]] // First 3 data rows for preview
    let onMap: (ColumnMapping) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var dateColumn: Int? = nil
    @State private var btcAmountColumn: Int? = nil
    @State private var priceColumn: Int? = nil
    @State private var usdSpentColumn: Int? = nil
    @State private var typeColumn: Int? = nil

    private var canImport: Bool {
        dateColumn != nil && btcAmountColumn != nil && (priceColumn != nil || usdSpentColumn != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header explanation
                    VStack(spacing: 8) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.bitcoinOrange)

                        Text("Map Your Columns")
                            .font(.title3.bold())
                            .foregroundColor(Theme.textPrimary)

                        Text("We couldn't auto-detect this CSV format. Select which columns contain your transaction data.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // CSV Preview
                    csvPreview

                    // Column Pickers
                    VStack(spacing: 0) {
                        columnPicker(title: "Date", subtitle: "Required", icon: "calendar", selection: $dateColumn)
                        Divider().background(Theme.cardBorder)
                        columnPicker(title: "BTC Amount", subtitle: "Required", icon: "bitcoinsign.circle", selection: $btcAmountColumn)
                        Divider().background(Theme.cardBorder)
                        columnPicker(title: "Price per BTC", subtitle: "Required if no USD", icon: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90", selection: $priceColumn)
                        Divider().background(Theme.cardBorder)
                        columnPicker(title: "USD Spent", subtitle: "Required if no Price", icon: "dollarsign.circle", selection: $usdSpentColumn)
                        Divider().background(Theme.cardBorder)
                        columnPicker(title: "Transaction Type", subtitle: "Optional (buy/sell)", icon: "arrow.left.arrow.right", selection: $typeColumn)
                    }
                    .background(Theme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Import button
                    Button {
                        Haptics.tap()
                        let mapping = ColumnMapping(
                            dateColumn: dateColumn,
                            btcAmountColumn: btcAmountColumn,
                            priceColumn: priceColumn,
                            usdSpentColumn: usdSpentColumn,
                            typeColumn: typeColumn
                        )
                        onMap(mapping)
                    } label: {
                        Text("Parse CSV")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canImport ? Theme.bitcoinOrange : Theme.bitcoinOrange.opacity(0.3))
                            .cornerRadius(12)
                    }
                    .disabled(!canImport)
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
            }
            .background(Theme.darkBackground)
            .navigationTitle("Column Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - CSV Preview

    private var csvPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption.bold())
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        ForEach(Array(headers.enumerated()), id: \.offset) { i, header in
                            Text(header.capitalized)
                                .font(.caption2.bold())
                                .foregroundColor(Theme.bitcoinOrange)
                                .frame(minWidth: 90, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Theme.bitcoinOrange.opacity(0.1))
                        }
                    }

                    // Data rows
                    ForEach(Array(previewRows.prefix(3).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { i, value in
                                Text(value.prefix(15) + (value.count > 15 ? "..." : ""))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(minWidth: 90, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                        }
                        Divider().background(Theme.cardBorder)
                    }
                }
            }
            .background(Theme.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Column Picker

    private func columnPicker(title: String, subtitle: String, icon: String, selection: Binding<Int?>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Theme.bitcoinOrange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Menu {
                Button("None") {
                    selection.wrappedValue = nil
                }
                ForEach(Array(headers.enumerated()), id: \.offset) { i, header in
                    Button(header.capitalized) {
                        selection.wrappedValue = i
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let col = selection.wrappedValue, col < headers.count {
                        Text(headers[col].capitalized)
                            .font(.subheadline)
                            .foregroundColor(Theme.bitcoinOrange)
                    } else {
                        Text("Select")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

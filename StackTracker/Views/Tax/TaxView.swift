import SwiftUI
import SwiftData

struct TaxView: View {
    @Query(sort: \Purchase.date) private var purchases: [Purchase]
    @ObservedObject private var priceService = PriceService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared

    @State private var method: AccountingMethod = .fifo
    @State private var selectedYear: Int? = nil
    @State private var showPaywall = false
    @State private var showSellCalculator = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    private var disposals: [DisposalResult] {
        TaxLotEngine.computeDisposals(purchases: purchases, method: method)
    }

    private var yearSummaries: [TaxYearSummary] {
        TaxLotEngine.yearSummaries(from: disposals)
    }

    private var filteredDisposals: [DisposalResult] {
        guard let year = selectedYear else { return disposals }
        let calendar = Calendar.current
        return disposals.filter {
            calendar.component(.year, from: $0.disposal.date) == year
        }
    }

    private var currentYearSummary: TaxYearSummary? {
        if let year = selectedYear {
            return yearSummaries.first { $0.year == year }
        }
        // "All" selected: aggregate all years
        guard !yearSummaries.isEmpty else { return nil }
        return TaxYearSummary(
            year: 0,
            shortTermGain: yearSummaries.reduce(0) { $0 + $1.shortTermGain },
            shortTermLoss: yearSummaries.reduce(0) { $0 + $1.shortTermLoss },
            longTermGain: yearSummaries.reduce(0) { $0 + $1.longTermGain },
            longTermLoss: yearSummaries.reduce(0) { $0 + $1.longTermLoss },
            disposalCount: yearSummaries.reduce(0) { $0 + $1.disposalCount }
        )
    }

    private var availableYears: [Int] {
        yearSummaries.map(\.year).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptionService.isPro {
                    taxContent
                } else {
                    lockedState
                }
            }
            .background(Theme.darkBackground)
            .navigationTitle("Taxes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if subscriptionService.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showSellCalculator = true
                            } label: {
                                Label("Sell Calculator", systemImage: "plusminus.circle")
                            }

                            if !disposals.isEmpty {
                                Button {
                                    exportForm8949()
                                } label: {
                                    Label("Export Form 8949 CSV", systemImage: "square.and.arrow.up")
                                }

                                Button {
                                    exportSummary()
                                } label: {
                                    Label("Export Summary CSV", systemImage: "doc.text")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(Theme.bitcoinOrange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showSellCalculator) {
                SellCalculatorView()
            }
            .onChange(of: showExportSheet) { _, show in
                if show, let url = exportURL {
                    presentShareSheet(url: url)
                    showExportSheet = false
                }
            }
        }
        .task {
            await priceService.fetchCurrentPrice()
        }
        .refreshable {
            Haptics.tap()
            await priceService.fetchCurrentPrice()
        }
    }

    // MARK: - Locked State

    private var lockedState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Theme.bitcoinOrange.opacity(0.5))

            Text("Tax Center")
                .font(.title3.bold())
                .foregroundColor(Theme.textPrimary)

            Text("Track capital gains, choose your accounting method, and simulate sells with StackTracker Pro.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                    Text("Unlock Pro")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.bitcoinOrange)
                .foregroundColor(.black)
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tax Content

    private var taxContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Method Picker
                methodPicker

                // Year Filter
                if !availableYears.isEmpty {
                    yearPicker
                }

                // Summary Card
                if let summary = currentYearSummary {
                    summaryCard(summary)
                } else if disposals.isEmpty {
                    emptyState
                } else {
                    noDisposalsForYear
                }

                // Sell Calculator Button
                sellCalculatorButton

                // Disposals List
                if !filteredDisposals.isEmpty {
                    disposalsList
                }
            }
            .padding(16)
        }
    }

    // MARK: - Method Picker

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accounting Method")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Picker("Method", selection: $method) {
                ForEach(AccountingMethod.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: method) { _, _ in
                Haptics.select()
            }
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                yearChip(label: "All", year: nil)
                ForEach(availableYears, id: \.self) { year in
                    yearChip(label: String(year), year: year)
                }
            }
        }
    }

    private func yearChip(label: String, year: Int?) -> some View {
        let isSelected = selectedYear == year
        return Button {
            Haptics.select()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedYear = year
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.bitcoinOrange : Theme.cardBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Summary Card

    private func summaryCard(_ summary: TaxYearSummary) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(Theme.bitcoinOrange)
                Text(selectedYear != nil ? String(summary.year) + " Tax Summary" : "All-Time Tax Summary")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(summary.disposalCount) disposal\(summary.disposalCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Divider().background(Theme.cardBorder)

            // Net Total
            VStack(spacing: 4) {
                Text("Net Capital Gain/Loss")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(Formatters.formatUSD(summary.netTotal))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(summary.netTotal >= 0 ? Theme.profitGreen : Theme.lossRed)
            }

            Divider().background(Theme.cardBorder)

            // Short-term breakdown
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Short-Term")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    if summary.shortTermGain > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                            Text(Formatters.formatUSD(summary.shortTermGain))
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.profitGreen)
                    }

                    if summary.shortTermLoss < 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.right")
                                .font(.caption2)
                            Text(Formatters.formatUSD(summary.shortTermLoss))
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.lossRed)
                    }

                    if summary.shortTermGain == 0 && summary.shortTermLoss == 0 {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text("Net: \(Formatters.formatUSD(summary.netShortTerm))")
                        .font(.caption.bold())
                        .foregroundColor(summary.netShortTerm >= 0 ? Theme.profitGreen : Theme.lossRed)
                }

                Spacer()

                // Long-term breakdown
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Long-Term")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    if summary.longTermGain > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                            Text(Formatters.formatUSD(summary.longTermGain))
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.profitGreen)
                    }

                    if summary.longTermLoss < 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.right")
                                .font(.caption2)
                            Text(Formatters.formatUSD(summary.longTermLoss))
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.lossRed)
                    }

                    if summary.longTermGain == 0 && summary.longTermLoss == 0 {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text("Net: \(Formatters.formatUSD(summary.netLongTerm))")
                        .font(.caption.bold())
                        .foregroundColor(summary.netLongTerm >= 0 ? Theme.profitGreen : Theme.lossRed)
                }
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

    // MARK: - Sell Calculator Button

    private var sellCalculatorButton: some View {
        Button {
            showSellCalculator = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plusminus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.bitcoinOrange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sell Calculator")
                        .font(.subheadline.bold())
                        .foregroundColor(Theme.textPrimary)
                    Text("Simulate a sale and see your tax impact")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.bitcoinOrange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disposals List

    private var disposalsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Taxable Events")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 4)

            ForEach(filteredDisposals.sorted(by: { $0.disposal.date > $1.disposal.date })) { result in
                NavigationLink(destination: DisposalDetailView(result: result, method: method)) {
                    disposalRow(result)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func disposalRow(_ result: DisposalResult) -> some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: result.disposal.type == .sell ? "arrow.up.circle.fill" : "creditcard.fill")
                .font(.title3)
                .foregroundColor(Theme.lossRed)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.disposal.type == .sell ? "Sold" : "Spent")
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.textPrimary)

                Text("\(Formatters.formatBTC(result.disposal.btcAmount)) BTC on \(Formatters.formatDate(result.disposal.date))")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.formatUSD(result.totalGain))
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundColor(result.totalGain >= 0 ? Theme.profitGreen : Theme.lossRed)

                Text(result.holdingPeriodLabel)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.cardBorder.opacity(0.5))
                    .cornerRadius(4)
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
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(Theme.textSecondary.opacity(0.5))

            Text("No Taxable Events")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            Text("When you import sells or payments, your capital gains will appear here with full lot matching.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
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

    private var noDisposalsForYear: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundColor(Theme.profitGreen)

            Text("No taxable events in \(selectedYear.map { String($0) } ?? "any year")")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Export Functions

    private func exportForm8949() {
        let csv = TaxExportService.generateForm8949CSV(disposals: disposals, year: selectedYear)
        let yearLabel = selectedYear.map { String($0) } ?? "all-years"
        if let url = TaxExportService.writeToTempFile(csv: csv, filename: "stacktracker-form8949-\(yearLabel).csv") {
            Haptics.success()
            exportURL = url
            showExportSheet = true
        } else {
            Haptics.error()
        }
    }

    private func exportSummary() {
        let csv = TaxExportService.generateSummaryCSV(disposals: disposals, year: selectedYear)
        let yearLabel = selectedYear.map { String($0) } ?? "all-years"
        if let url = TaxExportService.writeToTempFile(csv: csv, filename: "stacktracker-tax-summary-\(yearLabel).csv") {
            Haptics.success()
            exportURL = url
            showExportSheet = true
        } else {
            Haptics.error()
        }
    }
    private func presentShareSheet(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // Find the topmost presented controller
        var topController = root
        while let presented = topController.presentedViewController {
            topController = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
        }

        topController.present(activityVC, animated: true)
    }
}

import Foundation

struct TaxExportService {

    /// Generate a Form 8949-compatible CSV from disposal results
    /// Columns match IRS Form 8949 / TurboTax import format:
    /// Description, Date Acquired, Date Sold, Proceeds, Cost Basis, Gain/Loss, Holding Period
    static func generateForm8949CSV(
        disposals: [DisposalResult],
        year: Int? = nil
    ) -> String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"

        var lines: [String] = []

        // Header matching Form 8949 / TurboTax import
        lines.append("Description,Date Acquired,Date Sold,Proceeds,Cost Basis,Gain or Loss,Term")

        let filtered: [DisposalResult]
        if let year = year {
            filtered = disposals.filter {
                calendar.component(.year, from: $0.disposal.date) == year
            }
        } else {
            filtered = disposals
        }

        for result in filtered.sorted(by: { $0.disposal.date < $1.disposal.date }) {
            for match in result.matches {
                let description = String(format: "%.8f BTC", match.btcAmount)
                let acquired = dateFormatter.string(from: match.lotDate)
                let sold = dateFormatter.string(from: result.disposal.date)
                let proceeds = String(format: "%.2f", match.proceeds)
                let costBasis = String(format: "%.2f", match.costBasis)
                let gain = String(format: "%.2f", match.gain)
                let term = match.isLongTerm ? "Long-term" : "Short-term"

                lines.append([description, acquired, sold, proceeds, costBasis, gain, term].joined(separator: ","))
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Summary CSV with aggregated per-disposal data (simpler format)
    static func generateSummaryCSV(
        disposals: [DisposalResult],
        year: Int? = nil
    ) -> String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy"

        var lines: [String] = []
        lines.append("Date,Type,BTC Amount,Proceeds,Cost Basis,Short-Term Gain,Long-Term Gain,Net Gain")

        let filtered: [DisposalResult]
        if let year = year {
            filtered = disposals.filter {
                calendar.component(.year, from: $0.disposal.date) == year
            }
        } else {
            filtered = disposals
        }

        for result in filtered.sorted(by: { $0.disposal.date < $1.disposal.date }) {
            let date = dateFormatter.string(from: result.disposal.date)
            let type = result.disposal.type == .sell ? "Sell" : "Payment"
            let btc = String(format: "%.8f", result.disposal.btcAmount)
            let proceeds = String(format: "%.2f", result.totalProceeds)
            let costBasis = String(format: "%.2f", result.totalCostBasis)
            let stGain = String(format: "%.2f", result.shortTermGain)
            let ltGain = String(format: "%.2f", result.longTermGain)
            let netGain = String(format: "%.2f", result.totalGain)

            lines.append([date, type, btc, proceeds, costBasis, stGain, ltGain, netGain].joined(separator: ","))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Write CSV string to temp file and return URL
    static func writeToTempFile(csv: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

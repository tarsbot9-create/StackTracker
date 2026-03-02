import Foundation
import SwiftData

@Model
final class Purchase {
    var id: UUID
    var date: Date
    var btcAmount: Double
    var pricePerBTC: Double
    var usdSpent: Double
    var walletName: String
    var notes: String
    var createdAt: Date

    init(
        date: Date = .now,
        btcAmount: Double,
        pricePerBTC: Double,
        walletName: String = "Default",
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.btcAmount = btcAmount
        self.pricePerBTC = pricePerBTC
        self.usdSpent = btcAmount * pricePerBTC
        self.walletName = walletName
        self.notes = notes
        self.createdAt = .now
    }

    var satsAmount: Int {
        Int(btcAmount * 100_000_000)
    }

    var currentPL: ((Double) -> Double) {
        { currentPrice in
            (currentPrice - self.pricePerBTC) / self.pricePerBTC * 100
        }
    }
}

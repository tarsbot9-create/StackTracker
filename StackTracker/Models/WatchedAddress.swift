import Foundation
import SwiftData

@Model
final class WatchedAddress {
    var id: UUID
    var address: String
    var label: String
    var addedAt: Date
    var lastSyncedAt: Date?
    var cachedBalance: Double // in BTC

    init(address: String, label: String = "Cold Storage") {
        self.id = UUID()
        self.address = address
        self.label = label
        self.addedAt = .now
        self.lastSyncedAt = nil
        self.cachedBalance = 0
    }
}

@Model
final class AddressTransaction {
    var id: UUID
    var txid: String
    var address: String
    var btcAmount: Double
    var date: Date
    var blockHeight: Int
    var isIncoming: Bool

    // Cost basis tracking
    var costBasisSource: String // "matched", "manual", "historical"
    var pricePerBTC: Double
    var usdValue: Double
    var matchedPurchaseID: UUID?

    init(
        txid: String,
        address: String,
        btcAmount: Double,
        date: Date,
        blockHeight: Int,
        isIncoming: Bool
    ) {
        self.id = UUID()
        self.txid = txid
        self.address = address
        self.btcAmount = btcAmount
        self.date = date
        self.blockHeight = blockHeight
        self.isIncoming = isIncoming
        self.costBasisSource = "unset"
        self.pricePerBTC = 0
        self.usdValue = 0
        self.matchedPurchaseID = nil
    }
}

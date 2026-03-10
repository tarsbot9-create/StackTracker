import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case buy = "buy"
    case sell = "sell"
    case withdrawal = "withdrawal"  // transfer to cold storage
    case payment = "payment"        // spent BTC
}

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
    var transactionTypeRaw: String
    var isFlagged: Bool

    var transactionType: TransactionType {
        get { TransactionType(rawValue: transactionTypeRaw) ?? .buy }
        set { transactionTypeRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        btcAmount: Double,
        pricePerBTC: Double,
        walletName: String = "Default",
        notes: String = "",
        transactionType: TransactionType = .buy
    ) {
        self.id = UUID()
        self.date = date
        self.btcAmount = btcAmount
        self.pricePerBTC = pricePerBTC
        self.usdSpent = btcAmount * pricePerBTC
        self.walletName = walletName
        self.notes = notes
        self.createdAt = .now
        self.transactionTypeRaw = transactionType.rawValue
        self.isFlagged = false
    }

    var satsAmount: Int {
        Int(btcAmount * 100_000_000)
    }

    /// Whether this transaction adds to the stack
    var isStackPositive: Bool {
        transactionType == .buy
    }

    /// Whether this transaction reduces the stack (sell or payment, NOT withdrawal)
    var isStackNegative: Bool {
        transactionType == .sell || transactionType == .payment
    }

    /// Whether this is a transfer (withdrawal to cold storage)
    var isTransfer: Bool {
        transactionType == .withdrawal
    }

    /// Effective BTC for stack calculation (positive for buys, negative for sells/payments, zero for withdrawals)
    var effectiveBTC: Double {
        if isStackPositive { return btcAmount }
        if isStackNegative { return -btcAmount }
        return 0 // withdrawals don't affect exchange stack
    }

    var currentPL: ((Double) -> Double) {
        { currentPrice in
            (currentPrice - self.pricePerBTC) / self.pricePerBTC * 100
        }
    }
}

import Foundation
import SwiftData

@Model
final class PriceCache {
    var date: Date
    var priceUSD: Double
    var fetchedAt: Date

    init(date: Date, priceUSD: Double) {
        self.date = date
        self.priceUSD = priceUSD
        self.fetchedAt = .now
    }

    var isStale: Bool {
        fetchedAt.timeIntervalSinceNow < -300 // 5 minutes
    }
}

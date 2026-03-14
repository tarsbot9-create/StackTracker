import Foundation

struct CurrentPriceResponse: Codable {
    let bitcoin: BitcoinPrice

    struct BitcoinPrice: Codable {
        let usd: Double
        let usd_24h_change: Double?
    }
}

struct MarketChartResponse: Codable {
    let prices: [[Double]] // [[timestamp, price], ...]
}

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
}

@MainActor
final class PriceService: ObservableObject {
    static let shared = PriceService()

    @Published var currentPrice: Double = 0
    @Published var change24h: Double = 0
    @Published var chartData: [PricePoint] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let session: URLSession
    private var lastFetch: Date?
    private var lastChartFetch: Date?
    private var lastChartDays: Int?
    private var historicalCache: [String: (price: Double, fetched: Date)] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func fetchCurrentPrice() async {
        // Rate limit: don't fetch more than once per 60 seconds
        if let last = lastFetch, Date().timeIntervalSince(last) < 60 {
            return
        }

        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(CurrentPriceResponse.self, from: data)
            self.currentPrice = response.bitcoin.usd
            self.change24h = response.bitcoin.usd_24h_change ?? 0
            self.lastFetch = Date()
            self.lastError = nil
        } catch {
            self.lastError = "Price unavailable"
        }
    }

    func fetchChartData(days: Int = 30) async {
        // Cache: don't re-fetch same chart within 60 seconds
        if let last = lastChartFetch, lastChartDays == days,
           Date().timeIntervalSince(last) < 60, !chartData.isEmpty {
            return
        }

        let urlString = "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=\(days)"
        guard let url = URL(string: urlString) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(MarketChartResponse.self, from: data)
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            self.chartData = response.prices.compactMap { pair in
                let point = PricePoint(
                    date: Date(timeIntervalSince1970: pair[0] / 1000),
                    price: pair[1]
                )
                return point.date >= cutoff ? point : nil
            }
            self.lastChartFetch = Date()
            self.lastChartDays = days
            self.lastError = nil
        } catch {
            self.lastError = "Chart data unavailable"
        }
    }

    func historicalPrice(for date: Date) async -> Double? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let dateStr = formatter.string(from: date)

        // Cache: historical prices don't change, cache for 10 minutes
        if let cached = historicalCache[dateStr],
           Date().timeIntervalSince(cached.fetched) < 600 {
            return cached.price
        }

        let urlString = "https://api.coingecko.com/api/v3/coins/bitcoin/history?date=\(dateStr)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let market = json["market_data"] as? [String: Any],
               let prices = market["current_price"] as? [String: Any],
               let usd = prices["usd"] as? Double {
                historicalCache[dateStr] = (price: usd, fetched: Date())
                return usd
            }
        } catch {}
        return nil
    }
}

import Foundation

// MARK: - Mempool.space API Response Models

struct MempoolAddressInfo: Codable {
    let address: String
    let chain_stats: ChainStats
    let mempool_stats: ChainStats

    struct ChainStats: Codable {
        let funded_txo_count: Int
        let funded_txo_sum: Int // in sats
        let spent_txo_count: Int
        let spent_txo_sum: Int // in sats
    }

    var confirmedBalanceSats: Int {
        chain_stats.funded_txo_sum - chain_stats.spent_txo_sum
    }

    var confirmedBalanceBTC: Double {
        Double(confirmedBalanceSats) / 100_000_000.0
    }

    var unconfirmedBalanceSats: Int {
        mempool_stats.funded_txo_sum - mempool_stats.spent_txo_sum
    }
}

struct MempoolTx: Codable {
    let txid: String
    let status: TxStatus
    let vin: [TxInput]
    let vout: [TxOutput]

    struct TxStatus: Codable {
        let confirmed: Bool
        let block_height: Int?
        let block_time: Int? // unix timestamp
    }

    struct TxInput: Codable {
        let prevout: TxOutput?
    }

    struct TxOutput: Codable {
        let scriptpubkey_address: String?
        let value: Int // sats
    }
}

// MARK: - Blockchain Service

@MainActor
final class BlockchainService: ObservableObject {
    @Published var isLoading = false
    @Published var lastError: String?

    private let session: URLSession
    private let baseURL = "https://mempool.space/api"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Validate Address

    static func isValidBitcoinAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)

        // Legacy (1...)
        if trimmed.hasPrefix("1") && trimmed.count >= 26 && trimmed.count <= 34 {
            return trimmed.allSatisfy { $0.isLetter || $0.isNumber }
        }

        // P2SH (3...)
        if trimmed.hasPrefix("3") && trimmed.count >= 26 && trimmed.count <= 34 {
            return trimmed.allSatisfy { $0.isLetter || $0.isNumber }
        }

        // Native SegWit (bc1q...)
        if trimmed.lowercased().hasPrefix("bc1q") && trimmed.count >= 42 && trimmed.count <= 62 {
            return true
        }

        // Taproot (bc1p...)
        if trimmed.lowercased().hasPrefix("bc1p") && trimmed.count >= 42 && trimmed.count <= 62 {
            return true
        }

        return false
    }

    // MARK: - Fetch Address Info

    func fetchAddressInfo(_ address: String) async throws -> MempoolAddressInfo {
        let url = URL(string: "\(baseURL)/address/\(address)")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BlockchainError.invalidAddress
        }

        return try JSONDecoder().decode(MempoolAddressInfo.self, from: data)
    }

    // MARK: - Fetch Transactions

    func fetchTransactions(_ address: String) async throws -> [MempoolTx] {
        let url = URL(string: "\(baseURL)/address/\(address)/txs")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BlockchainError.fetchFailed
        }

        return try JSONDecoder().decode([MempoolTx].self, from: data)
    }

    // MARK: - Parse Transactions for Address

    func parseTransactions(txs: [MempoolTx], forAddress address: String) -> [AddressTransaction] {
        var result: [AddressTransaction] = []

        for tx in txs {
            guard tx.status.confirmed else { continue }

            let received = tx.vout
                .filter { $0.scriptpubkey_address == address }
                .reduce(0) { $0 + $1.value }

            let sent = tx.vin
                .compactMap { $0.prevout }
                .filter { $0.scriptpubkey_address == address }
                .reduce(0) { $0 + $1.value }

            let netSats = received - sent
            guard netSats != 0 else { continue }

            let date = tx.status.block_time.map { Date(timeIntervalSince1970: Double($0)) } ?? .now
            let blockHeight = tx.status.block_height ?? 0

            let addrTx = AddressTransaction(
                txid: tx.txid,
                address: address,
                btcAmount: abs(Double(netSats)) / 100_000_000.0,
                date: date,
                blockHeight: blockHeight,
                isIncoming: netSats > 0
            )

            result.append(addrTx)
        }

        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Auto-Match with Exchange Purchases

    func autoMatchTransactions(
        addressTxs: [AddressTransaction],
        purchases: [ExchangeWithdrawalCandidate]
    ) -> [AddressTransaction] {
        var matched = addressTxs
        var usedPurchaseIDs: Set<UUID> = []

        for i in matched.indices {
            guard matched[i].isIncoming && matched[i].costBasisSource == "unset" else { continue }

            let txAmount = matched[i].btcAmount
            let txDate = matched[i].date

            // Find purchases within 24h and within 2% of the amount
            // (exchange fees/network fees cause slight differences)
            let candidates = purchases.filter { candidate in
                guard !usedPurchaseIDs.contains(candidate.id) else { return false }
                let timeDiff = abs(txDate.timeIntervalSince(candidate.date))
                let amountDiff = abs(txAmount - candidate.btcAmount) / max(txAmount, 0.00000001)
                return timeDiff < 86400 * 2 && amountDiff < 0.05 // within 48h and 5% amount
            }

            // Pick the closest match by time
            if let best = candidates.min(by: { abs($0.date.timeIntervalSince(txDate)) < abs($1.date.timeIntervalSince(txDate)) }) {
                matched[i].costBasisSource = "matched"
                matched[i].pricePerBTC = best.pricePerBTC
                matched[i].usdValue = matched[i].btcAmount * best.pricePerBTC
                matched[i].matchedPurchaseID = best.id
                usedPurchaseIDs.insert(best.id)
            }
        }

        return matched
    }
}

// MARK: - Helper Types

struct ExchangeWithdrawalCandidate {
    let id: UUID
    let date: Date
    let btcAmount: Double
    let pricePerBTC: Double
}

enum BlockchainError: LocalizedError {
    case invalidAddress
    case fetchFailed
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "Invalid Bitcoin address."
        case .fetchFailed: return "Failed to fetch blockchain data. Try again."
        case .rateLimited: return "Too many requests. Wait a moment and try again."
        }
    }
}

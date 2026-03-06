import Foundation
import RevenueCat

@MainActor
final class SubscriptionService: NSObject, ObservableObject {
    static let shared = SubscriptionService()

    @Published var isPro: Bool = false
    @Published var packages: [Package] = []
    @Published var purchaseError: String?

    private let entitlementID = "pro"
    private let freeTransactionLimit = 25

    func configure() {
        // TODO: Replace with your RevenueCat API key
        Purchases.configure(withAPIKey: "your_revenuecat_api_key_here")
        Purchases.shared.delegate = self

        Task {
            await refreshStatus()
        }
    }

    func refreshStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.isPro = customerInfo.entitlements[entitlementID]?.isActive == true
        } catch {
            // Keep current state on failure
        }
    }

    func fetchPackages() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                self.packages = current.availablePackages
            }
        } catch {
            // Packages unavailable
        }
    }

    func purchase(_ package: Package) async -> Bool {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            let isActive = result.customerInfo.entitlements[entitlementID]?.isActive == true
            self.isPro = isActive
            self.purchaseError = nil
            return isActive
        } catch let error as ErrorCode {
            if error == .purchaseCancelledError {
                return false
            }
            self.purchaseError = error.localizedDescription
            return false
        } catch {
            self.purchaseError = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let isActive = customerInfo.entitlements[entitlementID]?.isActive == true
            self.isPro = isActive
            self.purchaseError = nil
            return isActive
        } catch {
            self.purchaseError = error.localizedDescription
            return false
        }
    }

    func canAddTransaction(currentCount: Int) -> Bool {
        return isPro || currentCount < freeTransactionLimit
    }

    func remainingFreeTransactions(currentCount: Int) -> Int {
        max(0, freeTransactionLimit - currentCount)
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.isPro = customerInfo.entitlements[self.entitlementID]?.isActive == true
        }
    }
}

import Foundation
import UserNotifications

/// Manages local notifications for price alerts and milestone achievements.
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var priceAlerts: [PriceAlert] = []

    private let alertsKey = "priceAlerts"
    private let lastMilestoneKey = "lastMilestoneNotified"

    struct PriceAlert: Codable, Identifiable {
        let id: UUID
        let targetPrice: Double
        let direction: Direction  // above or below
        var isTriggered: Bool

        enum Direction: String, Codable {
            case above
            case below
        }

        var description: String {
            let arrow = direction == .above ? "above" : "below"
            return "BTC \(arrow) \(Formatters.formatUSD(targetPrice))"
        }
    }

    init() {
        loadAlerts()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Price Alerts

    func addPriceAlert(targetPrice: Double, direction: PriceAlert.Direction) {
        let alert = PriceAlert(
            id: UUID(),
            targetPrice: targetPrice,
            direction: direction,
            isTriggered: false
        )
        priceAlerts.append(alert)
        saveAlerts()
        Haptics.confirm()
    }

    func removePriceAlert(_ alert: PriceAlert) {
        priceAlerts.removeAll { $0.id == alert.id }
        saveAlerts()
        // Cancel any pending notification for this alert
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [alert.id.uuidString]
        )
    }

    /// Check current price against all alerts and fire notifications for triggered ones.
    func checkPriceAlerts(currentPrice: Double) {
        guard currentPrice > 0 else { return }

        for i in priceAlerts.indices {
            guard !priceAlerts[i].isTriggered else { continue }

            let shouldTrigger: Bool
            switch priceAlerts[i].direction {
            case .above:
                shouldTrigger = currentPrice >= priceAlerts[i].targetPrice
            case .below:
                shouldTrigger = currentPrice <= priceAlerts[i].targetPrice
            }

            if shouldTrigger {
                priceAlerts[i].isTriggered = true
                sendPriceAlertNotification(
                    price: currentPrice,
                    alert: priceAlerts[i]
                )
            }
        }
        saveAlerts()
    }

    private func sendPriceAlertNotification(price: Double, alert: PriceAlert) {
        let content = UNMutableNotificationContent()
        content.title = "Price Alert Triggered"
        let direction = alert.direction == .above ? "crossed above" : "dropped below"
        content.body = "Bitcoin \(direction) \(Formatters.formatUSD(alert.targetPrice)). Current: \(Formatters.formatUSD(price))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Milestone Notifications

    /// Check if a new milestone was reached and notify.
    func checkMilestoneReached(totalSats: Int) {
        let milestoneThresholds = [
            100_000, 500_000, 1_000_000, 5_000_000,
            10_000_000, 25_000_000, 50_000_000, 100_000_000
        ]

        let milestoneNames = [
            100_000: "100K Sats",
            500_000: "500K Sats",
            1_000_000: "1M Sats",
            5_000_000: "5M Sats",
            10_000_000: "0.1 BTC",
            25_000_000: "0.25 BTC",
            50_000_000: "0.5 BTC",
            100_000_000: "1 BTC"
        ]

        let celebrations = [
            100_000: "You've stacked your first 100,000 sats!",
            500_000: "Half a million sats. Serious stacking!",
            1_000_000: "One million sats! You're a millionaire (in sats).",
            5_000_000: "5 million sats. You're building real wealth.",
            10_000_000: "0.1 BTC! Welcome to the club.",
            25_000_000: "Quarter Bitcoin! You're in rare company.",
            50_000_000: "Halfway to a whole coin!",
            100_000_000: "WHOLE COINER! You've made it."
        ]

        let lastNotified = UserDefaults.standard.integer(forKey: lastMilestoneKey)

        // Find the highest milestone reached that hasn't been notified
        guard let highestReached = milestoneThresholds.filter({ totalSats >= $0 }).max(),
              highestReached > lastNotified else {
            return
        }

        // Send notification
        let name = milestoneNames[highestReached] ?? "\(highestReached) sats"
        let celebration = celebrations[highestReached] ?? "New milestone reached!"

        let content = UNMutableNotificationContent()
        content.title = "\(name) Milestone!"
        content.body = celebration
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "milestone_\(highestReached)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        UserDefaults.standard.set(highestReached, forKey: lastMilestoneKey)
    }

    // MARK: - Persistence

    private func saveAlerts() {
        if let data = try? JSONEncoder().encode(priceAlerts) {
            UserDefaults.standard.set(data, forKey: alertsKey)
        }
    }

    private func loadAlerts() {
        guard let data = UserDefaults.standard.data(forKey: alertsKey),
              let alerts = try? JSONDecoder().decode([PriceAlert].self, from: data) else {
            return
        }
        self.priceAlerts = alerts
    }
}

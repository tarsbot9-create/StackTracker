import Foundation
import StoreKit
import SwiftUI

/// Manages App Store review prompts.
/// Requests a review after the user has been using the app for at least 14 days
/// and has added at least 5 transactions. Respects a 90-day cooldown between prompts.
enum ReviewPromptService {
    private static let firstLaunchKey = "reviewPrompt_firstLaunch"
    private static let lastPromptKey = "reviewPrompt_lastPrompt"
    private static let promptCountKey = "reviewPrompt_count"

    private static let minimumDaysBeforePrompt = 14
    private static let minimumTransactions = 5
    private static let cooldownDays = 90
    private static let maxPromptsPerYear = 3

    /// Call this on every app launch to record the first launch date.
    static func recordLaunch() {
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }

    /// Check if conditions are met and request a review if appropriate.
    /// - Parameter transactionCount: Current number of transactions in the app
    static func requestReviewIfAppropriate(transactionCount: Int) {
        guard shouldPrompt(transactionCount: transactionCount) else { return }

        // Request the review
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)

            // Record this prompt
            UserDefaults.standard.set(Date(), forKey: lastPromptKey)
            let count = UserDefaults.standard.integer(forKey: promptCountKey)
            UserDefaults.standard.set(count + 1, forKey: promptCountKey)
        }
    }

    private static func shouldPrompt(transactionCount: Int) -> Bool {
        // Must have enough transactions
        guard transactionCount >= minimumTransactions else { return false }

        // Must have been installed for minimum days
        guard let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date else {
            return false
        }
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        guard daysSinceInstall >= minimumDaysBeforePrompt else { return false }

        // Respect cooldown between prompts
        if let lastPrompt = UserDefaults.standard.object(forKey: lastPromptKey) as? Date {
            let daysSincePrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            guard daysSincePrompt >= cooldownDays else { return false }
        }

        // Don't exceed yearly limit
        let count = UserDefaults.standard.integer(forKey: promptCountKey)
        guard count < maxPromptsPerYear else { return false }

        return true
    }
}

import UIKit

/// Centralized haptic feedback helpers
enum Haptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Light tap - filter toggles, minor interactions
    static func tap() {
        lightImpact.impactOccurred()
    }

    /// Medium tap - saving, confirming
    static func confirm() {
        mediumImpact.impactOccurred()
    }

    /// Heavy tap - destructive actions, important events
    static func heavy() {
        heavyImpact.impactOccurred()
    }

    /// Selection changed - picker changes, segment controls
    static func select() {
        selection.selectionChanged()
    }

    /// Success - import complete, purchase saved
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// Warning - approaching limits, duplicates found
    static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Error - failed operations
    static func error() {
        notification.notificationOccurred(.error)
    }
}

import SwiftUI
import UIKit

enum Theme {
    static let bitcoinOrange = Color(hex: "F7931A")

    // Adaptive colors: custom dark navy in dark mode, system colors in light mode
    static let darkBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: "0D1117") : .systemBackground
    })

    static let cardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: "161B22") : .secondarySystemBackground
    })

    static let cardBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: "30363D") : .separator
    })

    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .label
    })

    static let textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: "8B949E") : .secondaryLabel
    })

    // These stay the same in both modes
    static let profitGreen = Color(hex: "3FB950")
    static let lossRed = Color(hex: "F85149")
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

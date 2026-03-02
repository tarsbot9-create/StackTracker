import SwiftUI

enum Theme {
    static let bitcoinOrange = Color(hex: "F7931A")
    static let darkBackground = Color(hex: "0D1117")
    static let cardBackground = Color(hex: "161B22")
    static let cardBorder = Color(hex: "30363D")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8B949E")
    static let profitGreen = Color(hex: "3FB950")
    static let lossRed = Color(hex: "F85149")
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

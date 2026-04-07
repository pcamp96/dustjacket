import SwiftUI

enum DustjacketTheme {
    // MARK: - Colors (Hardcover-inspired dark palette)

    /// Near-black background
    static let background = Color(red: 0.05, green: 0.05, blue: 0.05)

    /// Card/surface background
    static let surfaceCard = Color(red: 0.10, green: 0.10, blue: 0.10)

    /// Elevated surface
    static let surfaceElevated = Color(red: 0.15, green: 0.15, blue: 0.15)

    /// Warm book/paper amber accent
    static let accent = Color(red: 0.91, green: 0.84, blue: 0.72)

    /// Soft accent for backgrounds
    static let accentSoft = Color(red: 0.91, green: 0.84, blue: 0.72).opacity(0.15)

    // MARK: - Typography

    /// Serif title font for book-forward aesthetic
    static let titleFont = Font.system(.title2, design: .serif, weight: .bold)

    /// Large title for headers
    static let largeTitleFont = Font.system(.largeTitle, design: .serif, weight: .bold)

    /// Subtitle font
    static let subtitleFont = Font.system(.subheadline, design: .serif)
}

// MARK: - Color Hex Extension

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

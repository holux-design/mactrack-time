import SwiftUI

enum ProjectColors {
    static let palette = [
        "#5B8DEF", "#34C759", "#FF9500", "#AF52DE",
        "#FF2D55", "#64D2FF", "#FFD60A", "#8E8E93"
    ]

    static func color(from hex: String) -> Color {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return .accentColor
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}

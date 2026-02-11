import SwiftUI

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        
        let r, g, b, a: Double
        
        switch cleaned.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = opacity
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            self = .red
            return
        }
        
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}


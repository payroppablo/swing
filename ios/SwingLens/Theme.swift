import SwiftUI

// Paleta y tipografía de SwingLens (espejo del diseño web).
enum Theme {
    static let darkGreen   = Color(hex: 0x1B4332)
    static let actionGreen = Color(hex: 0x4CAF50)
    static let lightGreen  = Color(hex: 0x7FD08A)
    static let cream       = Color(hex: 0xFBFBF8)
    static let ink         = Color(hex: 0x16201B)
    static let slate       = Color(hex: 0x6B756F)
    static let amber       = Color(hex: 0xC2843B)
    static let cardBorder  = Color(hex: 0xECEAE3)

    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

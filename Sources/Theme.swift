import SwiftUI
import AppKit

enum Palette {
    static let surfaceTop = Color(hex: 0x323236)
    static let surfaceBottom = Color(hex: 0x17171A)
    static let drawerTop = Color(hex: 0x2B2B30)
    static let drawerBottom = Color(hex: 0x151518)
    static let labelPrimary = Color(hex: 0xF7F7F8)
    static let labelSecondary = Color(hex: 0xA4A4AC)
    static let labelTertiary = Color(hex: 0x77777F)
    static let hairline = Color.white.opacity(0.13)

    static let mint = Color(hex: 0x58E0B0)
    static let mintDeep = Color(hex: 0x2BC7A3)
    static let mintTeal = Color(hex: 0x48D9C5)

    static let sunset = Color(hex: 0xFF8F7A)
    static let sunsetDeep = Color(hex: 0xF26D63)

    static let berry = Color(hex: 0xF18AC0)
    static let berryDeep = Color(hex: 0xC77DFF)

    static let pause = Color(hex: 0xF3A04F)
    static let pauseDeep = Color(hex: 0xE28736)
    static let gold = Color(hex: 0xF6C95C)
    static let goldDeep = Color(hex: 0xE3A93E)
    static let dim = Color(hex: 0x8E8E97)
    static let red = Color(hex: 0xFF7A72)
}

enum WidgetTheme: String, CaseIterable, Identifiable, Equatable {
    case mint
    case sunset
    case berry
    case minimal
    case cream
    case amber
    case ice
    case terracotta

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mint: return "薄荷"
        case .sunset: return "日落"
        case .berry: return "莓果"
        case .minimal: return "冷静极简"
        case .cream: return "奶油纸感"
        case .amber: return "琥珀仪表"
        case .ice: return "冰川蓝"
        case .terracotta: return "陶土暖调"
        }
    }

    var isLight: Bool {
        self == .minimal || self == .cream || self == .amber || self == .ice || self == .terracotta
    }

    var active: Color {
        switch self {
        case .mint: return Palette.mint
        case .sunset: return Palette.sunset
        case .berry: return Palette.berry
        case .minimal: return Color(hex: 0x5C5CEB)
        case .cream: return Color(hex: 0x6E7A4E)
        case .amber: return Color(hex: 0xB07B2E)
        case .ice: return Color(hex: 0x4F83AD)
        case .terracotta: return Color(hex: 0xA45C3F)
        }
    }

    var deep: Color {
        switch self {
        case .mint: return Palette.mintDeep
        case .sunset: return Palette.sunsetDeep
        case .berry: return Palette.berryDeep
        case .minimal: return Color(hex: 0x7A7CF0)
        case .cream: return Color(hex: 0x8A9466)
        case .amber: return Color(hex: 0xC8923C)
        case .ice: return Color(hex: 0x6FA3C7)
        case .terracotta: return Color(hex: 0xC57A58)
        }
    }

    var gradient: [Color] {
        switch self {
        case .mint: return [Palette.mint, Palette.mintTeal]
        case .sunset: return [Palette.sunset, Palette.sunsetDeep]
        case .berry: return [Palette.berry, Palette.berryDeep]
        case .minimal: return [Color(hex: 0x5C5CEB), Color(hex: 0x8A8BF7)]
        case .cream: return [Color(hex: 0x6E7A4E), Color(hex: 0x8A9466)]
        case .amber: return [Color(hex: 0xB07B2E), Color(hex: 0xC8923C)]
        case .ice: return [Color(hex: 0x4F83AD), Color(hex: 0x76A9CB)]
        case .terracotta: return [Color(hex: 0xA45C3F), Color(hex: 0xC57A58)]
        }
    }

    var capsuleTop: Color {
        switch self {
        case .mint: return Color(hex: 0x22312E)
        case .sunset: return Color(hex: 0x32231F)
        case .berry: return Color(hex: 0x2E2030)
        case .minimal: return Color(hex: 0xFCFCFF)
        case .cream: return Color(hex: 0xFDF8EC)
        case .amber: return Color(hex: 0xF4EFE3)
        case .ice: return Color(hex: 0xEDF5FC)
        case .terracotta: return Color(hex: 0xF7EADF)
        }
    }

    var capsuleBottom: Color {
        switch self {
        case .mint: return Color(hex: 0x0E1715)
        case .sunset: return Color(hex: 0x17100E)
        case .berry: return Color(hex: 0x160E19)
        case .minimal: return Color(hex: 0xF0F1FA)
        case .cream: return Color(hex: 0xF3EBD9)
        case .amber: return Color(hex: 0xE9E2D2)
        case .ice: return Color(hex: 0xDCEAF6)
        case .terracotta: return Color(hex: 0xEEDBCB)
        }
    }

    var drawerTop: Color {
        switch self {
        case .mint: return Color(hex: 0x1F2C29)
        case .sunset: return Color(hex: 0x2C1F1B)
        case .berry: return Color(hex: 0x291C2B)
        case .minimal: return Color(hex: 0xFAFAFF)
        case .cream: return Color(hex: 0xFBF5E8)
        case .amber: return Color(hex: 0xF5F0E4)
        case .ice: return Color(hex: 0xEAF3FB)
        case .terracotta: return Color(hex: 0xEAD1BC)
        }
    }

    var drawerBottom: Color {
        switch self {
        case .mint: return Color(hex: 0x0C1412)
        case .sunset: return Color(hex: 0x150E0C)
        case .berry: return Color(hex: 0x130C16)
        case .minimal: return Color(hex: 0xF0F1FA)
        case .cream: return Color(hex: 0xF2EAD7)
        case .amber: return Color(hex: 0xEAE3D3)
        case .ice: return Color(hex: 0xDCEAF7)
        case .terracotta: return Color(hex: 0xF7EDE2)
        }
    }

    var primaryText: Color {
        switch self {
        case .mint, .sunset, .berry: return Palette.labelPrimary
        case .minimal: return Color(hex: 0x10152F)
        case .cream: return Color(hex: 0x2F2A1E)
        case .amber: return Color(hex: 0x3B362C)
        case .ice: return Color(hex: 0x17304A)
        case .terracotta: return Color(hex: 0x4A2E25)
        }
    }

    var secondaryText: Color {
        switch self {
        case .mint, .sunset, .berry: return Palette.labelSecondary
        case .minimal: return Color(hex: 0x5F6484)
        case .cream: return Color(hex: 0x6F6755)
        case .amber: return Color(hex: 0x6F6758)
        case .ice: return Color(hex: 0x4E6A84)
        case .terracotta: return Color(hex: 0x7A5B4A)
        }
    }

    var tertiaryText: Color {
        switch self {
        case .mint, .sunset, .berry: return Palette.labelTertiary
        case .minimal: return Color(hex: 0x8A8EA6)
        case .cream: return Color(hex: 0x9A907A)
        case .amber: return Color(hex: 0x9A917F)
        case .ice: return Color(hex: 0x7C93A8)
        case .terracotta: return Color(hex: 0xA18876)
        }
    }

    var hairline: Color {
        switch self {
        case .mint, .sunset, .berry: return Palette.hairline
        case .minimal: return Color(hex: 0x10152F).opacity(0.10)
        case .cream: return Color(hex: 0x2F2A1E).opacity(0.12)
        case .amber: return Color(hex: 0x3B362C).opacity(0.10)
        case .ice: return Color(hex: 0x17304A).opacity(0.10)
        case .terracotta: return Color(hex: 0x4A2E25).opacity(0.12)
        }
    }

    var track: Color {
        switch self {
        case .mint, .sunset, .berry: return .white.opacity(0.085)
        case .minimal: return active.opacity(0.12)
        case .cream, .amber, .ice, .terracotta: return active.opacity(0.14)
        }
    }

    var surfaceHighlight: Color {
        switch self {
        case .mint, .sunset, .berry: return .white.opacity(0.065)
        case .minimal: return .white.opacity(0.50)
        case .cream, .amber, .ice, .terracotta: return .white.opacity(0.46)
        }
    }

    var borderTop: Color {
        switch self {
        case .mint, .sunset, .berry: return .white.opacity(0.18)
        case .minimal: return active.opacity(0.34)
        case .cream, .amber, .ice, .terracotta: return active.opacity(0.32)
        }
    }

    var borderBottom: Color {
        switch self {
        case .mint, .sunset, .berry: return .white.opacity(0.035)
        case .minimal, .cream, .amber, .ice, .terracotta: return active.opacity(0.10)
        }
    }

    var innerBorder: Color {
        switch self {
        case .mint, .sunset, .berry: return .white.opacity(0.045)
        case .minimal: return primaryText.opacity(0.06)
        case .cream, .amber, .ice, .terracotta: return primaryText.opacity(0.07)
        }
    }

    var buttonHover: Color {
        switch self {
        case .mint, .sunset, .berry: return .white.opacity(0.11)
        case .minimal, .cream, .amber, .ice, .terracotta: return primaryText.opacity(0.08)
        }
    }

    var glowOpacity: Double {
        isLight ? 0.08 : 0.13
    }

    var pauseAccent: Color {
        isLight ? Color(hex: 0xC6761F) : Palette.pause
    }

    var pauseGradient: [Color] {
        isLight
            ? [Color(hex: 0xD58A2E), Color(hex: 0xB96A1A)]
            : [Palette.pause, Palette.pauseDeep]
    }

    var goldAccent: Color {
        isLight ? Color(hex: 0xB27C14) : Palette.gold
    }

    var goldGradient: [Color] {
        isLight
            ? [Color(hex: 0xC9962B), Color(hex: 0xA97A12)]
            : [Palette.gold, Palette.goldDeep]
    }

    var dimAccent: Color {
        isLight ? Color(hex: 0x8C8F9E) : Palette.dim
    }

    var errorAccent: Color {
        isLight ? Color(hex: 0xD04B43) : Palette.red
    }

    /// A soft tint of the card's own surface, pulled toward the theme accent.
    /// This keeps the encouragement block integrated with every theme instead
    /// of stamping the same terracotta panel onto all of them.
    var encouragementSurface: Color {
        let base = drawerTop.blended(with: drawerBottom, ratio: 0.5)
        return base.blended(with: active, ratio: isLight ? 0.12 : 0.20)
    }

    var usesSegmentedProgress: Bool {
        self == .minimal
    }

    var usesTickProgress: Bool {
        self == .amber
    }

    var heroDesign: Font.Design {
        switch self {
        case .cream, .amber, .terracotta: return .serif
        default: return .rounded
        }
    }
}

/// The encouragement banner keeps its own quiet terracotta palette so the copy
/// block stays legible and visually separate from the selected accent theme.
enum EncouragementPalette {
    static let accent = Color(hex: 0xBC7459)

    static func accent(light: Bool) -> Color {
        accent
    }

    static func primaryText(light: Bool) -> Color {
        light ? Color(hex: 0x603E35) : Color(hex: 0xF4DFD3)
    }

    static func line(light: Bool) -> Color {
        light ? Color(hex: 0xECDED4) : Color(hex: 0x584137)
    }
}

extension Color {
    /// Linear sRGB blending, used for theme-derived surfaces.
    func blended(with other: Color, ratio: Double) -> Color {
        let amount = min(1, max(0, ratio))
        guard
            let base = NSColor(self).usingColorSpace(.sRGB),
            let target = NSColor(other).usingColorSpace(.sRGB)
        else { return self }
        return Color(
            .sRGB,
            red: base.redComponent + (target.redComponent - base.redComponent) * amount,
            green: base.greenComponent + (target.greenComponent - base.greenComponent) * amount,
            blue: base.blueComponent + (target.blueComponent - base.blueComponent) * amount,
            opacity: 1
        )
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum WidgetFormat {
    /// `04h 32m` — the compact form used in the capsule.
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%02dh %02dm", hours, minutes)
    }

    /// `4h 32m`, without the leading zero.
    static func short(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(String(format: "%02dm", minutes))" }
        if minutes > 0 { return "\(minutes)m" }
        return "0m"
    }

    /// `4 小时 32 分` — the hero line in the expanded card.
    static func chinese(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours) 小时 \(String(format: "%02d", minutes)) 分"
        }
        return "\(minutes) 分钟"
    }

    static func goalLong(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours > 0 && rest > 0 {
            return "\(hours) 小时 \(String(format: "%02d", rest)) 分"
        }
        if hours > 0 { return "\(hours) 小时" }
        return "\(rest) 分钟"
    }

    static func goal(_ minutes: Int) -> String {
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes / 60)h \(String(format: "%02dm", minutes % 60))"
    }
}

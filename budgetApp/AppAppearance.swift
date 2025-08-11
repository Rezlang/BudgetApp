// File: BudgetApp/AppAppearance.swift
// Theme settings (light/dark/system) + helpers + accent color

import SwiftUI
import UIKit

enum ColorSchemePreference: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var display: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

final class ThemeStore: ObservableObject {
    @AppStorage("theme_preference") private var storedPref: String = ColorSchemePreference.system.rawValue
    @AppStorage("accent_hex") private var storedAccentHex: String = "#7F3DFF"   // accent used for non-themed UI
    @Published var cornerRadius: CGFloat = 16
    
    var preference: ColorSchemePreference {
        get { ColorSchemePreference(rawValue: storedPref) ?? .system }
        set { storedPref = newValue.rawValue; objectWillChange.send() }
    }
    var effectiveColorScheme: ColorScheme? {
        switch preference {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    
    // Accent color used selectively (not for budget tiles/icons)
    var accentColor: Color { Color(hex: storedAccentHex) ?? .purple }
    func setAccent(_ c: Color) { storedAccentHex = c.hexRGB ?? "#7F3DFF"; objectWillChange.send() }
}

extension ShapeStyle where Self == Color {
    static var cardBackground: Color { Color(.secondarySystemBackground) }
    static var subtleOutline: Color { Color.gray.opacity(0.18) }
    static var purpleWash: Color { Color.purple.opacity(0.10) }
}

// MARK: - Color helpers (hex + stable random + lighten)

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexRGB: String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let R = Int(round(r * 255)), G = Int(round(g * 255)), B = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", R, G, B)
    }

    static func stableRandom(for uuid: UUID) -> Color {
        var hasher = Hasher()
        hasher.combine(uuid)
        let seed = hasher.finalize()
        let hue = Double(abs(seed % 360)) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }

    /// Returns a lighter variant by blending toward white.
    func lightened(by amount: CGFloat) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let nr = min(r + (1 - r) * amount, 1)
        let ng = min(g + (1 - g) * amount, 1)
        let nb = min(b + (1 - b) * amount, 1)
        return Color(.sRGB, red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
    }
}

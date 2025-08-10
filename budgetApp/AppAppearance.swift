// File: App/AppAppearance.swift
// Theme settings (light/dark/system) + small design helpers

import SwiftUI

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
}

extension ShapeStyle where Self == Color {
    static var cardBackground: Color { Color(.secondarySystemBackground) }
    static var subtleOutline: Color { Color.gray.opacity(0.18) }
    static var purpleWash: Color { Color.purple.opacity(0.10) }
}

// File: App/BudgetRewardsApp.swift
// Entry point + global theming

import SwiftUI

@main
struct BudgetRewardsApp: App {
    @StateObject private var theme = ThemeStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .tint(.purple)
                .preferredColorScheme(theme.effectiveColorScheme)
        }
    }
}


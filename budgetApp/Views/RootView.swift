// FILE: BudgetApp/Views/RootView.swift
// Tab root — apply accent app-wide for generic UI, but category tiles override their own colors.

import SwiftUI

struct RootView: View {
    @StateObject private var store = AppStore()
    @EnvironmentObject private var theme: ThemeStore
    @State private var showSettings = false
    
    var body: some View {
        TabView {
            NavigationStack {
                BudgetView()
                    .environmentObject(store)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSettings = true
                            } label: { Image(systemName: "gearshape.fill") }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsSheet()
                            .environmentObject(theme)
                            .environmentObject(store)   // ensure store is available
                    }
            }
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("Budget")
            }
            
            NavigationStack {
                CardsView()
                    .environmentObject(store)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSettings = true
                            } label: { Image(systemName: "gearshape.fill") }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsSheet()
                            .environmentObject(theme)
                            .environmentObject(store)   // ensure store is available
                    }
            }
            .tabItem {
                Image(systemName: "creditcard.fill")
                Text("Credit Cards")
            }
        }
        .tint(theme.accentColor)
    }
}

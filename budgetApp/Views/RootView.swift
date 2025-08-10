// File: Views/RootView.swift
// Tab root

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
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsSheet()
                            .environmentObject(theme)
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
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsSheet()
                            .environmentObject(theme)
                    }
            }
            .tabItem {
                Image(systemName: "creditcard.fill")
                Text("Credit Cards")
            }
        }
    }
}

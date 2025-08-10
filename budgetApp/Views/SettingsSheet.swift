// File: Views/SettingsSheet.swift
// Theme picker + small accents preview

import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeStore
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Color Mode", selection: Binding(
                        get: { theme.preference },
                        set: { theme.preference = $0 }
                    )) {
                        ForEach(ColorSchemePreference.allCases) { pref in
                            Text(pref.display).tag(pref)
                        }
                    }
                    
                    HStack {
                        Text("Accent")
                        Spacer()
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.subtleOutline))
                        Text("Purple")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Preview")) {
                    HStack {
                        Capsule().fill(.purpleWash).frame(height: 10)
                        Capsule().fill(.purple).frame(width: 10, height: 10)
                            .opacity(0.4)
                    }
                    .padding(.vertical, 6)
                    Text("Cards and highlights use a soft purple wash with subtle outlines for a modern look.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

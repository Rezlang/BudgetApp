// FILE: BudgetApp/Views/SettingsSheet.swift
// Theme picker + Accent color selector + Data reset

import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var store: AppStore

    @State private var showEraseConfirm = false
    @AppStorage("chatgpt_api_key") private var chatGPTKey: String = ""
    @AppStorage("chatGPTDebugEnabled") private var chatGPTDebugEnabled = false

    private let swatches: [Color] = [
        Color(hex: "#7F3DFF") ?? .purple,
        .blue, .teal, .indigo, .green, .orange, .pink, .red
    ]
    
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
                }
                
                Section(header: Text("Accent (for non-themed UI)")) {
                    HStack(spacing: 10) {
                        ForEach(swatches.indices, id: \.self) { i in
                            let c = swatches[i]
                            Button {
                                theme.setAccent(c)
                            } label: {
                                ZStack {
                                    Circle().fill(c).frame(width: 28, height: 28)
                                    if theme.accentColor.hexRGB == c.hexRGB {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white)
                                            .shadow(radius: 1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        ColorPicker("Custom", selection: Binding(
                            get: { theme.accentColor },
                            set: { theme.setAccent($0) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }

                Section(header: Text("Preview")) {
                    HStack {
                        Capsule().fill(Color.cardBackground).overlay(Capsule().stroke(.subtleOutline)).frame(height: 10)
                        Capsule().fill(theme.accentColor).frame(width: 10, height: 10)
                    }
                    .padding(.vertical, 6)
                    Text("Accent color applies to generic controls and icons that don't have their own category color.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("ChatGPT")) {
                    TextField("ChatGPT API Key", text: $chatGPTKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section(header: Text("Banking")) {
                    Button {
                        PlaidService.shared.linkAccount()
                    } label: {
                        Label("Link Account with Plaid", systemImage: "link")
                    }
                }

                Section(header: Text("Data")) {
                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        Label("Clear Purchases & Reset Budgets", systemImage: "trash")
                    }
                }

                Section {
                    Toggle("ChatGPT debug output", isOn: $chatGPTDebugEnabled)
                } header: {
                    Text("Developer Settings").foregroundColor(.gray)
                }
            }
            .navigationTitle("Settings")
            .tint(theme.accentColor)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Erase all purchases and reset budgets?",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("Erase", role: .destructive) {
                    store.clearPurchasesAndBudgets()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all purchases and restore category limits to defaults. Cards and tags will be kept.")
            }
        }
    }
}

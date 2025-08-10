// File: Views/Cards/CardEditorSheet.swift
// Create or edit a CreditCard, including per-category multipliers with a purple accent preview

import SwiftUI

struct CardEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    
    /// Pass an existing card to edit; nil to create a new one.
    var card: CreditCard?
    /// Called when user taps Save. You decide whether to add/update in the caller.
    var onSave: (CreditCard) -> Void
    /// Optional delete handler. If provided and we're editing, a Delete button will appear.
    var onDelete: (() -> Void)? = nil
    
    @State private var name: String = ""
    @State private var baseMultiplierString: String = "1.0"
    @State private var rotatingNote: String = ""
    /// Editable multipliers keyed by category name
    @State private var multipliers: [String: String] = [:]
    
    var baseMultiplier: Double { Double(baseMultiplierString) ?? 1.0 }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Card")) {
                    TextField("Name", text: $name)
                    TextField("Base Multiplier (e.g. 1, 1.5, 2)", text: Binding(
                        get: { baseMultiplierString },
                        set: { baseMultiplierString = filteredNumber($0) }
                    ))
                    .keyboardType(.decimalPad)
                    TextField("Rotating Note (optional)", text: $rotatingNote)
                }
                
                Section(header: Text("Category Multipliers")) {
                    ForEach(store.categories) { cat in
                        HStack {
                            Text(cat.name)
                            Spacer()
                            TextField("—", text: Binding(
                                get: { multipliers[cat.name] ?? "" },
                                set: { multipliers[cat.name] = filteredNumber($0) }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        }
                    }
                    Button {
                        // Clear all category-specific multipliers
                        for cat in store.categories {
                            multipliers[cat.name] = ""
                        }
                    } label: {
                        Label("Clear Category Multipliers", systemImage: "eraser")
                    }
                }
                
                Section(header: Text("Preview")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                            Text(name.isEmpty ? "Unnamed Card" : name).bold()
                            Spacer()
                            Text(String(format: "Base %.1fx", baseMultiplier))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.purpleWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.subtleOutline))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(store.categories.prefix(4)) { cat in
                                let m = (Double(multipliers[cat.name] ?? "") ?? baseMultiplier)
                                HStack {
                                    Text(cat.name)
                                    Spacer()
                                    Text(String(format: "%.1fx", m))
                                        .monospacedDigit()
                                }
                                Divider()
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                }
                
                if card != nil, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Delete Card", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(card == nil ? "New Card" : "Edit Card")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let cleaned: [String: Double] = multipliers.reduce(into: [:]) { dict, pair in
                            if let v = Double(pair.value), v > 0 {
                                dict[pair.key] = v
                            }
                        }
                        let model = CreditCard(
                            id: card?.id ?? UUID(),
                            name: name.isEmpty ? "Card" : name,
                            multipliers: cleaned,
                            baseMultiplier: baseMultiplier,
                            rotatingNote: rotatingNote.isEmpty ? nil : rotatingNote
                        )
                        onSave(model)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let c = card {
                    name = c.name
                    baseMultiplierString = String(format: "%.1f", c.baseMultiplier)
                    rotatingNote = c.rotatingNote ?? ""
                    multipliers = Dictionary(uniqueKeysWithValues: c.multipliers.map { ($0.key, String($0.value)) })
                } else {
                    // Initialize with blanks
                    multipliers = Dictionary(uniqueKeysWithValues: store.categories.map { ($0.name, "") })
                }
            }
        }
    }
    
    private func filteredNumber(_ s: String) -> String {
        // allow digits and a single dot
        let filtered = s.filter { "0123456789.".contains($0) }
        let parts = filtered.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count > 1 {
            return parts[0] + "." + parts[1].replacingOccurrences(of: ".", with: "")
        }
        return filtered
    }
}

// ===== FILE: BudgetApp/Views/Budget/BudgetSubviews.swift =====
// Tiles & editors. "+" tile is full height. Progress edge uses the category color.
// In move mode, tiles show a pulsing dashed/solid border (no jiggle).

import SwiftUI

struct BudgetProgressCard: View {
    var title: String
    var spent: Double
    var limit: Double
    var editing: Bool
    var cornerRadius: CGFloat
    var tileSize: CGSize = .init(width: UIScreen.main.bounds.width/2 - 24, height: 120)
    /// Wiggle is unused (no jiggle), kept for API compatibility.
    var wiggle: Bool = false
    /// Optional accent color for this tile (category color). If nil, defaults are used.
    var accent: Color? = nil
    
    var ratio: Double { limit > 0 ? min(spent / limit, 1.0) : 0 }
    var over: Bool { limit > 0 && spent > limit }
    
    private var strokeColor: Color {
        if let a = accent { return a.lightened(by: 0.65) }
        return .subtleOutline
    }
    
    var body: some View {
        TileCard(
            size: tileSize,
            cornerRadius: cornerRadius,
            editing: editing,
            wiggle: false,                // no jiggle
            background: .cardBackground,  // solid, base color
            overlayStroke: strokeColor,
            dashedWhenEditing: true,      // pulse between dashed and solid while moving
            pulseBackgroundWhenEditing: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.headline)
                    if over {
                        Spacer()
                        Text("Over")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((accent ?? Color.gray).opacity(0.18), in: Capsule())
                    }
                }
                ProgressView(value: ratio)
                    .progressViewStyle(.linear)
                    .tint(accent ?? .accentColor) // progress bar is exactly the category color
                HStack {
                    Text(String(format: "$%.2f spent", spent))
                    Spacer()
                    Text(limit > 0 ? String(format: "Limit $%.0f", limit) : "No limit")
                }
                .font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

struct AddCategoryCard: View {
    var action: ()->Void
    /// Full height (normal tile)
    var tileSize: CGSize = .init(width: UIScreen.main.bounds.width/2 - 24, height: 120)
    
    var body: some View {
        Button(action: action) {
            TileCard(size: tileSize, background: .purpleWash) {
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill").font(.title2)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("AddCategoryTile")
    }
}

struct MoveCategoriesTile: View {
    var action: ()->Void
    var tileSize: CGSize = .init(width: UIScreen.main.bounds.width/2 - 24, height: 120)
    var body: some View {
        Button(action: action) {
            TileCard(size: tileSize, background: .cardBackground) {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.arrow.down.square").font(.title2)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("MoveCategoriesTile")
    }
}
// In: BudgetApp/Views/Budget/BudgetSubviews.swift
// Replace the entire CategoryEditorSheet with this updated version:

struct CategoryEditorSheet: View {
    var item: CategoryItem?
    var onSave: (CategoryItem)->Void
    var onDelete: (() -> Void)? = nil            // <-- NEW
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var limitString: String = ""
    @State private var iconSystemName: String = "tag.fill"
    @State private var colorSelection: Color = .purple   // stored as hex on save

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basics")) {
                    TextField("Name", text: $name)
                    TextField("Monthly Limit", text: Binding(
                        get: { limitString },
                        set: { limitString = $0.filter { "0123456789.".contains($0) } }
                    ))
                    .keyboardType(.decimalPad)
                }

                Section(header: Text("Appearance")) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorSelection.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: iconSystemName)
                                .foregroundStyle(colorSelection)
                        }
                        .accessibilityHidden(true)

                        ColorPicker("Icon Color", selection: $colorSelection, supportsOpacity: false)
                    }

                    Menu("Quick Symbols") {
                        ForEach(["tag.fill", "cart.fill", "fork.knife", "airplane", "car.fill", "tram.fill", "popcorn.fill", "bag.fill", "house.fill", "stethoscope", "bolt.fill"], id: \.self) { s in
                            Button {
                                iconSystemName = s
                            } label: {
                                Label(s, systemImage: s)
                            }
                        }
                    }
                }

                // --- NEW: destructive delete, shown only when editing an existing category
                if item != nil, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Delete Category", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let lim = Double(limitString) ?? 0
                        var model = CategoryItem(
                            id: item?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Category" : name,
                            limit: lim,
                            iconSystemName: iconSystemName.isEmpty ? "tag.fill" : iconSystemName,
                            iconColorHex: colorSelection.hexRGB
                        )
                        if item != nil, item?.iconColorHex == nil, colorSelection == .purple {
                            model.iconColorHex = item?.iconColorHex
                        }
                        onSave(model)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = item?.name ?? ""
                limitString = item.map { String(format: "%.0f", $0.limit) } ?? ""
                iconSystemName = item?.iconSystemName ?? "tag.fill"
                if let existing = item {
                    if let hex = existing.iconColorHex, let c = Color(hex: hex) {
                        colorSelection = c
                    } else {
                        colorSelection = Color.stableRandom(for: existing.id)
                    }
                }
            }
        }
    }
}


struct PurchaseRow: View {
    let purchase: Purchase
    let category: CategoryItem?               // pass whole category for icon/color
    let bestCard: (card: CreditCard, mult: Double, estPoints: Double)
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let iconName = category?.iconSystemName ?? "tag.fill"
        let tint = category.map { store.color(for: $0) } ?? Color.purple

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: iconName)
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(purchase.merchant).bold()
                    Spacer()
                    Text(String(format: "$%.2f", purchase.amount)).bold()
                }
                HStack {
                    Text(category?.name ?? "Uncategorized")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(bestCard.card.name + String(format: " · %.0fx", bestCard.mult))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// File: Views/Budget/BudgetSubviews.swift
// Budget subviews: progress card, add category button, category editor, purchase row

import SwiftUI

struct BudgetProgressCard: View {
    var title: String
    var spent: Double
    var limit: Double
    var editing: Bool
    var cornerRadius: CGFloat
    
    var ratio: Double { limit > 0 ? min(spent / limit, 1.0) : 0 }
    var over: Bool { limit > 0 && spent > limit }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                if over {
                    Spacer()
                    Text("Over").font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.18), in: Capsule())
                }
            }
            ProgressView(value: ratio)
                .progressViewStyle(.linear)
            HStack {
                Text(String(format: "$%.2f spent", spent))
                Spacer()
                Text(limit > 0 ? String(format: "Limit $%.0f", limit) : "No limit")
            }
            .font(.subheadline).foregroundColor(.secondary)
        }
        .padding()
        .background( (editing ? .purpleWash : .cardBackground), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.subtleOutline, lineWidth: editing ? 1.5 : 1)
        )
    }
}

struct AddCategoryCard: View {
    var action: ()->Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.largeTitle)
                Text("New Category").font(.subheadline)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding()
            .background(.purpleWash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.subtleOutline)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CategoryEditorSheet: View {
    var item: CategoryItem?
    var onSave: (CategoryItem)->Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var limitString: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Monthly Limit", text: Binding(
                    get: { limitString },
                    set: { limitString = $0.filter { "0123456789.".contains($0) } }
                ))
                .keyboardType(.decimalPad)
            }
            .navigationTitle(item == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let lim = Double(limitString) ?? 0
                        let model = CategoryItem(id: item?.id ?? UUID(), name: name.isEmpty ? "Category" : name, limit: lim)
                        onSave(model)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = item?.name ?? ""
                limitString = item.map { String(format: "%.0f", $0.limit) } ?? ""
            }
        }
    }
}

struct PurchaseRow: View {
    let purchase: Purchase
    let categoryName: String
    let bestCard: (card: CreditCard, mult: Double, estPoints: Double)
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.purpleWash)
                    .frame(width: 34, height: 34)
                Image(systemName: "tag.fill").font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(purchase.merchant).bold()
                    Spacer()
                    Text(String(format: "$%.2f", purchase.amount)).bold()
                }
                HStack {
                    Text(categoryName)
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

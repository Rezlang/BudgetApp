// File: Views/Budget/PurchaseListView.swift
import SwiftUI

enum PurchaseFilter: Identifiable, Hashable {
    case category(CategoryItem)
    case tag(Tag)

    var id: UUID {
        switch self {
        case .category(let c): return c.id
        case .tag(let t): return t.id
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PurchaseFilter, rhs: PurchaseFilter) -> Bool { lhs.id == rhs.id }
}

struct PurchaseListView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingCategory: CategoryItem?
    @State private var editingPurchase: Purchase?        // <-- tap-to-edit
    @Environment(\.dismiss) private var dismiss
    let filter: PurchaseFilter

    private var purchases: [Purchase] {
        switch filter {
        case .category(let cat):
            return store.purchases.filter { $0.categoryID == cat.id }
        case .tag(let tag):
            return store.purchases.filter { $0.tagIDs.contains(tag.id) }
        }
    }

    private var title: String {
        switch filter {
        case .category(let cat): return cat.name
        case .tag(let tag): return "#\(tag.name)"
        }
    }

    var body: some View {
        List {
            ForEach(purchases) { p in
                VStack(alignment: .leading, spacing: 4) {
                    let cat = store.categories.first(where: { $0.id == p.categoryID })
                    PurchaseRow(
                        purchase: p,
                        category: cat,
                        bestCard: CardRecommender.bestCard(
                            for: store.categoryName(for: p.categoryID),
                            amount: p.amount,
                            from: store.cards
                        )
                    )
                    .environmentObject(store)

                    if !p.tagIDs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(p.tagIDs, id: \.self) { tid in
                                    TagCapsule(text: store.tagName(for: tid))
                                }
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingPurchase = p                      // <-- present editor for this purchase
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            if case .category(let cat) = filter {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingCategory = cat
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityIdentifier("EditCategoryFromListButton")
                }
            }
        }
        // FILE: BudgetApp/Views/Budget/PurchaseListView.swift
        // Replace the existing sheet(item: $editingCategory) block with this version:

        .sheet(item: $editingCategory) { original in
            CategoryEditorSheet(
                item: original,
                onSave: { updated in
                    var u = updated
                    u.id = original.id
                    store.updateCategory(u)
                },
                onDelete: {
                    // Remove the category, persist, then pop back to Budget
                    store.categories.removeAll { $0.id == original.id }
                    store.persist()
                    // Pop the navigation stack after the sheet dismisses
                    DispatchQueue.main.async { dismiss() }
                }
            )
        }


        // Edit Purchase sheet (can change category & tags)
        .sheet(item: $editingPurchase) { p in
            PurchaseEditorSheet(purchase: p) { updated in
                if let idx = store.purchases.firstIndex(where: { $0.id == updated.id }) {
                    store.purchases[idx] = updated
                    store.persist()
                }
            } onDelete: {
                store.deletePurchase(p)
            }
            .environmentObject(store)
        }
    }
}

private struct TagCapsule: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.subtleOutline))
    }
}

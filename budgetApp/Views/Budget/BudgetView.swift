// File: Views/Budget/BudgetView.swift
// Reorder only when "Move Categories" tile is tapped; handle buttons appear on tiles.
// The two control tiles ("New Category" and "Move Categories") are always last.

import SwiftUI
import UniformTypeIdentifiers

struct BudgetView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    @State private var showAddPurchase = false
    @State private var editingMode = false
    @State private var editingCategory: CategoryItem?
    @State private var showCategoryEditor = false
    
    // Purchase editing
    @State private var editingPurchase: Purchase?
    @State private var showPurchaseEditor = false

    // Wiggle driver
    @State private var wiggleOn = false
    // Reorder state
    @State private var draggingCategory: CategoryItem?

    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private var tileSize: CGSize { .init(width: UIScreen.main.bounds.width/2 - 24, height: 120) }

    var totalSpent: Double { store.purchases.reduce(0) { $0 + $1.amount } }
    func spent(for cat: CategoryItem) -> Double {
        store.purchases.filter { $0.categoryID == cat.id }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 12) {
            BudgetProgressCard(
                title: "Overall",
                spent: totalSpent,
                limit: store.budget.overallLimit,
                editing: false,
                cornerRadius: theme.cornerRadius,
                tileSize: .init(width: UIScreen.main.bounds.width - 32, height: 110),
                wiggle: false
            )
            .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    // Regular category tiles
                    ForEach(store.categories) { cat in
                        let spentAmt = spent(for: cat)

                        ZStack(alignment: .topTrailing) {
                            BudgetProgressCard(
                                title: cat.name,
                                spent: spentAmt,
                                limit: cat.limit,
                                editing: editingMode,
                                cornerRadius: theme.cornerRadius,
                                tileSize: tileSize,
                                wiggle: wiggleOn
                            )
                            .opacity(draggingCategory?.id == cat.id ? 0.35 : 1)
                            .onTapGesture {
                                if editingMode {
                                    editingCategory = cat
                                    showCategoryEditor = true
                                }
                            }
                            
                            // Drag handle appears only in edit mode
                            if editingMode {
                                HandleDragButton()
                                    .padding(6)
                                    .onDrag {
                                        draggingCategory = cat
                                        return NSItemProvider(object: cat.id.uuidString as NSString)
                                    }
                            }
                        }
                        // OnDrop to reorder (keeps scrolling intact)
                        .onDrop(of: [UTType.text],
                                delegate: BudgetReorderDropDelegate(
                                    current: $draggingCategory,
                                    item: cat,
                                    getItems: { store.categories },
                                    move: { from, to in
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            store.categories.move(fromOffsets: IndexSet(integer: from),
                                                                  toOffset: to > from ? to + 1 : to)
                                        }
                                    },
                                    persist: { store.persist() }
                                )
                        )
                    }
                    
                    // Control tiles: always last
                    AddCategoryCard {
                        editingMode = true
                        wiggleOn = true
                        editingCategory = nil
                        showCategoryEditor = true
                    }
                    MoveCategoriesTile {
                        editingMode.toggle()
                        wiggleOn = editingMode
                        draggingCategory = nil
                    }
                }
                .padding(.horizontal)

                // Purchases list + tap to edit
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Purchases").font(.headline)
                        Spacer()
                        Button {
                            showAddPurchase = true
                        } label: {
                            Label("Add", systemImage: "plus").labelStyle(.iconOnly)
                        }
                        .accessibilityIdentifier("AddPurchaseButton")
                    }
                    if store.purchases.isEmpty {
                        Text("No purchases yet. Add one below.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.purchases) { p in
                            PurchaseRow(
                                purchase: p,
                                categoryName: store.categoryName(for: p.categoryID),
                                bestCard: CardRecommender.bestCard(
                                    for: store.categoryName(for: p.categoryID),
                                    amount: p.amount,
                                    from: store.cards
                                )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingPurchase = p
                                showPurchaseEditor = true
                            }
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if editingMode {
                    Button("Done") {
                        editingMode = false
                        wiggleOn = false
                        draggingCategory = nil
                    }
                } else {
                    Button { showAddPurchase = true } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPurchase) {
            AddPurchaseSheet().environmentObject(store)
        }
        .sheet(isPresented: $showCategoryEditor) {
            CategoryEditorSheet(item: editingCategory) { result in
                if var existing = editingCategory {
                    existing.name = result.name
                    existing.limit = result.limit
                    store.updateCategory(existing)
                } else {
                    store.addCategory(name: result.name, limit: result.limit)
                }
            }
        }
        .sheet(isPresented: $showPurchaseEditor) {
            if let p = editingPurchase {
                PurchaseEditorSheet(purchase: p) { updated in
                    if let idx = store.purchases.firstIndex(where: { $0.id == updated.id }) {
                        store.purchases[idx] = updated
                        store.persist()
                    }
                } onDelete: {
                    if let p = editingPurchase {
                        store.deletePurchase(p)
                    }
                }
                .environmentObject(store)
            }
        }
    }
}

private struct HandleDragButton: View {
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
            )
            .shadow(radius: 1)
            .accessibilityLabel("Drag Handle")
    }
}

// DropDelegate
private struct BudgetReorderDropDelegate: DropDelegate {
    @Binding var current: CategoryItem?
    let item: CategoryItem
    let getItems: () -> [CategoryItem]
    let move: (_ from: Int, _ to: Int) -> Void
    let persist: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging = current,
              dragging != item,
              let from = getItems().firstIndex(of: dragging),
              let to = getItems().firstIndex(of: item)
        else { return }
        if getItems()[to].id != dragging.id {
            move(from, to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        current = nil
        persist()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }
}

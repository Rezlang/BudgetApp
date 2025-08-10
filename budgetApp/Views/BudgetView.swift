// File: Views/Budget/BudgetView.swift
// Budget screen with stable edit mode, drag reorder only while editing, and preserved scrolling
// Purple accents applied

import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    @State private var showAddPurchase = false
    @State private var editingMode = false
    @State private var editingCategory: CategoryItem?
    @State private var showCategoryEditor = false

    // Wiggle driver
    @State private var wiggleOn = false
    @State private var draggingID: UUID?

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var totalSpent: Double {
        store.purchases.reduce(0) { $0 + $1.amount }
    }
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
                cornerRadius: theme.cornerRadius
            )
            .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.categories) { cat in
                        let spentAmt = spent(for: cat)

                        let tile = BudgetProgressCard(
                            title: cat.name,
                            spent: spentAmt,
                            limit: cat.limit,
                            editing: editingMode,
                            cornerRadius: theme.cornerRadius
                        )
                        .overlay(alignment: .topTrailing) {
                            if editingMode {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                    .padding(6)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(6)
                            }
                        }
                        .rotationEffect(.degrees(editingMode && wiggleOn ? 1.2 : 0))
                        .scaleEffect(editingMode && wiggleOn ? 1.01 : 1.0)
                        .animation(
                            editingMode
                            ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true)
                            : .default,
                            value: wiggleOn
                        )
                        .opacity(draggingID == cat.id ? 0.35 : 1)

                        .onTapGesture {
                            if editingMode {
                                editingCategory = cat
                                showCategoryEditor = true
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.35) {
                            if !editingMode {
                                editingMode = true
                            }
                            wiggleOn = true
                        }

                        Group {
                            if editingMode {
                                tile
                                    .draggable(cat.id.uuidString) {
                                        draggingID = cat.id
                                        return Text(cat.name)
                                            .padding(6)
                                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .dropDestination(for: String.self) { items, _ in
                                        guard let fromID = items.first,
                                              let fromIdx = store.categories.firstIndex(where: { $0.id.uuidString == fromID }),
                                              let toIdx = store.categories.firstIndex(of: cat),
                                              fromIdx != toIdx
                                        else { return false }
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            store.categories.move(
                                                fromOffsets: IndexSet(integer: fromIdx),
                                                toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
                                            )
                                            store.persist()
                                        }
                                        draggingID = nil
                                        return true
                                    } isTargeted: { hovering in
                                        if !hovering { draggingID = nil }
                                    }
                            } else {
                                tile
                            }
                        }
                    }

                    AddCategoryCard {
                        if editingMode {
                            editingCategory = nil
                            showCategoryEditor = true
                        }
                    }
                    .opacity(editingMode ? 1 : 0.7)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Purchases").font(.headline)
                        Spacer()
                        Button {
                            showAddPurchase.toggle()
                        } label: {
                            Label("Add", systemImage: "plus")
                                .labelStyle(.iconOnly)
                        }
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
                        draggingID = nil
                    }
                } else {
                    Button { showAddPurchase.toggle() } label: {
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
    }
}

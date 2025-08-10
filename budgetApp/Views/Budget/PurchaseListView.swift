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

    // Make Hashable/Equatable depend only on the underlying id.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PurchaseFilter, rhs: PurchaseFilter) -> Bool {
        lhs.id == rhs.id
    }
}


struct PurchaseListView: View {
    @EnvironmentObject var store: AppStore
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
                    PurchaseRow(
                        purchase: p,
                        categoryName: store.categoryName(for: p.categoryID),
                        bestCard: CardRecommender.bestCard(
                            for: store.categoryName(for: p.categoryID),
                            amount: p.amount,
                            from: store.cards
                        )
                    )
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
            }
        }
        .navigationTitle(title)
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

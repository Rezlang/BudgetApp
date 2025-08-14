import SwiftUI

struct DuplicateReviewSheet: View {
    @Binding var matches: [DuplicateMatch]
    var onDone: () -> Void
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(matches) { match in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dateText(match.new.date))
                            .font(.caption)
                        Text("Existing: \(match.existing.merchant) - $\(String(format: "%.2f", match.existing.amount))")
                            .font(.subheadline)
                        Text("New: \(match.new.merchant) - $\(String(format: "%.2f", match.new.amount))")
                            .font(.subheadline)
                        HStack {
                            Button("Add to Budget") {
                                store.addPurchase(match.new)
                                if let catName = store.category(for: match.new.categoryID)?.name {
                                    store.remember(merchant: match.new.merchant, categoryName: catName)
                                }
                                remove(match)
                            }
                            Button("Ignore") {
                                remove(match)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Possible Duplicates")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ignore All") {
                        matches.removeAll()
                        onDone()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add All") {
                        for m in matches {
                            store.addPurchase(m.new)
                            if let catName = store.category(for: m.new.categoryID)?.name {
                                store.remember(merchant: m.new.merchant, categoryName: catName)
                            }
                        }
                        matches.removeAll()
                        onDone()
                    }
                }
            }
        }
    }

    private func remove(_ match: DuplicateMatch) {
        if let idx = matches.firstIndex(where: { $0.id == match.id }) {
            matches.remove(at: idx)
        }
        if matches.isEmpty { onDone() }
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

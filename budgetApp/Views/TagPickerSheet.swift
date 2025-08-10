import SwiftUI

struct TagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    @State private var query: String = ""
    @Binding var selected: Set<UUID>

    private var filtered: [Tag] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty { return store.tags }
        return store.tags.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search tags", text: $query)
                        .textInputAutocapitalization(.words)
                }
                .padding(10)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.subtleOutline))
                .padding()

                List {
                    ForEach(filtered) { tag in
                        Button {
                            toggle(tag.id)
                        } label: {
                            HStack {
                                Text(tag.name)
                                Spacer()
                                if selected.contains(tag.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                        }
                    }
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       store.tags.first(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) == nil {
                        Section {
                            Button {
                                let created = store.addTag(name: query)
                                selected.insert(created.id)
                                query = ""
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create \"\(query)\"")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Select Tags")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
}

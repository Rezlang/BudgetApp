// FILE: BudgetApp/Views/Cards/CardsView.swift
// Tap card to edit (when not moving). Combined "New + Move" control tile in one grid slot. Subtle wiggle in move mode.
// Now includes on-screen debug console for ChatGPT receipt analysis.

import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct CardsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: ThemeStore
    @State private var amountString: String = ""
    @State private var naturalText: String = ""
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var selectedCategoryID: UUID?
    
    @State private var debugLines: [String] = []
    @AppStorage("chatGPTDebugEnabled") private var chatGPTDebugEnabled = false
    
    @State private var cardsEditingMode = false
    @State private var cardsWiggleOn = false
    @State private var editingCard: CreditCard?
    @State private var showCardEditor = false
    @State private var draggingCard: CreditCard?
    
    private let gridColumns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
    private var tileSize: CGSize { .init(width: UIScreen.main.bounds.width/2 - 24, height: 120) }
    
    private var parsedAmount: Double {
        let filtered = amountString.filter { "0123456789.".contains($0) }
        return Double(filtered) ?? 0.0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(store.cards) { card in
                        ZStack(alignment: .topTrailing) {
                            TileCard(size: tileSize,
                                     editing: cardsEditingMode,
                                     wiggle: cardsEditingMode && cardsWiggleOn,
                                     background: .cardBackground) {
                                CardTileContent(card: card)
                            }
                            .onTapGesture {
                                if !cardsEditingMode {
                                    editingCard = card
                                    showCardEditor = true
                                }
                            }
                            if cardsEditingMode {
                                HandleDragButton()
                                    .padding(6)
                                    .onDrag {
                                        draggingCard = card
                                        return NSItemProvider(object: card.id.uuidString as NSString)
                                    }
                            }
                        }
                        .onDrop(of: [UTType.text], delegate:
                                    CardsReorderDropDelegate(
                                        current: $draggingCard,
                                        item: card,
                                        getItems: { store.cards },
                                        move: { from, to in
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                                store.cards.move(fromOffsets: IndexSet(integer: from),
                                                                 toOffset: to > from ? to + 1 : to)
                                            }
                                        },
                                        persist: { store.persist() }
                                    )
                        )
                    }
                    
                    CombinedCardControlTile(
                        width: tileSize.width,
                        height: tileSize.height,
                        onNew: {
                            editingCard = nil
                            showCardEditor = true
                        },
                        onMoveToggle: {
                            cardsEditingMode.toggle()
                            cardsWiggleOn = cardsEditingMode
                            draggingCard = nil
                        },
                        isMoveOn: cardsEditingMode
                    )
                }
                .padding(.horizontal)
                
                PurchasePlannerSection(
                    naturalText: $naturalText,
                    amountString: $amountString,
                    selectedCategoryID: $selectedCategoryID
                )
                .environmentObject(store)
                
                ReceiptPickerSection(
                    selectedPhoto: $selectedPhoto,
                    isAnalyzing: $isAnalyzing,
                    selectedImage: $selectedImage,
                    amountString: $amountString,
                    selectedCategoryID: $selectedCategoryID
                )
                
                DetailsSection(
                    amountString: $amountString,
                    selectedCategoryID: $selectedCategoryID
                )
                .environmentObject(store)
                
                RecommendedCardCallout(
                    parsedAmount: parsedAmount,
                    selectedCategoryID: selectedCategoryID
                )
                .environmentObject(store)
                
                if chatGPTDebugEnabled {
                    DebugConsoleView(title: "ChatGPT Debug (Cards)", lines: $debugLines)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Credit Cards")
        .sheet(isPresented: $showCardEditor) {
            CardEditorSheet(card: editingCard) { updated in
                if let idx = store.cards.firstIndex(where: { $0.id == updated.id }) {
                    store.cards[idx] = updated
                } else {
                    store.cards.append(updated)
                }
                store.persist()
            } onDelete: {
                if let c = editingCard {
                    store.cards.removeAll { $0.id == c.id }
                    store.persist()
                }
            }
            .environmentObject(store)
        }
        .task(id: selectedPhoto) {
            await handleSelectedPhoto()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if cardsEditingMode {
                    Button("Done") { cardsEditingMode = false; cardsWiggleOn = false; draggingCard = nil }
                }
            }
        }
    }
    
    private func log(_ s: String) {
        guard chatGPTDebugEnabled else { return }
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        debugLines.append("\(f.string(from: Date())) \(s)")
        if debugLines.count > 400 { debugLines.removeFirst(debugLines.count - 400) }
    }
    
    private func parseDateISO(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        return iso.date(from: s)
    }
    
    private func handleSelectedPhoto() async {
        guard let item = selectedPhoto else { return }
        if isAnalyzing { log("Skip: analyze already running"); return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            log("Selected photo. Loading data…")
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                selectedImage = img
                log(String(format: "Image ready. bytes=%d, dims=%dx%d", data.count, Int(img.size.width), Int(img.size.height)))

                let allowedCats = store.categories.map { $0.name }
                let allowedTags = store.tags.map { $0.name }
                let txns = try await ChatGPTService.shared.analyzeTransactions(
                    image: img,
                    log: { self.log($0) },
                    allowedCategories: allowedCats,
                    allowedTags: allowedTags
                )
                if txns.isEmpty { log("No transactions parsed."); return }

                var imported = 0
                for t in txns {
                    guard t.amount > 0 else { continue }
                    let catID: UUID? = {
                        if let c = t.category, let id = store.categoryID(named: c) { return id }
                        return store.categoryID(named: "Other") ?? store.categories.first?.id
                    }()
                    let date = parseDateISO(t.date) ?? Date()

                    // Ensure tags exist (auto-create if needed), then attach IDs
                    let tagIDs: [UUID] = (t.tags ?? []).map { store.addTag(name: $0).id }

                    let p = Purchase(
                        date: date,
                        merchant: t.merchant,
                        amount: t.amount,
                        categoryID: catID,
                        notes: nil,
                        ocrText: nil,
                        tagIDs: tagIDs
                    )
                    store.addPurchase(p)
                    imported += 1
                    log("Imported: \(t.merchant) - \(String(format: "%.2f", t.amount)) \(t.category ?? "") tags=\(tagIDs.count)")
                    if let c = t.category { store.remember(merchant: t.merchant, categoryName: c) }
                }
                log("Done. Imported \(imported) transactions.")
            } else {
                log("ERROR: Unable to decode image from picked data.")
            }
        } catch {
            log("ERROR: handleSelectedPhoto failed: \(error.localizedDescription)")
        }
    }
    
    // (rest of file unchanged below …)
    
    // MARK: - Tiles & helpers
    
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
    
    private struct CardTileContent: View {
        let card: CreditCard
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "creditcard.fill")
                    Text(card.name).font(.headline)
                    Spacer()
                }
                let boostedPairs: Array<(key: String, value: Double)> =
                Array(card.multipliers.sorted { $0.value > $1.value }.prefix(2))
                if boostedPairs.isEmpty {
                    Text(String(format: "Base %.1fx everywhere", card.baseMultiplier))
                        .font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(boostedPairs, id: \.key) { pair in
                        HStack {
                            Text(pair.key)
                            Spacer()
                            Text(String(format: "%.1fx", pair.value)).monospacedDigit()
                        }
                        .font(.footnote).foregroundColor(.secondary)
                    }
                }
                if let note = card.rotatingNote {
                    Text(note).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
    }
    
    private struct CombinedCardControlTile: View {
        let width: CGFloat
        let height: CGFloat
        var onNew: () -> Void
        var onMoveToggle: () -> Void
        var isMoveOn: Bool
        
        var body: some View {
            VStack(spacing: 8) {
                Button(action: onNew) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                        Text("New Card").font(.subheadline).bold()
                        Spacer()
                    }
                    .padding(14)
                    .frame(width: width, height: height/2)
                    .background(Color.purpleWash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.subtleOutline))
                }
                .buttonStyle(.plain)
                
                Button(action: onMoveToggle) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.arrow.down.square").font(.title2)
                        Text(isMoveOn ? "Done Moving" : "Move Cards")
                            .font(.subheadline).bold()
                        Spacer()
                        Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(width: width, height: height/2)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.subtleOutline))
                }
                .buttonStyle(.plain)
            }
            .frame(width: width, height: height)
        }
    }
    
    // File: Views/Cards/CardsView.swift
    // Replace the PurchasePlannerSection with this version (only this type)

    private struct PurchasePlannerSection: View {
        @EnvironmentObject var store: AppStore
        @Binding var naturalText: String
        @Binding var amountString: String
        @Binding var selectedCategoryID: UUID?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe Planned Purchase")
                    .font(.headline)
                TextField("e.g. $60 at Olive Garden for dinner", text: $naturalText)
                    .textInputAutocapitalization(.sentences)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: naturalText) { _, newVal in
                        Task {
                            guard !newVal.isEmpty else { return }
                            let allowedCats = store.categories.map { $0.name }
                            let allowedTags = store.tags.map { $0.name }
                            if let result = try? await ChatGPTService.shared.analyze(
                                text: newVal,
                                allowedCategories: allowedCats,
                                allowedTags: allowedTags
                            ) {
                                if let a = result.total {
                                    amountString = String(format: "%.2f", a)
                                }
                                if let cat = result.category,
                                   let id = store.categoryID(named: cat) {
                                    selectedCategoryID = id
                                }
                            }
                        }
                    }
            }
            .padding(.horizontal)
        }
    }

    
    private struct ReceiptPickerSection: View {
        @Binding var selectedPhoto: PhotosPickerItem?
        @Binding var isAnalyzing: Bool
        @Binding var selectedImage: UIImage?
        @Binding var amountString: String
        @Binding var selectedCategoryID: UUID?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Or Upload Receipt / Screenshot")
                    .font(.headline)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose Image")
                        Spacer()
                        if isAnalyzing { ProgressView() }
                    }
                    .padding()
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.subtleOutline))
                }
                if let img = selectedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal)
        }
    }
    
    private struct DetailsSection: View {
        @EnvironmentObject var store: AppStore
        @Binding var amountString: String
        @Binding var selectedCategoryID: UUID?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Details (Adjust if needed)")
                    .font(.headline)
                Picker("Category", selection: Binding(get: {
                    selectedCategoryID ?? store.categories.first?.id
                }, set: { selectedCategoryID = $0 })) {
                    ForEach(store.categories) { c in
                        Text(c.name).tag(Optional.some(c.id))
                    }
                }
                .pickerStyle(.menu)
                TextField("Amount (e.g. 60)", text: $amountString)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
        }
    }
    
    private struct RecommendedCardCallout: View {
        @EnvironmentObject var store: AppStore
        let parsedAmount: Double
        let selectedCategoryID: UUID?
        
        var body: some View {
            Group {
                if parsedAmount > 0,
                   let catID = selectedCategoryID,
                   let cat = store.categories.first(where: { $0.id == catID }) {
                    let rec = CardRecommender.bestCard(for: cat.name, amount: parsedAmount, from: store.cards)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use This Card").font(.headline)
                        HStack {
                            Image(systemName: "creditcard.fill")
                            VStack(alignment: .leading) {
                                Text(rec.card.name).bold()
                                if let note = rec.card.rotatingNote {
                                    Text(note).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.0fx", rec.mult)).font(.title3.bold())
                        }
                        .padding()
                        .background(.purpleWash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.subtleOutline))
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - DropDelegate
    
    private struct CardsReorderDropDelegate: DropDelegate {
        @Binding var current: CreditCard?
        let item: CreditCard
        let getItems: () -> [CreditCard]
        let move: (_ from: Int, _ to: Int) -> Void
        let persist: () -> Void
        
        func dropEntered(info: DropInfo) {
            guard let dragging = current,
                  dragging != item,
                  let from = getItems().firstIndex(where: { $0.id == dragging.id }),
                  let to = getItems().firstIndex(where: { $0.id == item.id })
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
}

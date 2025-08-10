// File: Views/Budget/AddPurchaseSheet.swift
// Add multiple purchases at once with tags. Fix: replace seeded empty manual row with first camera/photo import.

import SwiftUI
import PhotosUI
import UIKit

private struct DraftPurchase: Identifiable, Equatable {
    let id: UUID
    var merchant: String
    var amountString: String
    var selectedCategoryID: UUID?
    var notes: String
    var date: Date
    var selectedTagIDs: Set<UUID>       // NEW: chosen tags for this draft line

    init(
        id: UUID = UUID(),
        merchant: String = "",
        amountString: String = "",
        selectedCategoryID: UUID? = nil,
        notes: String = "",
        date: Date = Date(),
        selectedTagIDs: Set<UUID> = []
    ) {
        self.id = id
        self.merchant = merchant
        self.amountString = amountString
        self.selectedCategoryID = selectedCategoryID
        self.notes = notes
        self.date = date
        self.selectedTagIDs = selectedTagIDs
    }

    var amount: Double {
        Double(amountString.filter { "0123456789.-".contains($0) }) ?? 0
    }

    var isValid: Bool {
        amount > 0
    }
}

struct AddPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore

    // Image import
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var showCamera = false

    // Multiple draft rows
    @State private var drafts: [DraftPurchase] = []
    @State private var seededEmptyRow = false     // NEW: track if we added the initial placeholder row

    // Tag picker presentation
    @State private var showTagPickerForDraftID: UUID?
    
    // Debug lines
    @State private var debugLines: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Camera + Photo Import
                    HStack(spacing: 10) {
                        Button {
                            showCamera = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                Text("Take Picture")
                                Spacer()
                                Image(systemName: "sparkles")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.purpleWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.subtleOutline))
                        }
                        .buttonStyle(.plain)

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text(isAnalyzing ? "Analyzing…" : "Choose Image")
                                Spacer()
                                if isAnalyzing { ProgressView() }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.subtleOutline))
                        }
                        .buttonStyle(.plain)
                    }

                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Manual section header with "+" to add rows
                    HStack {
                        Text("Manual Entries").font(.headline)
                        Spacer()
                        Button {
                            let catID = store.categoryID(named: "Other") ?? store.categories.first?.id
                            drafts.append(DraftPurchase(selectedCategoryID: catID))
                        } label: {
                            Label("Add Line", systemImage: "plus.circle.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        .accessibilityIdentifier("AddManualLineButton")
                    }

                    // Draft list editor
                    VStack(spacing: 12) {
                        if drafts.isEmpty {
                            Text("No draft purchases yet. Add some manually or import from a receipt/statement image.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach($drafts) { $draft in
                                DraftRow(
                                    draft: $draft,
                                    categories: store.categories,
                                    allTags: store.tags,
                                    onDelete: {
                                        if let idx = drafts.firstIndex(where: { $0.id == draft.id }) {
                                            drafts.remove(at: idx)
                                        }
                                    },
                                    onAddTags: {
                                        showTagPickerForDraftID = draft.id
                                    }
                                )
                                .sheet(item: Binding.constant(showTagPickerForDraftID == draft.id ? draft : nil), onDismiss: {
                                    showTagPickerForDraftID = nil
                                }) { _ in
                                    TagPickerSheet(
                                        selected: Binding(
                                            get: { draft.selectedTagIDs },
                                            set: { draft.selectedTagIDs = $0 }
                                        )
                                    )
                                    .environmentObject(store)
                                }
                            }
                        }
                    }

                    // Debug console
                    DebugConsoleView(title: "ChatGPT Debug (Add Purchase)", lines: $debugLines)
                }
                .padding()
            }
            .navigationTitle("Add Purchases")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save All") {
                        saveAll()
                    }
                    .disabled(!drafts.contains(where: { $0.isValid }))
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $selectedImage).ignoresSafeArea()
            }
            .task(id: selectedPhoto) { await handleSelectedPhoto() }
            .onChange(of: selectedImage) { _, newImg in
                guard let img = newImg else { return }
                Task { await analyzeImageToDrafts(img) }
            }
            .onAppear {
                // Start with one empty manual row for convenience, mark it as seeded
                if drafts.isEmpty {
                    let catID = store.categoryID(named: "Other") ?? store.categories.first?.id
                    drafts = [DraftPurchase(selectedCategoryID: catID)]
                    seededEmptyRow = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func log(_ s: String) {
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
                await analyzeImageToDrafts(img)
            } else {
                log("ERROR: unable to decode image from picked data.")
            }
        } catch {
            log("ERROR: handleSelectedPhoto failed: \(error.localizedDescription)")
        }
    }

    private func analyzeImageToDrafts(_ image: UIImage) async {
        if isAnalyzing == false { isAnalyzing = true }
        defer { isAnalyzing = false }
        do {
            let allowedCats = store.categories.map { $0.name }
            // let allowedTags = store.tags.map { $0.name } // not needed for this call in this target

            let txns = try await ChatGPTService.shared.analyzeTransactions(
                image: image,
                log: { self.log($0) },
                allowedCategories: allowedCats
            )

            if txns.isEmpty { log("No transactions parsed."); return }

            // FIX: if we seeded a single empty manual row, replace it instead of leaving it behind
            if seededEmptyRow,
               drafts.count == 1,
               drafts[0].merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               drafts[0].isValid == false {
                drafts.removeAll()
                seededEmptyRow = false
            }
            
            var added = 0
            for t in txns {
                guard t.amount > 0 else { continue }
                let catID: UUID? = {
                    if let c = t.category, let id = store.categoryID(named: c) { return id }
                    return store.categoryID(named: "Other") ?? store.categories.first?.id
                }()
                let date = parseDateISO(t.date) ?? Date()
//                let tagIDs = (t.tags ?? []).compactMap { store.tagID(named: $0) }
                drafts.append(DraftPurchase(
                    merchant: t.merchant,
                    amountString: String(format: "%.2f", t.amount),
                    selectedCategoryID: catID,
                    notes: "",
                    date: date
//                    selectedTagIDs: Set(tagIDs)
                ))
                added += 1
            }
            log("Created \(added) draft line(s) from image.")
        } catch {
            log("ERROR: analyzeTransactions() failed: \(error.localizedDescription)")
        }
    }

    private func saveAll() {
        var saved = 0
        for d in drafts where d.isValid {
            let p = Purchase(
                date: d.date,
                merchant: d.merchant.isEmpty ? "Unknown" : d.merchant,
                amount: d.amount,
                categoryID: d.selectedCategoryID,
                notes: d.notes.isEmpty ? nil : d.notes,
                ocrText: nil,
                tagIDs: Array(d.selectedTagIDs) // NEW
            )
            store.addPurchase(p)
            if !d.merchant.isEmpty,
               let catName = store.categories.first(where: { $0.id == d.selectedCategoryID })?.name {
                store.remember(merchant: d.merchant, categoryName: catName)
            }
            saved += 1
        }
        log("Saved \(saved) purchase(s).")
        dismiss()
    }
}

// MARK: - Draft Row UI

private struct DraftRow: View {
    @Binding var draft: DraftPurchase
    let categories: [CategoryItem]
    let allTags: [Tag]
    var onDelete: () -> Void
    var onAddTags: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Merchant", text: $draft.merchant)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityIdentifier("DeleteDraftRowButton")
            }

            HStack(spacing: 12) {
                TextField("Amount (e.g. 23.45)", text: Binding(
                    get: { draft.amountString },
                    set: { draft.amountString = $0.filter { "0123456789.-".contains($0) } }
                ))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

                Picker("Category", selection: Binding(
                    get: { draft.selectedCategoryID ?? categories.first?.id },
                    set: { draft.selectedCategoryID = $0 }
                )) {
                    ForEach(categories) { c in
                        Text(c.name).tag(Optional.some(c.id))
                    }
                }
                .pickerStyle(.menu)
            }

            // Tags row
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Tags").font(.subheadline)
                    Spacer()
                    Button {
                        onAddTags()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Tags")
                        }
                    }
                }
                if draft.selectedTagIDs.isEmpty {
                    Text("No tags").foregroundColor(.secondary).font(.footnote)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(draft.selectedTagIDs), id: \.self) { tid in
                                let name = allTags.first(where: { $0.id == tid })?.name ?? "Tag"
                                Text(name)
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.cardBackground)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(.subtleOutline))
                            }
                        }
                    }
                }
            }

            TextField("Notes (optional)", text: $draft.notes)
                .textFieldStyle(.roundedBorder)

            DatePicker("Date", selection: $draft.date, displayedComponents: [.date])
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.subtleOutline))
    }
}


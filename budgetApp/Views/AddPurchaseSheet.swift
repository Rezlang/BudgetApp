// File: Views/Budget/AddPurchaseSheet.swift
// Add purchase: Take Picture + Choose Image + Manual section
// Purple accents applied

import SwiftUI
import PhotosUI
import UIKit

struct AddPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var ocrText: String = ""
    @State private var isOCRRunning = false
    @State private var showCamera = false
    
    // Manual fields
    @State private var merchant: String = ""
    @State private var amountString: String = ""
    @State private var notes: String = ""
    @State private var selectedCategoryID: UUID? = nil
    
    var parsedAmount: Double? { Double(amountString.filter { "0123456789.".contains($0) }) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                        .background(.purpleWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.subtleOutline))
                    }
                    
                    Text("Or Upload Receipt / Screenshot")
                        .font(.headline)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose Image")
                            Spacer()
                            if isOCRRunning { ProgressView() }
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
                        if !ocrText.isEmpty {
                            DisclosureGroup("Extracted Text (OCR)") {
                                Text(ocrText).font(.footnote).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Group {
                        Text("Manual").font(.headline)
                        TextField("Merchant", text: $merchant)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: merchant) { _, _ in updateSuggestedCategoryFromCurrent() }
                        TextField("Amount (e.g. 23.45)", text: $amountString)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Picker("Category", selection: Binding(
                            get: { selectedCategoryID ?? store.categoryID(named: "Other") },
                            set: { selectedCategoryID = $0 }
                        )) {
                            ForEach(store.categories) { c in
                                Text(c.name).tag(Optional.some(c.id))
                            }
                        }
                        .pickerStyle(.menu)
                        TextField("Notes (optional)", text: $notes)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    if let catID = selectedCategoryID,
                       let cat = store.categories.first(where: { $0.id == catID }),
                       let amt = parsedAmount, amt > 0 {
                        let rec = CardRecommender.bestCard(for: cat.name, amount: amt, from: store.cards)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended Card").font(.headline)
                            HStack {
                                Image(systemName: "creditcard.fill")
                                Text(rec.card.name).bold()
                                Spacer()
                                Text(String(format: "%.0fx", rec.mult))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(.purpleWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.subtleOutline))
                    }
                }
                .padding()
            }
            .navigationTitle("Add Purchase")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let amt = parsedAmount ?? 0
                        let p = Purchase(
                            merchant: merchant.isEmpty ? "Unknown" : merchant,
                            amount: amt,
                            categoryID: selectedCategoryID,
                            notes: notes.isEmpty ? nil : notes,
                            ocrText: ocrText.isEmpty ? nil : ocrText
                        )
                        store.addPurchase(p)
                        if !merchant.isEmpty, let catName = store.categories.first(where: { $0.id == selectedCategoryID })?.name {
                            store.remember(merchant: merchant, categoryName: catName)
                        }
                        dismiss()
                    }
                    .disabled((parsedAmount ?? 0) <= 0)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $selectedImage).ignoresSafeArea()
            }
            .task(id: selectedPhoto) { await handleSelectedPhoto() }
            .onChange(of: selectedImage) { _, newImg in
                guard let img = newImg else { return }
                Task { await runOCR(on: img) }
            }
            .onAppear {
                selectedCategoryID = selectedCategoryID ?? store.categoryID(named: "Other") ?? store.categories.first?.id
            }
        }
    }
    
    private func updateSuggestedCategoryFromCurrent() {
        let suggestedName = CategoryRecommender.suggestCategoryName(
            merchant: merchant, ocrText: ocrText,
            memory: store.categoryMemory,
            available: store.categories
        )
        if let id = store.categoryID(named: suggestedName) {
            selectedCategoryID = id
        }
    }
    
    private func handleSelectedPhoto() async {
        guard let item = selectedPhoto else { return }
        isOCRRunning = true
        defer { isOCRRunning = false }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                selectedImage = img
                await runOCR(on: img)
            }
        } catch { }
    }
    private func runOCR(on image: UIImage) async {
        do {
            let text = try await OCRService.shared.recognizeText(from: image)
            ocrText = text
            if merchant.isEmpty, let guessM = guessMerchant(from: text) { merchant = guessM }
            if (parsedAmount ?? 0) == 0, let amt = guessAmount(from: text) { amountString = String(format: "%.2f", amt) }
            updateSuggestedCategoryFromCurrent()
        } catch { }
    }
    
    private func guessMerchant(from text: String) -> String? {
        for raw in text.split(separator: "\n").map(String.init) {
            let lower = raw.lowercased()
            if lower.range(of: #"[0-9]{1,2}/[0-9]{1,2}"#, options: .regularExpression) != nil { continue }
            if lower.range(of: #"\$?\s*[0-9]+(?:\.[0-9]{1,2})?"#, options: .regularExpression) != nil { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count >= 3 { return trimmed }
        }
        return nil
    }
    private func guessAmount(from text: String) -> Double? {
        let lower = text.lowercased()
        let regex = try? NSRegularExpression(pattern: #"\$?\s*([0-9]+(?:\.[0-9]{1,2})?)"#)
        let matches = regex?.matches(in: lower, range: NSRange(lower.startIndex..., in: lower)) ?? []
        if matches.isEmpty { return nil }
        if let _ = lower.range(of: "total"),
           let m = matches.last,
           let r = Range(m.range(at: 1), in: lower) { return Double(lower[r]) }
        if let m = matches.last, let r = Range(m.range(at: 1), in: lower) { return Double(lower[r]) }
        return nil
    }
}

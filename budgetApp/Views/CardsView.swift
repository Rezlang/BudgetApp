// File: Views/Cards/CardsView.swift
// Credit card recommendation page with purple accents

import SwiftUI
import PhotosUI
import UIKit

struct CardsView: View {
    @EnvironmentObject var store: AppStore
    @State private var amountString: String = ""
    @State private var naturalText: String = ""
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var ocrText: String = ""
    @State private var isOCRRunning = false
    @State private var selectedCategoryID: UUID?
    
    var parsedAmount: Double { Double(amountString.filter { "0123456789.".contains($0) }) ?? 0 }
    var inferredMerchant: String? {
        let parsed = PurchaseParser.parse(naturalText)
        if let m = parsed.merchant { return m }
        if !ocrText.isEmpty {
            return ocrText.split(separator: "\n").first.map(String.init)
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Describe Planned Purchase")
                        .font(.headline)
                    TextField("e.g. $60 at Olive Garden for dinner", text: $naturalText)
                        .textInputAutocapitalization(.sentences)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: naturalText) { _, newVal in
                            let parsed = PurchaseParser.parse(newVal)
                            if let a = parsed.amount {
                                amountString = String(format: "%.2f", a)
                            }
                            let suggestedName = CategoryRecommender.suggestCategoryName(
                                merchant: parsed.merchant, ocrText: parsed.notes,
                                memory: store.categoryMemory, available: store.categories
                            )
                            selectedCategoryID = store.categoryID(named: suggestedName) ?? store.categories.first?.id
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
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
                }
                
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
                
                if parsedAmount > 0,
                   let catID = selectedCategoryID,
                   let cat = store.categories.first(where: {$0.id == catID}) {
                    let rec = CardRecommender.bestCard(for: cat.name, amount: parsedAmount, from: store.cards)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use This Card")
                            .font(.headline)
                        HStack {
                            Image(systemName: "creditcard.fill")
                            VStack(alignment: .leading) {
                                Text(rec.card.name).bold()
                                if let note = rec.card.rotatingNote {
                                    Text(note).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(String(format: "%.0fx", rec.mult))
                                .font(.title3.bold())
                        }
                        .padding()
                        .background(.purpleWash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.subtleOutline))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Quick Compare")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(store.cards) { card in
                                let mult = card.multipliers[cat.name] ?? card.baseMultiplier
                                HStack {
                                    Text(card.name)
                                    Spacer()
                                    Text(String(format: "%.0fx", mult))
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Credit Cards")
        .task(id: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            isOCRRunning = true
            defer { isOCRRunning = false }
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    selectedImage = img
                    let text = try await OCRService.shared.recognizeText(from: img)
                    ocrText = text
                    if amountString.isEmpty, let amt = guessAmount(from: text) {
                        amountString = String(format: "%.2f", amt)
                    }
                    let merch = guessMerchant(from: text)
                    let suggName = CategoryRecommender.suggestCategoryName(
                        merchant: merch, ocrText: text,
                        memory: store.categoryMemory, available: store.categories
                    )
                    selectedCategoryID = store.categoryID(named: suggName) ?? store.categories.first?.id
                }
            } catch { }
        }
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

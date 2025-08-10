// File: Views/Budget/PurchaseEditorSheet.swift
// Create or edit a Purchase with modern styling (purple accents)

import SwiftUI

struct PurchaseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    
    /// Pass an existing purchase to edit; nil to create a new one.
    var purchase: Purchase?
    /// Called when user taps Save. You decide whether to add/update in the caller.
    var onSave: (Purchase) -> Void
    /// Optional delete handler. If provided and we're editing, a Delete button will appear.
    var onDelete: (() -> Void)? = nil
    
    // Editable state
    @State private var merchant: String = ""
    @State private var amountString: String = ""
    @State private var selectedCategoryID: UUID?
    @State private var date: Date = Date()
    @State private var notes: String = ""
    
    private var parsedAmount: Double? {
        Double(amountString.filter { "0123456789.".contains($0) })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Merchant", text: $merchant)
                        .textInputAutocapitalization(.words)
                    TextField("Amount", text: $amountString)
                        .keyboardType(.decimalPad)
                    
                    Picker("Category", selection: Binding(
                        get: { selectedCategoryID ?? store.categoryID(named: "Other") ?? store.categories.first?.id },
                        set: { selectedCategoryID = $0 }
                    )) {
                        ForEach(store.categories) { c in
                            Text(c.name).tag(Optional.some(c.id))
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Notes")) {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                
                if let catID = selectedCategoryID,
                   let cat = store.categories.first(where: { $0.id == catID }),
                   let amt = parsedAmount, amt > 0 {
                    let rec = CardRecommender.bestCard(for: cat.name, amount: amt, from: store.cards)
                    Section {
                        HStack {
                            Image(systemName: "creditcard.fill")
                            Text(rec.card.name).bold()
                            Spacer()
                            Text(String(format: "%.0fx", rec.mult))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Recommended Card")
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.purpleWash)
                    )
                }
                
                if purchase != nil, let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Delete Purchase", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(purchase == nil ? "New Purchase" : "Edit Purchase")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let model = Purchase(
                            id: purchase?.id ?? UUID(),
                            date: date,
                            merchant: merchant.isEmpty ? "Unknown" : merchant,
                            amount: parsedAmount ?? 0,
                            categoryID: selectedCategoryID,
                            notes: notes.isEmpty ? nil : notes,
                            ocrText: purchase?.ocrText
                        )
                        onSave(model)
                        // Remember merchant -> category for future suggestions
                        if !merchant.isEmpty,
                           let catName = store.categories.first(where: { $0.id == selectedCategoryID })?.name {
                            store.remember(merchant: merchant, categoryName: catName)
                        }
                        dismiss()
                    }
                    .disabled((parsedAmount ?? 0) <= 0)
                }
            }
            .scrollContentBackground(.automatic)
            .onAppear {
                if let p = purchase {
                    merchant = p.merchant
                    amountString = String(format: "%.2f", p.amount)
                    selectedCategoryID = p.categoryID ?? store.categoryID(named: "Other") ?? store.categories.first?.id
                    date = p.date
                    notes = p.notes ?? ""
                } else {
                    selectedCategoryID = store.categoryID(named: "Other") ?? store.categories.first?.id
                }
            }
        }
    }
}

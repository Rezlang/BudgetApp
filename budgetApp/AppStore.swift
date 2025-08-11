// FILE: BudgetApp/Store/AppStore.swift
// Persistence and in-memory store

import Foundation
import SwiftUI

final class AppStore: ObservableObject {
    @AppStorage("purchases_json") private var purchasesJSON: String = "[]"
    @AppStorage("budget_json") private var budgetJSON: String = ""
    @AppStorage("cards_json") private var cardsJSON: String = ""
    @AppStorage("categories_json") private var categoriesJSON: String = ""
    @AppStorage("category_memory_json") private var categoryMemoryJSON: String = "{}"
    @AppStorage("tags_json") private var tagsJSON: String = "[]"
    
    @Published var purchases: [Purchase] = []
    @Published var budget: BudgetEnvelope = .default
    @Published var cards: [CreditCard] = AppStore.defaultCards
    @Published var categories: [CategoryItem] = AppStore.defaultCategories
    @Published var categoryMemory: [String: String] = [:]
    @Published var tags: [Tag] = []
    
    static let defaultCategories: [CategoryItem] = [
        CategoryItem(name: "Groceries", limit: 400),
        CategoryItem(name: "Dining", limit: 250),
        CategoryItem(name: "Travel", limit: 300),
        CategoryItem(name: "Gas", limit: 150),
        CategoryItem(name: "Transit", limit: 100),
        CategoryItem(name: "Entertainment", limit: 150),
        CategoryItem(name: "Online Shopping", limit: 200),
        CategoryItem(name: "Bills", limit: 400),
        CategoryItem(name: "Health", limit: 120),
        CategoryItem(name: "Home", limit: 200),
        CategoryItem(name: "Other", limit: 100)
    ]
    
    static let defaultCards: [CreditCard] = [
        CreditCard(name: "Savor Max",
                   multipliers: ["Dining": 4, "Entertainment": 3, "Groceries": 2],
                   baseMultiplier: 1),
        CreditCard(name: "Freedom Flexy",
                   multipliers: ["Gas": 3, "Transit": 3, "Online Shopping": 3],
                   baseMultiplier: 1,
                   rotatingNote: "Rotating 5x categories quarterly."),
        CreditCard(name: "Everyday Grocer",
                   multipliers: ["Groceries": 3, "Health": 2],
                   baseMultiplier: 1),
        CreditCard(name: "Travel Pro",
                   multipliers: ["Travel": 3, "Dining": 2, "Transit": 2],
                   baseMultiplier: 1),
        CreditCard(name: "Flat 2%",
                   multipliers: [:],
                   baseMultiplier: 2)
    ]
    
    init() { load() }
    
    func load() {
        purchases = decode([Purchase].self, from: purchasesJSON) ?? []
        if let b = decode(BudgetEnvelope.self, from: budgetJSON) { budget = b }
        if let c = decode([CreditCard].self, from: cardsJSON), !c.isEmpty { cards = c }
        if let cats = decode([CategoryItem].self, from: categoriesJSON), !cats.isEmpty { categories = cats }
        categoryMemory = decode([String: String].self, from: categoryMemoryJSON) ?? [:]
        tags = decode([Tag].self, from: tagsJSON) ?? []
    }
    
    func persist() {
        purchasesJSON = encode(purchases) ?? "[]"
        budgetJSON = encode(budget) ?? ""
        cardsJSON = encode(cards) ?? ""
        categoriesJSON = encode(categories) ?? ""
        categoryMemoryJSON = encode(categoryMemory) ?? "{}"
        tagsJSON = encode(tags) ?? "[]"
    }
    
    // Purchases
    func addPurchase(_ p: Purchase) { purchases.insert(p, at: 0); persist() }
    func deletePurchase(_ p: Purchase) { purchases.removeAll { $0.id == p.id }; persist() }
    
    // Categories
    func addCategory(name: String, limit: Double) {
        categories.append(CategoryItem(name: name, limit: limit))
        persist()
    }
    func updateCategory(_ item: CategoryItem) {
        if let idx = categories.firstIndex(where: { $0.id == item.id }) {
            categories[idx] = item
            persist()
        }
    }
    func moveCategory(from offsets: IndexSet, to offset: Int) {
        categories.move(fromOffsets: offsets, toOffset: offset)
        persist()
    }
    
    // Merchant memory
    func remember(merchant: String, categoryName: String) {
        let key = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        categoryMemory[key] = categoryName
        persist()
    }
    
    // MARK: - TAGS
    
    @discardableResult
    func addTag(name: String) -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = tags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let t = Tag(name: trimmed.isEmpty ? "Tag" : trimmed)
        tags.append(t)
        persist()
        return t
    }
    
    func tagName(for id: UUID) -> String {
        tags.first(where: { $0.id == id })?.name ?? "Tag"
    }
    
    func tagID(named name: String) -> UUID? {
        tags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.id
    }
    
    // Helpers
    private func encode<T: Encodable>(_ value: T) -> String? {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(value) { return String(data: data, encoding: .utf8) }
        return nil
    }
    private func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        guard let data = string.data(using: .utf8) else { return nil }
        return try? dec.decode(type, from: data)
    }
    
    // Lookup helpers
    func categoryName(for id: UUID?) -> String {
        guard let id, let cat = categories.first(where: { $0.id == id }) else { return "Uncategorized" }
        return cat.name
    }
    func categoryID(named name: String) -> UUID? {
        categories.first(where: { $0.name.lowercased() == name.lowercased() })?.id
    }
    
    func category(for id: UUID?) -> CategoryItem? {
        guard let id else { return nil }
        return categories.first(where: { $0.id == id })
    }

    func color(for category: CategoryItem) -> Color {
        if let hex = category.iconColorHex, let c = Color(hex: hex) {
            return c
        }
        return Color.stableRandom(for: category.id)
    }

    // MARK: - CLEAR / RESET

    func clearPurchasesAndBudgets() {
        purchases.removeAll()
        budget = .default
        categories = AppStore.defaultCategories
        categoryMemory = [:]
        persist()
    }
}

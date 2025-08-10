// File: Logic/Recommenders.swift
// Category and card recommendation + lightweight NLP

import Foundation

struct CategoryRecommender {
    static let keywordHints: [(name: String, hints: [String])] = [
        ("Groceries", ["kroger","safeway","whole foods","aldi","trader joe","publix","costco","grocery"]),
        ("Dining", ["starbucks","mcdonald","taco bell","chipotle","pizza","cafe","restaurant","dunkin"]),
        ("Travel", ["airlines","delta","united","southwest","jetblue","hotel","marriott","hilton","airbnb","flight"]),
        ("Gas", ["shell","chevron","bp","exxon","mobil","gas station","fuel"]),
        ("Transit", ["uber","lyft","metro","subway","train","mta","bart","bus"]),
        ("Entertainment", ["netflix","movie","amc","concert","ticketmaster","cinema","theater"]),
        ("Online Shopping", ["amazon","etsy","shein","temu","ebay","online"]),
        ("Bills", ["comcast","verizon","att","t-mobile","electric","water","utility","insurance","internet"]),
        ("Health", ["walgreens","cvs","rite aid","pharmacy","dental","clinic"]),
        ("Home", ["home depot","lowe","ikea","wayfair","furniture"])
    ]
    
    static func suggestCategoryName(
        merchant: String?,
        ocrText: String?,
        memory: [String: String],
        available: [CategoryItem]
    ) -> String {
        if let m = merchant?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           let remembered = memory[m] { return remembered }
        let hay = (merchant ?? "" + " " + (ocrText ?? "")).lowercased()
        for (name, hints) in keywordHints {
            if hints.contains(where: { hay.contains($0) }) {
                return name
            }
        }
        if hay.contains("ticket") { return "Entertainment" }
        if hay.contains("pharmacy") { return "Health" }
        if hay.contains("utility") { return "Bills" }
        return available.first(where: { $0.name.lowercased() == "other" })?.name ?? (available.first?.name ?? "Other")
    }
}

struct CardRecommender {
    static func bestCard(for categoryName: String, amount: Double, from cards: [CreditCard]) -> (card: CreditCard, mult: Double, estPoints: Double) {
        var best: (CreditCard, Double, Double)? = nil
        for card in cards {
            let mult = card.multipliers[categoryName] ?? card.baseMultiplier
            let pts = amount * mult
            if best == nil || pts > best!.2 { best = (card, mult, pts) }
        }
        let fallback = cards.first!
        return best ?? (fallback, fallback.baseMultiplier, amount * fallback.baseMultiplier)
    }
}

struct PurchaseParser {
    static func parse(_ text: String) -> (merchant: String?, amount: Double?, notes: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, nil, nil) }
        let lower = trimmed.lowercased()
        var amount: Double? = nil
        if let moneyMatch = try? NSRegularExpression(pattern: #"(?i)\$?\s*([0-9]+(?:\.[0-9]{1,2})?)"#)
            .firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let r = Range(moneyMatch.range(at: 1), in: lower) {
            amount = Double(lower[r])
        }
        var merchant: String? = nil
        if let atRange = lower.range(of: " at ") {
            let after = String(trimmed[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            merchant = after.split(separator: " ").prefix(3).joined(separator: " ")
        } else {
            merchant = trimmed.split(separator: " ").first.map(String.init)
        }
        var notes: String? = nil
        if let forRange = lower.range(of: " for ") {
            notes = String(trimmed[forRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return (merchant, amount, notes)
    }
}

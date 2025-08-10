// File: Models/Models.swift
// Data models

import Foundation

struct CategoryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var limit: Double
}

struct Tag: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
}

struct Purchase: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var merchant: String
    var amount: Double
    var categoryID: UUID?
    var notes: String?
    var ocrText: String?
    var tagIDs: [UUID]          // NEW: associated tags (does not create budgets)

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        merchant: String,
        amount: Double,
        categoryID: UUID?,
        notes: String? = nil,
        ocrText: String? = nil,
        tagIDs: [UUID] = []
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.amount = amount
        self.categoryID = categoryID
        self.notes = notes
        self.ocrText = ocrText
        self.tagIDs = tagIDs
    }
}

struct BudgetEnvelope: Codable, Equatable {
    var overallLimit: Double
    static let `default` = BudgetEnvelope(overallLimit: 2000)
}

/// Credit card multipliers keyed by category name (string)
struct CreditCard: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var multipliers: [String: Double]
    var baseMultiplier: Double
    var rotatingNote: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        multipliers: [String : Double],
        baseMultiplier: Double = 1.0,
        rotatingNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.multipliers = multipliers
        self.baseMultiplier = baseMultiplier
        self.rotatingNote = rotatingNote
    }
}

// File: Logic/Recommenders.swift
// Card recommendation helpers

import Foundation

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

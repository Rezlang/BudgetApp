// FILE: BudgetApp/Services/ChatGPTService.swift
// Multi-transaction extraction with category control + robust tags

import Foundation
import UIKit
import os

struct ReceiptAnalysis: Decodable {
    let merchant: String?
    let total: Double?
    let category: String?
    let recommendedCard: String?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case merchant, total, category, tags
        case recommendedCard = "recommended_card"
    }
}

struct ReceiptTransaction: Decodable {
    let merchant: String
    let amount: Double
    let category: String?
    let date: String?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case merchant, category, date, tags
        case amount
        case total
    }

    init(merchant: String, amount: Double, category: String?, date: String?, tags: [String]? = nil) {
        self.merchant = merchant
        self.amount = amount
        self.category = category
        self.date = date
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.merchant = (try? c.decode(String.self, forKey: .merchant)) ?? "Unknown"

        if let a = try? c.decode(Double.self, forKey: .amount) {
            self.amount = a
        } else if let t = try? c.decode(Double.self, forKey: .total) {
            self.amount = t
        } else if let s = try? c.decode(String.self, forKey: .amount),
                  let v = Double(s.filter { "0123456789.-".contains($0) }) {
            self.amount = v
        } else if let s = try? c.decode(String.self, forKey: .total),
                  let v = Double(s.filter { "0123456789.-".contains($0) }) {
            self.amount = v
        } else {
            self.amount = 0
        }

        self.category = try? c.decode(String.self, forKey: .category)
        self.date = try? c.decode(String.self, forKey: .date)

        if let arr = try? c.decode([String].self, forKey: .tags) {
            self.tags = arr
        } else if let single = try? c.decode(String.self, forKey: .tags) {
            self.tags = [single]
        } else {
            self.tags = nil
        }
    }
}

private struct TxnEnvelope: Decodable { let transactions: [ReceiptTransaction] }

final class ChatGPTService {
    static let shared = ChatGPTService()
    private init() {}

    private let logger = Logger(subsystem: "BudgetApp", category: "ChatGPTService")

    // MARK: - Single result (kept for planner text flow)
    func analyze(
        image: UIImage? = nil,
        text: String? = nil,
        log: ((String)->Void)? = nil,
        allowedCategories: [String]? = nil,
        allowedTags: [String] = []
    ) async throws -> ReceiptAnalysis {
        func stamp(_ s: String) { let line = "\(Self.ts()) \(s)"; log?(line); print(line); logger.debug("\(line)") }
        stamp("BEGIN analyze(image:\(image != nil), text:\(text?.isEmpty == false))")

        var userContent: [[String: Any]] = []
        if let text, !text.isEmpty {
            userContent.append(["type": "text", "text": text])
            stamp("Text included. length=\(text.count)")
        }
        if let image {
            let prepared = image.preparedForUpload(maxDimension: 1024, quality: 0.65)
            if let data = prepared.jpegData {
                let b64 = data.base64EncodedString()
                userContent.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]])
                let kb = Double(data.count) / 1024.0
                stamp(String(format: "Image included. size=%.1f KB, dims=%dx%d", kb, Int(prepared.size.width), Int(prepared.size.height)))
            } else { stamp("WARN: provided image could not be JPEG-encoded.") }
        }

        let closedSet = (allowedCategories ?? []).joined(separator: ", ")

        let tagClause: String = {
            if allowedTags.isEmpty {
                // When the app has no tags yet, allow from a sane default palette so we can auto-create them.
                return """
                Tags are optional. If helpful, choose up to 2 tags from this set (case-insensitive):
                [work, reimbursable, subscription, gift, vacation, business, personal, family, urgent, recurring]
                If no tags apply, return an empty array.
                """
            } else {
                let tagSet = allowedTags.joined(separator: ", ")
                return """
                Tags are optional. If any apply, choose only from this list (case-insensitive):
                [\(tagSet)]
                If no tags apply, return an empty array.
                """
            }
        }()

        let system = """
        You are a budgeting assistant. Return ONE JSON OBJECT ONLY (no markdown).
        Keys: merchant (string), total (number), category (string), recommended_card (string), tags ([string]).

        Category must be chosen ONLY from this closed set (case-insensitive, return the exact label as written):
        [\(closedSet)]

        \(tagClause)

        If ambiguous between travel-related food and restaurant, prefer "Dining".
        If a merchant looks like a supermarket/market/grocer, prefer "Groceries".
        Use "Other" only when none clearly apply.
        """
        let messages: [[String: Any]] = [
            ["role": "system", "content": system],
            ["role": "user", "content": userContent]
        ]

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "response_format": ["type": "json_object"]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization"); stamp("Auth: using API key from environment")
        } else { stamp("ERROR: OPENAI_API_KEY not found in environment. Set it in Scheme > Run > Environment Variables.") }

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = body
            stamp("Payload prepared. bytes=\(body.count), model=gpt-4o-mini")
        } catch { stamp("ERROR: JSONSerialization failed: \(error.localizedDescription)"); throw error }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            stamp("HTTP status=\(status)")
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            stamp("Raw response:\n\(raw)")
            guard (200...299).contains(status) else { throw URLError(.badServerResponse) }

            let api = try JSONDecoder().decode(ChatAPIResponse.self, from: data)
            var content = api.choices.first?.message.content ?? "{}"
            content = extractFirstJSON(from: content)
            var analysis = try JSONDecoder().decode(ReceiptAnalysis.self, from: Data(content.utf8))

            if let allowed = allowedCategories {
                analysis = normalizeSingle(analysis, allowed: allowed)
            }

            stamp("DECODE OK: merchant=\(analysis.merchant ?? "nil"), total=\(analysis.total?.description ?? "nil"), category=\(analysis.category ?? "nil")")
            stamp("END analyze()")
            return analysis
        } catch { stamp("ERROR: request/parse failed: \(error.localizedDescription)"); throw error }
    }

    // MARK: - Multiple transactions with category + tag guidance
    func analyzeTransactions(
        image: UIImage? = nil,
        text: String? = nil,
        log: ((String)->Void)? = nil,
        allowedCategories: [String],
        allowedTags: [String] = []
    ) async throws -> [ReceiptTransaction] {
        func stamp(_ s: String) { let line = "\(Self.ts()) \(s)"; log?(line); print(line); logger.debug("\(line)") }
        stamp("BEGIN analyzeTransactions(image:\(image != nil), text:\(text?.isEmpty == false))")

        var userContent: [[String: Any]] = []
        if let text, !text.isEmpty {
            userContent.append(["type": "text", "text": text])
            stamp("Text included. length=\(text.count)")
        }
        if let image {
            let prepared = image.preparedForUpload(maxDimension: 1280, quality: 0.7)
            if let data = prepared.jpegData {
                let b64 = data.base64EncodedString()
                userContent.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]])
                let kb = Double(data.count) / 1024.0
                stamp(String(format: "Image included. size=%.1f KB, dims=%dx%d", kb, Int(prepared.size.width), Int(prepared.size.height)))
            } else { stamp("WARN: provided image could not be JPEG-encoded.") }
        }

        let closedSet = allowedCategories.joined(separator: ", ")

        let tagClause: String = {
            if allowedTags.isEmpty {
                return """
                Tags are optional. If helpful, choose up to 2 tags from this set (case-insensitive):
                [work, reimbursable, subscription, gift, vacation, business, personal, family, urgent, recurring]
                If no tags apply, use an empty array.
                """
            } else {
                let tagSet = allowedTags.joined(separator: ", ")
                return """
                Tags are optional. If any apply, choose only from this list (case-insensitive):
                [\(tagSet)]
                If no tags apply, use an empty array.
                """
            }
        }()

        let system = """
        You extract INDIVIDUAL card transactions from statements or app screenshots.
        Ignore any overall totals or running balances. Output JSON ONLY (no markdown).
        Respond as: { "transactions": [ { "merchant": string, "amount": number, "category": string, "date": "YYYY-MM-DD", "tags": [string] } ... ] }

        Category must be chosen ONLY from this closed set (case-insensitive, return the exact label as written):
        [\(closedSet)]

        \(tagClause)

        Ambiguity policy:
        - If a merchant looks like restaurant, cafe, bar, fast food, pizza, sushi, bakery, etc. => choose "Dining" (even if traveling).
        - If a merchant looks like supermarket/grocery/market/whole foods/trader joe's/costco food, etc. => choose "Groceries".
        - Hotels, airlines, car rentals => "Travel".
        - Uber/Lyft/metro/bus/train fares => "Transit".
        - Gas stations => "Gas".
        - If none fit, choose "Other".
        Use positive amounts. Omit any summary lines like "Posted Total".
        Convert visible dates like "Aug 7, 2025" to "2025-08-07"; if not visible, omit date.
        """
        let messages: [[String: Any]] = [
            ["role": "system", "content": system],
            ["role": "user", "content": userContent]
        ]

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "response_format": ["type": "json_object"]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization"); stamp("Auth: using API key from environment")
        } else { stamp("ERROR: OPENAI_API_KEY not found in environment. Set it in Scheme > Run > Environment Variables.") }

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = body
            stamp("Payload prepared. bytes=\(body.count), model=gpt-4o-mini")
        } catch { stamp("ERROR: JSONSerialization failed: \(error.localizedDescription)"); throw error }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            stamp("HTTP status=\(status)")
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            stamp("Raw response:\n\(raw)")
            guard (200...299).contains(status) else { throw URLError(.badServerResponse) }

            let api = try JSONDecoder().decode(ChatAPIResponse.self, from: data)
            var content = api.choices.first?.message.content ?? "{\"transactions\":[]}"
            content = extractFirstJSON(from: content)

            var txns: [ReceiptTransaction] = []
            if let env = try? JSONDecoder().decode(TxnEnvelope.self, from: Data(content.utf8)) {
                txns = env.transactions
            } else if let arr = try? JSONDecoder().decode([ReceiptTransaction].self, from: Data(content.utf8)) {
                txns = arr
            }

            txns = txns.map { t in
                var cat = t.category
                cat = normalizeCategory(cat, allowed: allowedCategories)
                return ReceiptTransaction(merchant: t.merchant, amount: t.amount, category: cat, date: t.date, tags: t.tags)
            }

            stamp("DECODE OK: \(txns.count) transactions (normalized categories).")
            stamp("END analyzeTransactions()")
            return txns
        } catch { stamp("ERROR: request/parse failed: \(error.localizedDescription)"); throw error }
    }

    private static func ts() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func extractFirstJSON(from s: String) -> String {
        var text = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            if let first = text.range(of: "```") {
                let rest = text[first.upperBound...]
                if let end = rest.range(of: "```") {
                    text = String(rest[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        if let objStart = text.firstIndex(of: "{"),
           let objEnd = matchClosing(in: text, from: objStart, open: "{", close: "}") {
            return String(text[objStart...objEnd])
        }
        if let arrStart = text.firstIndex(of: "["),
           let arrEnd = matchClosing(in: text, from: arrStart, open: "[", close: "]") {
            return String(text[arrStart...arrEnd])
        }
        return text
    }

    private func matchClosing(in s: String, from start: String.Index, open: Character, close: Character) -> String.Index? {
        var depth = 0; var i = start
        while i < s.endIndex {
            let ch = s[i]
            if ch == open { depth += 1 }
            else if ch == close { depth -= 1; if depth == 0 { return i } }
            i = s.index(after: i)
        }
        return nil
    }

    private func normalizeCategory(_ cat: String?, allowed: [String]) -> String? {
        guard let c = cat, !c.isEmpty else { return nil }
        if let hit = allowed.first(where: { $0.compare(c, options: .caseInsensitive) == .orderedSame }) {
            return hit
        }
        let lc = c.lowercased()
        let map: [(keys: [String], target: String)] = [
            (["restaurant","food","fast food","cafe","coffee","bar","deli","pizza","sushi","burrito","taco","wing","bbq"], "Dining"),
            (["grocery","grocer","supermarket","market","whole foods","trader joe","aldi","kroger","safeway","stop & shop","wegmans","publix","costco (food)","fairway"], "Groceries"),
            (["hotel","airline","flight","delta","united","american airlines","frontier","jetblue","airbnb","resort","motel","car rental","hertz","avis","budget"], "Travel"),
            (["uber","lyft","subway","metro","bus","train","amtrak","ferry","mta","bart"], "Transit"),
            (["shell","exxon","chevron","bp","mobil","gas"], "Gas"),
        ]
        for entry in map {
            if entry.keys.contains(where: { lc.contains($0) }) {
                if let hit = allowed.first(where: { $0.caseInsensitiveCompare(entry.target) == .orderedSame }) {
                    return hit
                }
                break
            }
        }
        if let other = allowed.first(where: { $0.caseInsensitiveCompare("Other") == .orderedSame }) {
            return other
        }
        return nil
    }

    private func normalizeSingle(_ r: ReceiptAnalysis, allowed: [String]) -> ReceiptAnalysis {
        let cat = normalizeCategory(r.category, allowed: allowed)
        return ReceiptAnalysis(merchant: r.merchant, total: r.total, category: cat, recommendedCard: r.recommendedCard, tags: r.tags)
    }
}

private struct ChatAPIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private extension UIImage {
    struct Prepared { let image: UIImage; let size: CGSize; let jpegData: Data? }
    func preparedForUpload(maxDimension: CGFloat, quality: CGFloat) -> Prepared {
        let w = size.width, h = size.height
        let scale = min(1, maxDimension / max(w, h))
        let newSize = CGSize(width: w * scale, height: h * scale)
        let resized = scale < 1 ? self.resized(to: newSize) : self
        let data = resized.jpegData(compressionQuality: quality)
        return Prepared(image: resized, size: resized.size, jpegData: data)
    }
    func resized(to target: CGSize) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: target, format: fmt).image { _ in
            self.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

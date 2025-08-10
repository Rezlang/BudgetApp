// File: Services/ChatGPTService.swift
// Multi-transaction extraction from statements/receipts + verbose logging

import Foundation
import UIKit
import os

struct ReceiptAnalysis: Decodable {
    let merchant: String?
    let total: Double?
    let category: String?
    let recommendedCard: String?

    enum CodingKeys: String, CodingKey {
        case merchant, total, category
        case recommendedCard = "recommended_card"
    }
}

// New: normalized transaction item
struct ReceiptTransaction: Decodable {
    let merchant: String
    let amount: Double
    let category: String?
    let date: String? // ISO-8601 preferred

    enum CodingKeys: String, CodingKey {
        case merchant, category, date
        case amount
        case total // allow models that still use "total"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        merchant = (try? c.decode(String.self, forKey: .merchant)) ?? "Unknown"
        // prefer "amount", fall back to "total"
        if let a = try? c.decode(Double.self, forKey: .amount) {
            amount = a
        } else if let t = try? c.decode(Double.self, forKey: .total) {
            amount = t
        } else if let s = try? c.decode(String.self, forKey: .amount), let v = Double(s.filter{ "0123456789.-".contains($0) }) {
            amount = v
        } else if let s = try? c.decode(String.self, forKey: .total), let v = Double(s.filter{ "0123456789.-".contains($0) }) {
            amount = v
        } else {
            amount = 0
        }
        category = try? c.decode(String.self, forKey: .category)
        date = try? c.decode(String.self, forKey: .date)
    }
}

// For the json_object response wrapper
private struct TxnEnvelope: Decodable {
    let transactions: [ReceiptTransaction]
}

final class ChatGPTService {
    static let shared = ChatGPTService()
    private init() {}

    private let logger = Logger(subsystem: "BudgetApp", category: "ChatGPTService")

    // Existing single-result method (kept for other flows)
    func analyze(image: UIImage? = nil, text: String? = nil, log: ((String)->Void)? = nil) async throws -> ReceiptAnalysis {
        func stamp(_ s: String) {
            let line = "\(ChatGPTService.ts()) \(s)"
            log?(line); print(line); logger.debug("\(line)")
        }

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
            } else {
                stamp("WARN: provided image could not be JPEG-encoded.")
            }
        }

        let system = """
        You are a budgeting assistant. Return ONE JSON OBJECT ONLY (no markdown).
        Keys: merchant (string), total (number), category (string), recommended_card (string).
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
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            stamp("Auth: using API key from environment")
        } else {
            stamp("ERROR: OPENAI_API_KEY not found in environment. Set it in Scheme > Run > Arguments.")
        }

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = body
            stamp("Payload prepared. bytes=\(body.count), model=gpt-4o-mini")
        } catch {
            stamp("ERROR: JSONSerialization failed: \(error.localizedDescription)")
            throw error
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            stamp("HTTP status=\(status)")
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            stamp("Raw response (first 800 chars):\n\(raw.prefix(800))")
            guard (200...299).contains(status) else { throw URLError(.badServerResponse) }

            let api = try JSONDecoder().decode(ChatAPIResponse.self, from: data)
            var content = api.choices.first?.message.content ?? "{}"
            content = extractFirstJSON(from: content)
            let analysis = try JSONDecoder().decode(ReceiptAnalysis.self, from: Data(content.utf8))
            stamp("DECODE OK: merchant=\(analysis.merchant ?? "nil"), total=\(analysis.total?.description ?? "nil"), category=\(analysis.category ?? "nil")")
            stamp("END analyze()")
            return analysis
        } catch {
            stamp("ERROR: request/parse failed: \(error.localizedDescription)")
            throw error
        }
    }

    // NEW: multi-transaction analyzer. Returns many items from one image.
    func analyzeTransactions(image: UIImage? = nil, text: String? = nil, log: ((String)->Void)? = nil) async throws -> [ReceiptTransaction] {
        func stamp(_ s: String) {
            let line = "\(ChatGPTService.ts()) \(s)"
            log?(line); print(line); logger.debug("\(line)")
        }

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
            } else {
                stamp("WARN: provided image could not be JPEG-encoded.")
            }
        }

        // Instruction: we want ONLY individual transactions; ignore totals/summaries
        let system = """
        You extract INDIVIDUAL card transactions from statements or app screenshots.
        Ignore any overall/posted totals or running balances. Return JSON ONLY (no markdown).
        Respond as an object: { "transactions": [ { "merchant": string, "amount": number, "category": string, "date": "YYYY-MM-DD" } ... ] }
        - "amount" is the line item amount (positive numbers only).
        - If the category isn't obvious, set a reasonable guess (e.g., "Dining", "Transit") or omit.
        - If a date is visible like "Aug 7, 2025", convert to ISO "2025-08-07". If not visible, omit "date".
        - Do not include any summary lines like "Posted Total".
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
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            stamp("Auth: using API key from environment")
        } else {
            stamp("ERROR: OPENAI_API_KEY not found in environment. Set it in Scheme > Run > Arguments.")
        }

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = body
            stamp("Payload prepared. bytes=\(body.count), model=gpt-4o-mini")
        } catch {
            stamp("ERROR: JSONSerialization failed: \(error.localizedDescription)")
            throw error
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            stamp("HTTP status=\(status)")
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            stamp("Raw response (first 800 chars):\n\(raw.prefix(800))")
            guard (200...299).contains(status) else { throw URLError(.badServerResponse) }

            let api = try JSONDecoder().decode(ChatAPIResponse.self, from: data)
            var content = api.choices.first?.message.content ?? "{\"transactions\":[]}"
            content = extractFirstJSON(from: content)

            // Prefer envelope
            if let env = try? JSONDecoder().decode(TxnEnvelope.self, from: Data(content.utf8)) {
                stamp("DECODE OK: \(env.transactions.count) transactions")
                stamp("END analyzeTransactions()")
                return env.transactions
            }

            // Fallback: some models may return a bare array
            if let arr = try? JSONDecoder().decode([ReceiptTransaction].self, from: Data(content.utf8)) {
                stamp("DECODE OK (bare array): \(arr.count) transactions")
                stamp("END analyzeTransactions()")
                return arr
            }

            stamp("ERROR: could not decode transactions.")
            return []
        } catch {
            stamp("ERROR: request/parse failed: \(error.localizedDescription)")
            throw error
        }
    }

    private static func ts() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    // Strip markdown fences / keep first JSON object or array
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
        var depth = 0
        var i = start
        while i < s.endIndex {
            let ch = s[i]
            if ch == open { depth += 1 }
            else if ch == close {
                depth -= 1
                if depth == 0 { return i }
            }
            i = s.index(after: i)
        }
        return nil
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
    struct Prepared {
        let image: UIImage
        let size: CGSize
        let jpegData: Data?
    }
    func preparedForUpload(maxDimension: CGFloat, quality: CGFloat) -> Prepared {
        let w = size.width, h = size.height
        let scale = min(1, maxDimension / max(w, h))
        let newSize = CGSize(width: w * scale, height: h * scale)
        let resized = scale < 1 ? self.resized(to: newSize) : self
        let data = resized.jpegData(compressionQuality: quality)
        return Prepared(image: resized, size: resized.size, jpegData: data)
    }
    func resized(to target: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let r = UIGraphicsImageRenderer(size: target, format: format)
        return r.image { _ in self.draw(in: CGRect(origin: .zero, size: target)) }
    }
}

// File: Services/ChatGPTService.swift
// Interface to OpenAI for receipt analysis

import Foundation
import UIKit

struct ReceiptAnalysis: Decodable {
    let merchant: String?
    let total: Double?
    let category: String?
    let recommendedCard: String?

    enum CodingKeys: String, CodingKey {
        case merchant
        case total
        case category
        case recommendedCard = "recommended_card"
    }
}

final class ChatGPTService {
    static let shared = ChatGPTService()
    private init() {}

    func analyze(image: UIImage? = nil, text: String? = nil) async throws -> ReceiptAnalysis {
        var userContent: [[String: Any]] = []
        if let text = text, !text.isEmpty {
            userContent.append(["type": "text", "text": text])
        }
        if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
            let b64 = data.base64EncodedString()
            userContent.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
            ])
        }
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a budgeting assistant. Extract merchant, total, budget category, and best credit card from receipts or purchase descriptions. Reply in JSON with keys merchant, total, category, recommended_card."],
            ["role": "user", "content": userContent]
        ]
        let payload: [String: Any] = ["model": "gpt-4o-mini", "messages": messages]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await URLSession.shared.data(for: request)
        let apiResponse = try JSONDecoder().decode(ChatGPTAPIResponse.self, from: data)
        let content = apiResponse.choices.first?.message.content ?? "{}"
        let analysisData = Data(content.utf8)
        let analysis = try JSONDecoder().decode(ReceiptAnalysis.self, from: analysisData)
        return analysis
    }
}

private struct ChatGPTAPIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

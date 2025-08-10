// File: Services/OCRService.swift
// OCR using Vision

import Foundation
import Vision
import UIKit

final class OCRService {
    static let shared = OCRService()
    private init() {}
    
    func recognizeText(from uiImage: UIImage) async throws -> String {
        guard let cgImage = uiImage.cgImage else { return "" }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try handler.perform([request])
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let strings = observations.compactMap { $0.topCandidates(1).first?.string }
        return strings.joined(separator: "\n")
    }
}

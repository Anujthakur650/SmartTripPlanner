import Foundation
import NaturalLanguage
import PDFKit
import UIKit
import Vision

struct DocumentMetadataExtractor {
    func extractMetadata(fromPDFAt url: URL) async throws -> DocumentMetadata {
        try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: url) else {
                return DocumentMetadata()
            }
            var aggregatedText = ""
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                if let pageText = page.string {
                    aggregatedText.append(pageText)
                    aggregatedText.append("\n")
                }
            }
            return parseMetadata(from: aggregatedText)
        }.value
    }
    
    func extractMetadata(from images: [UIImage]) async throws -> DocumentMetadata {
        guard !images.isEmpty else { return DocumentMetadata() }
        return try await Task.detached(priority: .userInitiated) {
            var collected = ""
            for image in images {
                guard let cgImage = image.cgImage else { continue }
                let request = VNRecognizeTextRequest()
                request.usesLanguageCorrection = true
                request.recognitionLevel = .accurate
                request.recognitionLanguages = Locale.preferredLanguages
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                let text = request.results?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                collected.append(text)
                collected.append("\n")
            }
            return parseMetadata(from: collected)
        }.value
    }
    
    func extractMetadata(fromRawText text: String) -> DocumentMetadata {
        parseMetadata(from: text)
    }
    
    private func parseMetadata(from text: String) -> DocumentMetadata {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return DocumentMetadata() }
        
        var detectedDates: [Date] = []
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: trimmedText, options: [], range: NSRange(location: 0, length: trimmedText.utf16.count))
            detectedDates = matches.compactMap { $0.date }
        }
        
        let confirmationPattern = "\\b[A-Z0-9]{6,8}\\b"
        let regex = try? NSRegularExpression(pattern: confirmationPattern)
        let confirmationCodes: [String]
        if let regex {
            let nsRange = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
            confirmationCodes = regex.matches(in: trimmedText, options: [], range: nsRange).map { match in
                guard let range = Range(match.range, in: trimmedText) else { return "" }
                return String(trimmedText[range])
            }.filter { !$0.isEmpty }.uniqued()
        } else {
            confirmationCodes = []
        }
        
        let summary = summarize(text: trimmedText)
        let primaryDate = detectedDates.sorted().first
        
        let sampleLength = min(400, trimmedText.count)
        let sample = sampleLength > 0 ? String(trimmedText.prefix(sampleLength)) : nil
        
        return DocumentMetadata(
            primaryDate: primaryDate,
            allDates: detectedDates.uniqued(),
            confirmationCodes: confirmationCodes,
            summary: summary,
            rawTextSample: sample
        )
    }
    
    private func summarize(text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        let sentenceRanges = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        let firstSentences = sentenceRanges.prefix(2).compactMap { range in
            String(text[range])
        }
        let joined = firstSentences.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

import Foundation
import UIKit

@MainActor
class ExportService: ObservableObject {
    func exportToPDF(content: String, filename: String) async throws -> URL {
        let pdfData = createPDF(from: content)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).pdf")
        try pdfData.write(to: tempURL)
        
        return tempURL
    }
    
    func exportToJSON<T: Encodable>(data: T, filename: String) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(data)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).json")
        try jsonData.write(to: tempURL)
        
        return tempURL
    }
    
    func shareFile(at url: URL) async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "ExportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        rootViewController.present(activityViewController, animated: true)
    }
    
    private func createPDF(from content: String) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "SmartTripPlanner",
            kCGPDFContextAuthor: "SmartTripPlanner App"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let textRect = CGRect(x: 40, y: 40, width: pageRect.width - 80, height: pageRect.height - 80)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .paragraphStyle: paragraphStyle
            ]
            
            content.draw(in: textRect, withAttributes: attributes)
        }
        
        return data
    }
}

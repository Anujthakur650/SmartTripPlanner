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
    
    func exportGPX(trip: Trip) throws -> URL {
        let gpxContent = generateGPX(for: trip)
        let filename = "\(trip.name.sanitized())-\(Date().ISO8601Format()).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try gpxContent.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func generateGPX(for trip: Trip) -> String {
        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        gpx += "<gpx version=\"1.1\" creator=\"SmartTripPlanner\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        gpx += "  <metadata>\n"
        gpx += "    <name>\(trip.name)</name>\n"
        if let startDate = trip.startDate {
            gpx += "    <time>\(startDate.ISO8601Format())</time>\n"
        }
        gpx += "  </metadata>\n"
        
        for item in trip.itineraryItems {
            if let location = item.location {
                gpx += "  <wpt lat=\"\(location.latitude)\" lon=\"\(location.longitude)\">\n"
                gpx += "    <name>\(item.title)</name>\n"
                if let time = item.startTime {
                    gpx += "    <time>\(time.ISO8601Format())</time>\n"
                }
                gpx += "  </wpt>\n"
            }
        }
        
        gpx += "</gpx>\n"
        return gpx
    }
    
    func shareExports(for trip: Trip, exportedURLs: [URL]) async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "ExportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        
        let gpxURL = try? exportGPX(trip: trip)
        var activityItems: [Any] = exportedURLs.map { $0 }
        if let gpxURL {
            activityItems.append(gpxURL)
        }
        
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        rootViewController.present(activityViewController, animated: true)
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

private extension String {
    func sanitized() -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let components = self.components(separatedBy: invalidCharacters)
        let sanitized = components.filter { !$0.isEmpty }.joined(separator: "-")
        let collapsedWhitespace = sanitized.replacingOccurrences(of: "[\\s_]+", with: "-", options: .regularExpression)
        return collapsedWhitespace.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

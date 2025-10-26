import Foundation
import UIKit

@MainActor
class ExportService: ObservableObject {
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
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
        try await presentActivityController(with: [url])
    }
    
    func shareExports(for trip: Trip) async throws {
        let sanitizedName = trip.name.sanitized()
        let summary = tripSummary(for: trip)
        let pdfURL = try await exportToPDF(content: summary, filename: sanitizedName)
        let jsonURL = try await exportToJSON(data: trip, filename: sanitizedName)
        let gpxURL = try exportGPX(trip: trip)
        try await presentActivityController(with: [pdfURL, jsonURL, gpxURL])
    }
    
    func exportGPX(trip: Trip) throws -> URL {
        let xml = generateGPXXML(trip: trip)
        let filename = "\(trip.name.sanitized())-\(Date().ISO8601Format()).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private func presentActivityController(with items: [Any]) async throws {
        guard !items.isEmpty else { return }
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "ExportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        rootViewController.present(activityViewController, animated: true)
    }
    
    private func tripSummary(for trip: Trip) -> String {
        var components: [String] = []
        components.append("Trip: \(trip.name)")
        components.append("Destination: \(trip.destination)")
        components.append("Start Date: \(dateFormatter.string(from: trip.startDate))")
        components.append("End Date: \(dateFormatter.string(from: trip.endDate))")
        if !trip.itineraryItems.isEmpty {
            components.append("")
            components.append("Itinerary:")
            let sortedItems = trip.itineraryItems.sorted { $0.startTime < $1.startTime }
            for item in sortedItems {
                let time = timeFormatter.string(from: item.startTime)
                components.append("- \(time) • \(item.title)")
            }
        }
        return components.joined(separator: "\n")
    }
    
    private func generateGPXXML(trip: Trip) -> String {
        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        gpx += "<gpx version=\"1.1\" creator=\"SmartTripPlanner\">\n"
        gpx += "  <metadata>\n"
        gpx += "    <name>\(xmlEscaped(trip.name))</name>\n"
        gpx += "    <time>\(trip.startDate.ISO8601Format())</time>\n"
        gpx += "  </metadata>\n"
        
        for item in trip.itineraryItems {
            guard let location = item.location else { continue }
            let latitude = String(format: "%.6f", location.latitude)
            let longitude = String(format: "%.6f", location.longitude)
            gpx += "  <wpt lat=\"\(latitude)\" lon=\"\(longitude)\">\n"
            gpx += "    <name>\(xmlEscaped(item.title))</name>\n"
            gpx += "    <time>\(item.startTime.ISO8601Format())</time>\n"
            gpx += "  </wpt>\n"
        }
        
        gpx += "</gpx>"
        return gpx
    }
    
    private func xmlEscaped(_ value: String) -> String {
        var escaped = value
        let replacements: [String: String] = [
            "&": "&amp;",
            "\"": "&quot;",
            "'": "&apos;",
            "<": "&lt;",
            ">": "&gt;"
        ]
        for (key, replacement) in replacements {
            escaped = escaped.replacingOccurrences(of: key, with: replacement)
        }
        return escaped
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

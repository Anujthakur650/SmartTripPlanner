import Foundation
import UIKit

@MainActor
class ExportService: ObservableObject {
    private let tempDirectory: URL
    private let fileManager: FileManager
    private let gpxDateFormatter: ISO8601DateFormatter
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        tempDirectory = fileManager.temporaryDirectory
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        gpxDateFormatter = formatter
    }
    
    func exportToPDF(content: String, filename: String) async throws -> URL {
        let pdfData = createPDF(from: content)
        let safeFilename = sanitizedFilename(filename)
        let tempURL = tempDirectory.appendingPathComponent("\(safeFilename).pdf")
        try pdfData.write(to: tempURL, options: .atomic)
        return tempURL
    }
    
    func exportToJSON<T: Encodable>(data: T, filename: String) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(data)
        let safeFilename = sanitizedFilename(filename)
        let tempURL = tempDirectory.appendingPathComponent("\(safeFilename).json")
        try jsonData.write(to: tempURL, options: .atomic)
        return tempURL
    }
    
    func exportToGPX(for trip: Trip, description: String? = nil) async throws -> URL {
        let builder = GPXBuilder(dateFormatter: gpxDateFormatter)
        let gpxString = builder.buildGPX(for: trip, description: description)
        guard let data = gpxString.data(using: .utf8) else {
            throw NSError(domain: "ExportService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode GPX data"])
        }
        let filename = sanitizedFilename(trip.name.isEmpty ? "Trip" : trip.name)
        let url = tempDirectory.appendingPathComponent("\(filename).gpx")
        try data.write(to: url, options: .atomic)
        return url
    }
    
    func shareFile(at url: URL) async throws {
        try await shareFiles(at: [url])
    }
    
    func shareFiles(at urls: [URL]) async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "ExportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        let activityViewController = UIActivityViewController(activityItems: urls, applicationActivities: nil)
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
    
    private func sanitizedFilename(_ filename: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let components = filename.components(separatedBy: forbidden)
        let sanitized = components.joined(separator: "-")
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Export" : String(trimmed.prefix(60))
    }
}

private struct GPXBuilder {
    private let namespace = "http://www.topografix.com/GPX/1/1"
    private let creator = "SmartTripPlanner"
    private let dateFormatter: ISO8601DateFormatter
    
    init(dateFormatter: ISO8601DateFormatter) {
        self.dateFormatter = dateFormatter
    }
    
    func buildGPX(for trip: Trip, description: String?) -> String {
        var xml = """<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"""
        xml += "<gpx version=\"1.1\" creator=\"\(creator)\" xmlns=\"\(namespace)\">\n"
        xml += metadata(for: trip, description: description)
        xml += waypoints(for: trip)
        xml += track(for: trip)
        xml += "</gpx>\n"
        return xml
    }
    
    private func metadata(for trip: Trip, description: String?) -> String {
        var xml = "  <metadata>\n"
        xml += "    <name>\(escape(trip.name))</name>\n"
        if let description {
            xml += "    <desc>\(escape(description))</desc>\n"
        }
        xml += "    <time>\(dateFormatter.string(from: trip.startDate))</time>\n"
        xml += "  </metadata>\n"
        return xml
    }
    
    private func waypoints(for trip: Trip) -> String {
        var xml = ""
        let reservationWaypoints = trip.reservations.flatMap { reservation -> [Waypoint] in
            var points: [Waypoint] = []
            if let origin = reservation.origin, let coordinate = origin.coordinate {
                points.append(Waypoint(title: reservation.title + " - Origin",
                                       coordinate: coordinate,
                                       time: reservation.startDate,
                                       description: origin.address ?? reservation.notes))
            }
            if let destination = reservation.destination, let coordinate = destination.coordinate {
                points.append(Waypoint(title: reservation.title + " - Destination",
                                       coordinate: coordinate,
                                       time: reservation.endDate ?? reservation.startDate,
                                       description: destination.address ?? reservation.notes))
            }
            return points
        }
        let itineraryWaypoints = trip.itineraryItems.compactMap { item -> Waypoint? in
            guard let coordinate = item.location?.coordinate else { return nil }
            return Waypoint(title: item.title,
                            coordinate: coordinate,
                            time: item.startDate,
                            description: item.detail ?? item.reservation?.notes)
        }
        let waypoints = reservationWaypoints + itineraryWaypoints
        for waypoint in waypoints {
            xml += "  <wpt lat=\"\(waypoint.coordinate.latitude)\" lon=\"\(waypoint.coordinate.longitude)\">\n"
            xml += "    <name>\(escape(waypoint.title))</name>\n"
            if let description = waypoint.description {
                xml += "    <desc>\(escape(description))</desc>\n"
            }
            if let time = waypoint.time {
                xml += "    <time>\(dateFormatter.string(from: time))</time>\n"
            }
            xml += "  </wpt>\n"
        }
        return xml
    }
    
    private func track(for trip: Trip) -> String {
        let points = trip.itineraryItems
            .filter { $0.location?.coordinate != nil }
            .sorted { (lhs, rhs) -> Bool in
                switch (lhs.startDate, rhs.startDate) {
                case let (l?, r?): return l < r
                case (.some, .none): return true
                case (.none, .some): return false
                default: return lhs.title < rhs.title
                }
            }
        guard !points.isEmpty else { return "" }
        var xml = "  <trk>\n"
        xml += "    <name>\(escape(trip.name)) Route</name>\n"
        xml += "    <trkseg>\n"
        for point in points {
            guard let coordinate = point.location?.coordinate else { continue }
            xml += "      <trkpt lat=\"\(coordinate.latitude)\" lon=\"\(coordinate.longitude)\">\n"
            if let time = point.startDate {
                xml += "        <time>\(dateFormatter.string(from: time))</time>\n"
            }
            if let name = point.location?.name, !name.isEmpty {
                xml += "        <name>\(escape(name))</name>\n"
            }
            xml += "      </trkpt>\n"
        }
        xml += "    </trkseg>\n"
        xml += "  </trk>\n"
        return xml
    }
    
    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    private struct Waypoint {
        var title: String
        var coordinate: Coordinate
        var time: Date?
        var description: String?
    }
}

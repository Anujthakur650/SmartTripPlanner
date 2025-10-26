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
    
    func exportToGPX(metadata: GPXMetadata, tracks: [GPXTrack], waypoints: [GPXWaypoint], filename: String) async throws -> URL {
        let builder = GPXBuilder(metadata: metadata, tracks: tracks, waypoints: waypoints)
        let xml = builder.build()
        guard let data = xml.data(using: .utf8) else {
            throw NSError(domain: "ExportService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode GPX data"])
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).gpx")
        try data.write(to: url, options: [.atomic])
        return url
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

private struct GPXBuilder {
    private let metadata: GPXMetadata
    private let tracks: [GPXTrack]
    private let waypoints: [GPXWaypoint]
    private let isoFormatter: ISO8601DateFormatter
    
    init(metadata: GPXMetadata, tracks: [GPXTrack], waypoints: [GPXWaypoint]) {
        self.metadata = metadata
        self.tracks = tracks
        self.waypoints = waypoints
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFormatter = formatter
    }
    
    func build() -> String {
        var components: [String] = []
        components.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        components.append("<gpx version=\"1.1\" creator=\"SmartTripPlanner\" xmlns=\"http://www.topografix.com/GPX/1/1\">")
        components.append(metadataSection())
        for waypoint in waypoints {
            components.append(render(waypoint: waypoint))
        }
        for track in tracks {
            components.append(render(track: track))
        }
        components.append("</gpx>")
        return components.joined(separator: "\n")
    }
    
    private func metadataSection() -> String {
        var lines: [String] = []
        lines.append("  <metadata>")
        lines.append("    <name>\(escape(metadata.name))</name>")
        if let description = metadata.description {
            lines.append("    <desc>\(escape(description))</desc>")
        }
        lines.append("    <time>\(isoFormatter.string(from: metadata.creationDate))</time>")
        if let author = metadata.author {
            lines.append("    <author>")
            lines.append("      <name>\(escape(author))</name>")
            if let email = metadata.email {
                let parts = email.split(separator: "@")
                let idPart = parts.first.map(String.init) ?? "info"
                let domainPart = parts.count > 1 ? parts.last.map(String.init) ?? "example.com" : "example.com"
                lines.append("      <email id=\"\(escape(idPart))\" domain=\"\(escape(domainPart))\" />")
            }
            lines.append("    </author>")
        }
        if let link = metadata.link {
            lines.append("    <link href=\"\(escape(link.absoluteString))\" />")
        }
        if !metadata.keywords.isEmpty {
            lines.append("    <keywords>\(escape(metadata.keywords.joined(separator: ", ")))</keywords>")
        }
        lines.append("  </metadata>")
        return lines.joined(separator: "\n")
    }
    
    private func render(waypoint: GPXWaypoint) -> String {
        var lines: [String] = []
        lines.append("  <wpt lat=\"\(formatCoordinate(waypoint.latitude))\" lon=\"\(formatCoordinate(waypoint.longitude))\">")
        if let elevation = waypoint.elevation {
            lines.append("    <ele>\(formatElevation(elevation))</ele>")
        }
        if let time = waypoint.time {
            lines.append("    <time>\(isoFormatter.string(from: time))</time>")
        }
        if let name = waypoint.name {
            lines.append("    <name>\(escape(name))</name>")
        }
        if let comment = waypoint.comment {
            lines.append("    <cmt>\(escape(comment))</cmt>")
        }
        if let symbol = waypoint.symbol {
            lines.append("    <sym>\(escape(symbol))</sym>")
        }
        if let type = waypoint.type {
            lines.append("    <type>\(escape(type))</type>")
        }
        lines.append("  </wpt>")
        return lines.joined(separator: "\n")
    }
    
    private func render(track: GPXTrack) -> String {
        var lines: [String] = []
        lines.append("  <trk>")
        lines.append("    <name>\(escape(track.name))</name>")
        if let comment = track.comment {
            lines.append("    <cmt>\(escape(comment))</cmt>")
        }
        if let type = track.type {
            lines.append("    <type>\(escape(type))</type>")
        }
        for segment in track.segments {
            lines.append("    <trkseg>")
            for point in segment.points {
                lines.append("      <trkpt lat=\"\(formatCoordinate(point.latitude))\" lon=\"\(formatCoordinate(point.longitude))\">")
                if let elevation = point.elevation {
                    lines.append("        <ele>\(formatElevation(elevation))</ele>")
                }
                if let time = point.time {
                    lines.append("        <time>\(isoFormatter.string(from: time))</time>")
                }
                if let name = point.name {
                    lines.append("        <name>\(escape(name))</name>")
                }
                if let comment = point.comment {
                    lines.append("        <cmt>\(escape(comment))</cmt>")
                }
                if let symbol = point.symbol {
                    lines.append("        <sym>\(escape(symbol))</sym>")
                }
                lines.append("      </trkpt>")
            }
            lines.append("    </trkseg>")
        }
        lines.append("  </trk>")
        return lines.joined(separator: "\n")
    }
    
    private func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
    
    private func formatElevation(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
    
    private func escape(_ value: String) -> String {
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        return escaped
    }
}

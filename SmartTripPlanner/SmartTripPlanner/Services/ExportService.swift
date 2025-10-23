import Foundation
import CoreLocation
import PDFKit
import UIKit

@MainActor
protocol MapsDataSource: AnyObject {
    var savedRoutes: [SavedRoute] { get }
    var savedPlaces: [Place] { get }
}

@MainActor
final class ExportService: ObservableObject {
    enum ExportKind: String, Codable {
        case itineraryPDF
        case gpx
        
        var localizedTitle: String {
            switch self {
            case .itineraryPDF:
                return String(localized: "Itinerary PDF")
            case .gpx:
                return String(localized: "GPX Export")
            }
        }
        
        var systemImage: String {
            switch self {
            case .itineraryPDF:
                return "doc.richtext"
            case .gpx:
                return "map"
            }
        }
    }
    
    enum DeliveryOption: String, CaseIterable, Identifiable {
        case share
        case files
        case print
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .share:
                return String(localized: "Share")
            case .files:
                return String(localized: "Files")
            case .print:
                return String(localized: "Print")
            }
        }
        
        var systemImage: String {
            switch self {
            case .share:
                return "square.and.arrow.up"
            case .files:
                return "folder"
            case .print:
                return "printer"
            }
        }
    }
    
    struct HistoryRecord: Identifiable, Codable, Equatable {
        let id: UUID
        let kind: ExportKind
        let createdAt: Date
        let filename: String
        let relativePath: String
        let localeIdentifier: String
        let sizeInBytes: Int
        
        enum CodingKeys: String, CodingKey {
            case id
            case kind
            case createdAt
            case filename
            case relativePath
            case localeIdentifier
            case sizeInBytes
        }
    }
    
    struct ItineraryContent: Codable, Equatable {
        var trip: Trip
        var segments: [TripSegment]
        var dayPlans: [DayPlan]
        var packingItems: [PackingItem]
        var documents: [TravelDocument]
    }
    
    struct GPXMetadata {
        var name: String
        var description: String?
        var author: String?
        var time: Date
    }
    
    enum ExportError: LocalizedError, Identifiable {
        case itineraryUnavailable
        case gpxUnavailable
        case offlineDataUnavailable
        case presentationUnavailable
        case pdfGenerationFailed
        case gpxGenerationFailed
        case fileAccessFailed
        
        var id: String { localizedDescription }
        
        var errorDescription: String? {
            switch self {
            case .itineraryUnavailable:
                return String(localized: "Unable to build itinerary data.")
            case .gpxUnavailable:
                return String(localized: "No route or waypoint data available for GPX export.")
            case .offlineDataUnavailable:
                return String(localized: "No cached data is available offline. Sync your data before exporting.")
            case .presentationUnavailable:
                return String(localized: "Unable to present the export interface.")
            case .pdfGenerationFailed:
                return String(localized: "Failed to generate the itinerary PDF.")
            case .gpxGenerationFailed:
                return String(localized: "Failed to generate the GPX file.")
            case .fileAccessFailed:
                return String(localized: "Unable to access the exported file location.")
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .itineraryUnavailable:
                return String(localized: "Verify your trip details and try again.")
            case .gpxUnavailable:
                return String(localized: "Save a route or waypoint before exporting.")
            case .offlineDataUnavailable:
                return String(localized: "Reconnect to the internet or refresh your saved data.")
            case .presentationUnavailable:
                return String(localized: "Try dismissing any presented views and retry the export.")
            case .pdfGenerationFailed, .gpxGenerationFailed:
                return String(localized: "Please try exporting again.")
            case .fileAccessFailed:
                return String(localized: "Check your available storage space and permissions.")
            }
        }
    }
    
    @Published private(set) var history: [HistoryRecord] = []
    
    private weak var appEnvironment: AppEnvironment?
    private weak var travelDataSource: (any ItineraryDataSource)?
    private weak var mapsDataSource: (any MapsDataSource)?
    private let fileManager: FileManager
    private let exportsDirectory: URL
    private let historyURL: URL
    private let locale: Locale
    private let isoFormatter: ISO8601DateFormatter
    
    private struct PDFLayout {
        static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        static let contentInsets = UIEdgeInsets(top: 48, left: 54, bottom: 54, right: 54)
        static let brandColor = UIColor(red: 0.08, green: 0.45, blue: 0.85, alpha: 1)
        static let accentColor = UIColor(red: 0.99, green: 0.63, blue: 0.13, alpha: 1)
    }
    
    init(appEnvironment: AppEnvironment,
         travelDataSource: any ItineraryDataSource,
         mapsDataSource: (any MapsDataSource)? = nil,
         fileManager: FileManager = .default,
         locale: Locale = .current) {
        self.appEnvironment = appEnvironment
        self.travelDataSource = travelDataSource
        self.mapsDataSource = mapsDataSource
        self.fileManager = fileManager
        self.locale = locale
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.isoFormatter = formatter
        let baseDirectory: URL
        if let support = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            baseDirectory = support.appendingPathComponent("Exports", isDirectory: true)
        } else {
            baseDirectory = fileManager.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        }
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
        self.exportsDirectory = baseDirectory
        self.historyURL = baseDirectory.appendingPathComponent("exports-history.json")
        loadHistory()
    }
    
    var canGenerateItinerary: Bool {
        buildCurrentItineraryContent() != nil
    }
    
    var canGenerateGPX: Bool {
        guard let mapsDataSource else { return false }
        return !mapsDataSource.savedRoutes.isEmpty || !mapsDataSource.savedPlaces.isEmpty
    }
    
    @discardableResult
    func exportCurrentItinerary(delivery: DeliveryOption? = .share) async throws -> HistoryRecord {
        guard let content = buildCurrentItineraryContent() else {
            throw ExportError.itineraryUnavailable
        }
        return try await exportItinerary(content: content, delivery: delivery)
    }
    
    @discardableResult
    func exportItinerary(content: ItineraryContent, delivery: DeliveryOption? = nil) async throws -> HistoryRecord {
        guard let pdfData = try? renderPDF(for: content) else {
            throw ExportError.pdfGenerationFailed
        }
        let filename = makeFilename(from: content.trip.name, suffix: "Itinerary", fileExtension: "pdf")
        let url = exportsDirectory.appendingPathComponent(filename)
        do {
            try pdfData.write(to: url, options: .atomic)
        } catch {
            throw ExportError.fileAccessFailed
        }
        let record = HistoryRecord(
            id: UUID(),
            kind: .itineraryPDF,
            createdAt: Date(),
            filename: filename,
            relativePath: filename,
            localeIdentifier: locale.identifier,
            sizeInBytes: pdfData.count
        )
        appendToHistory(record)
        if let delivery {
            try deliver(url: url, option: delivery)
        }
        return record
    }
    
    @discardableResult
    func exportGPX(delivery: DeliveryOption? = nil) async throws -> HistoryRecord {
        guard let mapsDataSource else { throw ExportError.gpxUnavailable }
        let isOnline = appEnvironment?.isOnline ?? true
        if !isOnline, !canGenerateGPX {
            throw ExportError.offlineDataUnavailable
        }
        guard canGenerateGPX else {
            throw ExportError.gpxUnavailable
        }
        let waypoints = mapsDataSource.savedPlaces
        let routes = mapsDataSource.savedRoutes
        let metadata = defaultMetadata(for: routes, waypoints: waypoints)
        guard let gpxString = renderGPX(metadata: metadata, waypoints: waypoints, routes: routes) else {
            throw ExportError.gpxGenerationFailed
        }
        guard let data = gpxString.data(using: .utf8) else {
            throw ExportError.gpxGenerationFailed
        }
        let filename = makeFilename(from: metadata.name, suffix: "Routes", fileExtension: "gpx")
        let url = exportsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.fileAccessFailed
        }
        let record = HistoryRecord(
            id: UUID(),
            kind: .gpx,
            createdAt: Date(),
            filename: filename,
            relativePath: filename,
            localeIdentifier: locale.identifier,
            sizeInBytes: data.count
        )
        appendToHistory(record)
        if let delivery {
            try deliver(url: url, option: delivery)
        }
        return record
    }
    
    func deliver(record: HistoryRecord, option: DeliveryOption) throws {
        let url = fileURL(for: record)
        guard fileManager.fileExists(atPath: url.path) else {
            throw ExportError.fileAccessFailed
        }
        try deliver(url: url, option: option)
    }
    
    func fileURL(for record: HistoryRecord) -> URL {
        exportsDirectory.appendingPathComponent(record.relativePath)
    }
    
    func refreshHistory() {
        loadHistory()
    }
    
    // MARK: - Private helpers
    
    private func appendToHistory(_ record: HistoryRecord) {
        history.insert(record, at: 0)
        saveHistory()
    }
    
    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL) else { return }
        if let decoded = try? JSONDecoder().decode([HistoryRecord].self, from: data) {
            history = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }
    
    private func makeFilename(from name: String, suffix: String, fileExtension: String) -> String {
        let sanitized = name.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let timestamp = formatter.string(from: Date())
        return "\(sanitized.isEmpty ? "Trip" : sanitized)-\(suffix)-\(timestamp).\(fileExtension)"
    }
    
    private func renderPDF(for content: ItineraryContent) throws -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator: "SmartTripPlanner",
            kCGPDFContextAuthor: "SmartTripPlanner",
            kCGPDFContextTitle: content.trip.name
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: PDFLayout.pageRect, format: format)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 20
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.hyphenationFactor = 0.8
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: PDFLayout.brandColor
        ]
        let subheadingAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let smallAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let bulletAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.label
        ]
        let brandBarHeight: CGFloat = 36
        var currentY: CGFloat = PDFLayout.contentInsets.top + brandBarHeight + 24
        
        func newPage(_ context: UIGraphicsPDFRendererContext) {
            context.beginPage()
            drawBrandHeader(context)
            currentY = PDFLayout.contentInsets.top + brandBarHeight + 24
        }
        
        func ensureSpace(_ height: CGFloat, context: UIGraphicsPDFRendererContext) {
            let maxY = PDFLayout.pageRect.height - PDFLayout.contentInsets.bottom
            if currentY + height > maxY {
                newPage(context)
            }
        }
        
        func drawText(_ text: String, attributes: [NSAttributedString.Key: Any], spacing: CGFloat = 12, context: UIGraphicsPDFRendererContext) {
            guard !text.isEmpty else { return }
            let width = PDFLayout.pageRect.width - PDFLayout.contentInsets.left - PDFLayout.contentInsets.right
            let boundingRect = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            ensureSpace(boundingRect.height, context: context)
            let frame = CGRect(x: PDFLayout.contentInsets.left, y: currentY, width: width, height: boundingRect.height)
            (text as NSString).draw(with: frame, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            currentY += boundingRect.height + spacing
        }
        
        func drawDivider(context: UIGraphicsPDFRendererContext) {
            ensureSpace(20, context: context)
            let startX = PDFLayout.contentInsets.left
            let endX = PDFLayout.pageRect.width - PDFLayout.contentInsets.right
            context.cgContext.setStrokeColor(PDFLayout.brandColor.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.move(to: CGPoint(x: startX, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: endX, y: currentY))
            context.cgContext.strokePath()
            currentY += 16
        }
        
        func drawBrandHeader(_ context: UIGraphicsPDFRendererContext) {
            let headerRect = CGRect(x: 0, y: 0, width: PDFLayout.pageRect.width, height: PDFLayout.contentInsets.top + brandBarHeight)
            PDFLayout.brandColor.setFill()
            context.cgContext.fill(headerRect)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let title = content.trip.name
            let subtitle = DateInterval(start: content.trip.startDate, end: content.trip.endDate).formatted(.interval.day().month().year())
            let titlePoint = CGPoint(x: PDFLayout.contentInsets.left, y: PDFLayout.contentInsets.top - 12)
            (title as NSString).draw(at: titlePoint, withAttributes: titleAttributes)
            (subtitle as NSString).draw(at: CGPoint(x: PDFLayout.contentInsets.left, y: titlePoint.y + 26), withAttributes: subtitleAttributes)
        }
        
        return renderer.pdfData { context in
            drawBrandHeader(context)
            drawText(String(localized: "Trip Overview"), attributes: headingAttributes, context: context)
            drawText(overviewSummary(for: content.trip), attributes: bodyAttributes, spacing: 10, context: context)
            if !content.trip.travelers.isEmpty {
                let travelers = content.trip.travelers.joined(separator: ", ")
                drawText(String(localized: "Travelers: \(travelers)"), attributes: smallAttributes, context: context)
            }
            if let notes = content.trip.notes, !notes.isEmpty {
                drawText(String(localized: "Notes: \(notes)"), attributes: smallAttributes, context: context)
            }
            drawDivider(context: context)
            
            if !content.segments.isEmpty {
                drawText(String(localized: "Segments"), attributes: headingAttributes, context: context)
                for segment in content.segments {
                    let title = "\(segment.title) — \(segment.mode.localizedTitle)"
                    drawText(title, attributes: subheadingAttributes, spacing: 6, context: context)
                    let departureLine = String(localized: "• Depart: \(formatted(segment.departure.date)) — \(segment.departure.location)")
                    drawText(departureLine, attributes: bulletAttributes, spacing: 4, context: context)
                    let arrivalLine = String(localized: "• Arrive: \(formatted(segment.arrival.date)) — \(segment.arrival.location)")
                    drawText(arrivalLine, attributes: bulletAttributes, spacing: 4, context: context)
                    if let notes = segment.notes, !notes.isEmpty {
                        drawText(String(localized: "  Notes: \(notes)"), attributes: smallAttributes, spacing: 12, context: context)
                    } else {
                        currentY += 8
                    }
                }
                drawDivider(context: context)
            }
            
            if !content.dayPlans.isEmpty {
                drawText(String(localized: "Daily Plans"), attributes: headingAttributes, context: context)
                for plan in content.dayPlans.sorted(by: { $0.date < $1.date }) {
                    drawText(dayPlanTitle(for: plan), attributes: subheadingAttributes, spacing: 8, context: context)
                    if plan.items.isEmpty {
                        drawText(String(localized: "  • No activities scheduled"), attributes: bulletAttributes, context: context)
                    } else {
                        for item in plan.items {
                            var line = "  • \(item.title)"
                            if let time = item.time, let date = Calendar.current.date(from: time) {
                                line = "  • \(date.formatted(date: .omitted, time: .shortened)) – \(item.title)"
                            }
                            drawText(line, attributes: bulletAttributes, spacing: 4, context: context)
                            if let location = item.location, !location.isEmpty {
                                drawText("    ⋅ \(location)", attributes: smallAttributes, spacing: 2, context: context)
                            }
                            drawText("    \(item.details)", attributes: smallAttributes, spacing: 8, context: context)
                        }
                    }
                    currentY += 6
                }
                drawDivider(context: context)
            }
            
            if !content.packingItems.isEmpty {
                drawText(String(localized: "Packing Checklist"), attributes: headingAttributes, context: context)
                for item in content.packingItems {
                    let status = item.isChecked ? "☑" : "☐"
                    let line = "\(status) \(item.name)"
                    drawText(line, attributes: bulletAttributes, spacing: 6, context: context)
                }
                drawDivider(context: context)
            }
            
            if !content.documents.isEmpty {
                drawText(String(localized: "Key Documents"), attributes: headingAttributes, context: context)
                for document in content.documents {
                    var line = "• \(document.name) — \(document.type.localizedTitle)"
                    if let notes = document.notes, !notes.isEmpty {
                        line.append(" (\(notes))")
                    }
                    drawText(line, attributes: bulletAttributes, spacing: 6, context: context)
                }
            }
        }
    }
    
    private func overviewSummary(for trip: Trip) -> String {
        let durationDays = max(trip.durationInDays, 1)
        let dateRange = DateInterval(start: trip.startDate, end: trip.endDate).formatted(.interval.day().month().year())
        return String(localized: "Destination: \(trip.destination)\nDates: \(dateRange)\nDuration: \(durationDays) day(s)")
    }
    
    private func dayPlanTitle(for plan: DayPlan) -> String {
        if plan.title.isEmpty {
            return plan.date.formatted(date: .long, time: .omitted)
        }
        return "\(plan.title) – \(plan.date.formatted(date: .abbreviated, time: .omitted))"
    }
    
    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
    
    private func renderGPX(metadata: GPXMetadata, waypoints: [Place], routes: [SavedRoute]) -> String? {
        var result = """<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<gpx version=\"1.1\" creator=\"SmartTripPlanner\" xmlns=\"http://www.topografix.com/GPX/1/1\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\">
  <metadata>
    <name>\(escapeXML(metadata.name))</name>
"""
        if let description = metadata.description, !description.isEmpty {
            result.append("    <desc>\(escapeXML(description))</desc>\n")
        }
        if let author = metadata.author, !author.isEmpty {
            result.append("    <author><name>\(escapeXML(author))</name></author>\n")
        }
        result.append("    <time>\(isoFormatter.string(from: metadata.time))</time>\n  </metadata>\n")
        for place in waypoints {
            result.append("  <wpt lat=\"\(formatCoordinate(place.coordinate.latitude))\" lon=\"\(formatCoordinate(place.coordinate.longitude))\">\n")
            result.append("    <name>\(escapeXML(place.name))</name>\n")
            let descComponents = [place.addressDescription, place.association?.summary].compactMap { $0 }.filter { !$0.isEmpty }
            if !descComponents.isEmpty {
                result.append("    <desc>\(escapeXML(descComponents.joined(separator: ", ")))</desc>\n")
            }
            result.append("  </wpt>\n")
        }
        for route in routes {
            result.append("  <rte>\n")
            result.append("    <name>\(escapeXML(routeName(route)))</name>\n")
            result.append("    <desc>\(escapeXML(routeDescription(route)))</desc>\n")
            result.append("    <type>\(escapeXML(route.mode.rawValue))</type>\n")
            result.append("    <rtept lat=\"\(formatCoordinate(route.from.coordinate.latitude))\" lon=\"\(formatCoordinate(route.from.coordinate.longitude))\">\n")
            result.append("      <name>\(escapeXML(route.from.name))</name>\n")
            result.append("    </rtept>\n")
            result.append("    <rtept lat=\"\(formatCoordinate(route.to.coordinate.latitude))\" lon=\"\(formatCoordinate(route.to.coordinate.longitude))\">\n")
            result.append("      <name>\(escapeXML(route.to.name))</name>\n")
            result.append("    </rtept>\n")
            result.append("  </rte>\n")
        }
        result.append("</gpx>\n")
        return result
    }
    
    private func defaultMetadata(for routes: [SavedRoute], waypoints: [Place]) -> GPXMetadata {
        let tripName = travelDataSource?.trips.first?.name ?? String(localized: "Trip Export")
        let destination = travelDataSource?.trips.first?.destination ?? waypoints.first?.locality ?? ""
        var description = destination.isEmpty ? nil : String(localized: "Destination: \(destination)")
        if description == nil, let firstRoute = routes.first {
            description = String(localized: "Route from \(firstRoute.from.name) to \(firstRoute.to.name)")
        }
        return GPXMetadata(name: tripName, description: description, author: String(localized: "SmartTripPlanner"), time: Date())
    }
    
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    private func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
    
    private func routeName(_ route: SavedRoute) -> String {
        "\(route.from.name) → \(route.to.name)"
    }
    
    private func routeDescription(_ route: SavedRoute) -> String {
        let time = formatDuration(route.primary.expectedTravelTime)
        let distance = formatDistance(route.primary.distance)
        return String(localized: "Primary route: \(time), \(distance)")
    }
    
    private func formatDuration(_ value: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = value >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
        return formatter.string(from: value) ?? "--"
    }
    
    private func formatDistance(_ value: CLLocationDistance) -> String {
        let measurement = Measurement(value: value / 1000, unit: UnitLength.kilometers)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
    
    private func buildCurrentItineraryContent() -> ItineraryContent? {
        guard let dataSource = travelDataSource, let trip = dataSource.trips.first else {
            return nil
        }
        var segments = dataSource.segments
        if segments.isEmpty, let routes = mapsDataSource?.savedRoutes, !routes.isEmpty {
            segments = routes.map(makeSegment(from:))
        }
        let plans = dataSource.dayPlans.sorted { $0.date < $1.date }
        return ItineraryContent(
            trip: trip,
            segments: segments,
            dayPlans: plans,
            packingItems: dataSource.packingItems,
            documents: dataSource.documents
        )
    }
    
    private func makeSegment(from route: SavedRoute) -> TripSegment {
        let mode: TripSegment.Mode
        switch route.mode {
        case .driving:
            mode = .drive
        case .walking:
            mode = .walk
        case .transit:
            mode = .transit
        }
        let departure = TripSegment.Event(date: route.createdAt, location: route.from.name)
        let arrival = TripSegment.Event(date: route.createdAt.addingTimeInterval(route.primary.expectedTravelTime), location: route.to.name)
        let notes = String(localized: "Distance: \(formatDistance(route.primary.distance)) — Duration: \(formatDuration(route.primary.expectedTravelTime))")
        return TripSegment(title: routeName(route), subtitle: route.mode.displayName, mode: mode, departure: departure, arrival: arrival, notes: notes)
    }
    
    private func deliver(url: URL, option: DeliveryOption) throws {
        guard let rootController = topViewController() else {
            throw ExportError.presentationUnavailable
        }
        switch option {
        case .share:
            let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            controller.popoverPresentationController?.sourceView = rootController.view
            rootController.present(controller, animated: true)
        case .files:
            let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            picker.modalPresentationStyle = .formSheet
            rootController.present(picker, animated: true)
        case .print:
            let printController = UIPrintInteractionController.shared
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = url.lastPathComponent
            info.outputType = .general
            printController.printInfo = info
            printController.printingItem = url
            printController.present(animated: true)
        }
    }
    
    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return root.topMostPresentedController()
    }
}

private extension UIViewController {
    func topMostPresentedController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostPresentedController()
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostPresentedController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostPresentedController() ?? tab
        }
        return self
    }
}

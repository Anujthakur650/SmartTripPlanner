import Foundation

struct ICSParsedTrip {
    let name: String
    let calendarName: String?
    let startDate: Date
    let endDate: Date
    let destinations: [TripDestination]
    let segments: [TripSegment]
    let travelModes: [TripTravelMode]
}

enum ICSParserError: LocalizedError {
    case invalidData
    case noEvents
    case invalidDate(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The calendar file could not be read."
        case .noEvents:
            return "No events were found in the calendar."
        case let .invalidDate(value):
            return "Unable to parse date value \(value)."
        }
    }
}

final class ICSParser {
    private struct Event {
        var uid: String?
        var summary: String?
        var description: String?
        var location: String?
        var start: Date?
        var end: Date?
    }
    
    private let calendar = Calendar(identifier: .gregorian)
    
    func parse(data: Data) throws -> ICSParsedTrip {
        guard let rawString = String(data: data, encoding: .utf8) else {
            throw ICSParserError.invalidData
        }
        let unfoldedLines = unfoldLines(from: rawString)
        var events: [Event] = []
        var currentEvent: Event?
        var calendarName: String?
        
        for line in unfoldedLines {
            if line.hasPrefix("BEGIN:VEVENT") {
                currentEvent = Event()
                continue
            }
            if line.hasPrefix("END:VEVENT") {
                if var event = currentEvent {
                    if event.end == nil, let start = event.start {
                        event.end = start
                    }
                    events.append(event)
                }
                currentEvent = nil
                continue
            }
            if line.hasPrefix("X-WR-CALNAME:") {
                calendarName = extractValue(from: line)
                continue
            }
            guard var event = currentEvent else { continue }
            switch true {
            case line.hasPrefix("SUMMARY"):
                event.summary = extractValue(from: line)
            case line.hasPrefix("DESCRIPTION"):
                event.description = extractValue(from: line)
            case line.hasPrefix("UID"):
                event.uid = extractValue(from: line)
            case line.hasPrefix("LOCATION"):
                event.location = extractValue(from: line)
            case line.hasPrefix("DTSTART"):
                event.start = try parseDate(from: line)
            case line.hasPrefix("DTEND"):
                event.end = try parseDate(from: line)
            default:
                break
            }
            currentEvent = event
        }
        let validEvents = events.compactMap { event -> Event? in
            guard event.start != nil else { return nil }
            return event
        }
        guard !validEvents.isEmpty else {
            throw ICSParserError.noEvents
        }
        let sortedEvents = validEvents.sorted { lhs, rhs in
            guard let left = lhs.start, let right = rhs.start else { return false }
            return left < right
        }
        guard let tripStart = sortedEvents.first?.start, let tripEnd = sortedEvents.compactMap({ $0.end ?? $0.start }).max() else {
            throw ICSParserError.noEvents
        }
        var segments: [TripSegment] = []
        var locationMap: [String: (start: Date, end: Date)] = [:]
        var modes: Set<TripTravelMode> = []
        
        for event in sortedEvents {
            guard let start = event.start else { continue }
            let end = event.end ?? start
            let summary = event.summary ?? "Event"
            let notes = event.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
            let mode = inferTravelMode(from: summary, description: notes)
            if let mode {
                modes.insert(mode)
            }
            let type = inferSegmentType(from: summary, travelMode: mode)
            let segment = TripSegment(
                title: summary,
                notes: notes,
                location: location,
                startDate: start,
                endDate: end,
                segmentType: type,
                travelMode: mode,
                sourceIdentifier: event.uid
            )
            segments.append(segment)
            if let location {
                if var existing = locationMap[location] {
                    existing.start = min(existing.start, start)
                    existing.end = max(existing.end, end)
                    locationMap[location] = existing
                } else {
                    locationMap[location] = (start, end)
                }
            }
        }
        let destinations = locationMap.map { key, value in
            TripDestination(name: key, arrival: value.start, departure: value.end)
        }.sorted(by: { $0.arrival < $1.arrival })
        let tripName = calendarName ?? sortedEvents.first?.summary ?? destinations.first?.name ?? "Imported Trip"
        return ICSParsedTrip(
            name: tripName,
            calendarName: calendarName,
            startDate: tripStart,
            endDate: tripEnd,
            destinations: destinations,
            segments: segments,
            travelModes: Array(modes)
        )
    }
    
    private func unfoldLines(from raw: String) -> [String] {
        var unfolded: [String] = []
        for line in raw.components(separatedBy: .newlines) {
            if let last = unfolded.last, line.hasPrefix(" ") || line.hasPrefix("\t") {
                unfolded[unfolded.count - 1] = last + line.dropFirst()
            } else {
                unfolded.append(line)
            }
        }
        return unfolded.filter { !$0.isEmpty }
    }
    
    private func extractValue(from line: String) -> String {
        guard let separatorIndex = line.firstIndex(of: ":") else { return line }
        return String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseDate(from line: String) throws -> Date {
        let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw ICSParserError.invalidDate(line) }
        let metadata = parts[0]
        let rawValue = parts[1]
        let metadataComponents = metadata.split(separator: ";").map(String.init)
        let parameterComponents = metadataComponents.dropFirst()
        var timeZone: TimeZone?
        var isAllDay = false
        for component in parameterComponents {
            if component.uppercased().hasPrefix("TZID=") {
                let identifier = component.dropFirst(5)
                timeZone = TimeZone(identifier: String(identifier))
            }
            if component.uppercased().contains("VALUE=DATE") {
                isAllDay = true
            }
        }
        if rawValue.count == 8 {
            isAllDay = true
        }
        if isAllDay {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = timeZone ?? TimeZone(secondsFromGMT: 0)
            guard let date = formatter.date(from: rawValue) else {
                throw ICSParserError.invalidDate(rawValue)
            }
            return date
        }
        if rawValue.hasSuffix("Z") {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: rawValue) {
                return date
            }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: rawValue) {
                return date
            }
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = timeZone ?? TimeZone(secondsFromGMT: 0)
        if let date = formatter.date(from: rawValue) {
            return date
        }
        throw ICSParserError.invalidDate(rawValue)
    }
    
    private func inferTravelMode(from summary: String, description: String?) -> TripTravelMode? {
        let combined = (summary + " " + (description ?? "")).lowercased()
        if combined.contains("flight") || combined.contains("airline") || combined.contains("terminal") {
            return .flight
        }
        if combined.contains("train") || combined.contains("rail") {
            return .train
        }
        if combined.contains("bus") || combined.contains("coach") {
            return .bus
        }
        if combined.contains("ferry") || combined.contains("boat") || combined.contains("cruise") {
            return .boat
        }
        if combined.contains("drive") || combined.contains("rental car") || combined.contains("car pick") {
            return .car
        }
        if combined.contains("walk") || combined.contains("walking") {
            return .walking
        }
        if combined.contains("metro") || combined.contains("subway") || combined.contains("transit") {
            return .publicTransit
        }
        if combined.contains("uber") || combined.contains("lyft") || combined.contains("rideshare") {
            return .rideshare
        }
        return nil
    }
    
    private func inferSegmentType(from summary: String, travelMode: TripTravelMode?) -> TripSegmentType {
        if travelMode != nil {
            return .transport
        }
        let lowercased = summary.lowercased()
        if lowercased.contains("hotel") || lowercased.contains("check-in") || lowercased.contains("lodging") {
            return .lodging
        }
        if lowercased.contains("note") || lowercased.contains("reminder") {
            return .note
        }
        return .activity
    }
}

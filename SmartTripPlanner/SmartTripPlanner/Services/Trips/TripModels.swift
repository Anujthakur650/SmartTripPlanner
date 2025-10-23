import Foundation

struct Trip: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var destinations: [TripDestination]
    var startDate: Date
    var endDate: Date
    var participants: [TripParticipant]
    var preferredTravelModes: [TripTravelMode]
    var segments: [TripSegment]
    var notes: String?
    var source: TripSource
    var createdAt: Date
    var updatedAt: Date
    var lastSyncedAt: Date?
    
    init(id: UUID = UUID(),
         name: String,
         destinations: [TripDestination],
         startDate: Date,
         endDate: Date,
         participants: [TripParticipant],
         preferredTravelModes: [TripTravelMode] = [],
         segments: [TripSegment] = [],
         notes: String? = nil,
         source: TripSource = TripSource(kind: .manual),
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         lastSyncedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.destinations = destinations.sorted(by: { $0.arrival < $1.arrival })
        self.startDate = startDate
        self.endDate = endDate
        self.participants = participants
        self.preferredTravelModes = preferredTravelModes.removingDuplicates()
        self.segments = segments.sorted(by: { $0.startDate < $1.startDate })
        self.notes = notes
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
    }
    
    var primaryDestination: String {
        destinations.first?.name ?? ""
    }
    
    var durationInDays: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day.map { $0 + 1 } ?? 1
    }
    
    var isUpcoming: Bool {
        startDate > Date()
    }
    
    var isPast: Bool {
        endDate < Date()
    }
    
    var isOngoing: Bool {
        !isUpcoming && !isPast
    }
    
    var allTravelModes: Set<TripTravelMode> {
        var combined = Set(preferredTravelModes)
        combined.formUnion(segments.compactMap { $0.travelMode })
        return combined
    }
    
    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        let tokens = searchText.lowercased().split(separator: " ")
        let haystack = [
            name.lowercased(),
            primaryDestination.lowercased(),
            destinations.map { $0.name.lowercased() }.joined(separator: " "),
            participants.map { $0.name.lowercased() }.joined(separator: " "),
        ].joined(separator: " ")
        return tokens.allSatisfy { haystack.contains($0) }
    }
    
    func contains(mode: TripTravelMode) -> Bool {
        allTravelModes.contains(mode)
    }
    
    func updating(_ transform: (inout Trip) -> Void) -> Trip {
        var copy = self
        transform(&copy)
        copy.updatedAt = Date()
        return copy
    }
    
    func withUpdatedValues(name: String,
                           destinations: [TripDestination],
                           startDate: Date,
                           endDate: Date,
                           participants: [TripParticipant],
                           preferredTravelModes: [TripTravelMode],
                           segments: [TripSegment],
                           notes: String?) -> Trip {
        Trip(
            id: id,
            name: name,
            destinations: destinations,
            startDate: startDate,
            endDate: endDate,
            participants: participants,
            preferredTravelModes: preferredTravelModes,
            segments: segments,
            notes: notes,
            source: source,
            createdAt: createdAt,
            updatedAt: Date(),
            lastSyncedAt: nil
        )
    }
}

struct TripDestination: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var arrival: Date
    var departure: Date
    var notes: String?
    
    init(id: UUID = UUID(), name: String, arrival: Date, departure: Date, notes: String? = nil) {
        self.id = id
        self.name = name
        self.arrival = arrival
        self.departure = departure
        self.notes = notes
    }
}

struct TripParticipant: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var contact: String?
    
    init(id: UUID = UUID(), name: String, contact: String? = nil) {
        self.id = id
        self.name = name
        self.contact = contact
    }
}

struct TripSegment: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var notes: String?
    var location: String?
    var startDate: Date
    var endDate: Date?
    var segmentType: TripSegmentType
    var travelMode: TripTravelMode?
    var sourceIdentifier: String?
    
    init(id: UUID = UUID(),
         title: String,
         notes: String? = nil,
         location: String? = nil,
         startDate: Date,
         endDate: Date? = nil,
         segmentType: TripSegmentType = .activity,
         travelMode: TripTravelMode? = nil,
         sourceIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.segmentType = segmentType
        self.travelMode = travelMode
        self.sourceIdentifier = sourceIdentifier
    }
}

enum TripSegmentType: String, Codable, CaseIterable, Identifiable {
    case transport
    case lodging
    case activity
    case note
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .transport: return "Transport"
        case .lodging: return "Lodging"
        case .activity: return "Activity"
        case .note: return "Note"
        }
    }
}

enum TripTravelMode: String, Codable, CaseIterable, Identifiable {
    case flight
    case train
    case bus
    case car
    case boat
    case walking
    case publicTransit
    case rideshare
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .flight: return "Flight"
        case .train: return "Train"
        case .bus: return "Bus"
        case .car: return "Car"
        case .boat: return "Boat"
        case .walking: return "Walking"
        case .publicTransit: return "Transit"
        case .rideshare: return "Rideshare"
        case .other: return "Other"
        }
    }
    
    var systemImage: String {
        switch self {
        case .flight: return "airplane"
        case .train: return "train.side.front.car"
        case .bus: return "bus.fill"
        case .car: return "car.fill"
        case .boat: return "ferry.fill"
        case .walking: return "figure.walk"
        case .publicTransit: return "tram.fill"
        case .rideshare: return "car.side"
        case .other: return "mappin.and.ellipse"
        }
    }
}

struct TripSource: Codable, Hashable {
    enum Kind: String, Codable {
        case manual
        case ics
        case pkpass
        case template
    }
    
    var kind: Kind
    var reference: String?
    var rawPayload: String?
    var metadata: [String: String]?
    
    init(kind: Kind, reference: String? = nil, rawPayload: String? = nil, metadata: [String: String]? = nil) {
        self.kind = kind
        self.reference = reference
        self.rawPayload = rawPayload
        self.metadata = metadata
    }
}

extension Array where Element: Hashable {
    fileprivate func removingDuplicates() -> [Element] {
        var seen: Set<Element> = []
        return filter { element in
            if seen.contains(element) {
                return false
            }
            seen.insert(element)
            return true
        }
    }
}

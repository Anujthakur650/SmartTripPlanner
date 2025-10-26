import Foundation

struct TripDraft: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var startDate: Date
    var endDate: Date
    var destinations: [TripDestinationDraft]
    var participants: [TripParticipantDraft]
    var preferredTravelModes: Set<TripTravelMode>
    var segments: [TripSegmentDraft]
    var notes: String
    var sourceKind: TripSource.Kind
    
    init(now: Date = Date()) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 3, to: start) ?? start
        self.name = ""
        self.startDate = start
        self.endDate = end
        self.destinations = [TripDestinationDraft(name: "", arrival: start, departure: end, notes: "")]
        self.participants = []
        self.preferredTravelModes = []
        self.segments = []
        self.notes = ""
        self.sourceKind = .manual
    }
    
    init(trip: Trip) {
        self.name = trip.name
        self.startDate = trip.startDate
        self.endDate = trip.endDate
        self.destinations = trip.destinations.map { TripDestinationDraft(destination: $0) }
        self.participants = trip.participants.map { TripParticipantDraft(participant: $0) }
        self.preferredTravelModes = Set(trip.preferredTravelModes)
        self.segments = trip.segments.map { TripSegmentDraft(segment: $0) }
        self.notes = trip.notes ?? ""
        self.sourceKind = trip.source.kind
    }
    
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var normalizedNotes: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    mutating func ensureChronology() {
        if startDate > endDate {
            endDate = startDate
        }
        destinations = destinations.map { destination in
            var copy = destination
            if copy.arrival < startDate {
                copy.arrival = startDate
            }
            if copy.departure < copy.arrival {
                copy.departure = copy.arrival
            }
            if copy.departure > endDate {
                copy.departure = endDate
            }
            return copy
        }
        segments = segments.map { segment in
            var copy = segment
            if copy.startDate < startDate {
                copy.startDate = startDate
            }
            if let end = copy.endDate, end < copy.startDate {
                copy.endDate = copy.startDate
            }
            return copy
        }
    }
    
    func makeDestinations() -> [TripDestination] {
        destinations
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { $0.makeDestination() }
            .sorted(by: { $0.arrival < $1.arrival })
    }
    
    func makeParticipants() -> [TripParticipant] {
        participants
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { $0.makeParticipant() }
    }
    
    func makeSegments() -> [TripSegment] {
        segments.map { $0.makeSegment() }.sorted(by: { $0.startDate < $1.startDate })
    }
}

struct TripDestinationDraft: Identifiable, Hashable {
    var id: UUID
    var name: String
    var arrival: Date
    var departure: Date
    var notes: String
    
    init(id: UUID = UUID(), name: String, arrival: Date, departure: Date, notes: String) {
        self.id = id
        self.name = name
        self.arrival = arrival
        self.departure = departure
        self.notes = notes
    }
    
    init(destination: TripDestination) {
        self.id = destination.id
        self.name = destination.name
        self.arrival = destination.arrival
        self.departure = destination.departure
        self.notes = destination.notes ?? ""
    }
    
    func makeDestination() -> TripDestination {
        TripDestination(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), arrival: arrival, departure: departure, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
    }
}

struct TripParticipantDraft: Identifiable, Hashable {
    var id: UUID
    var name: String
    var contact: String
    
    init(id: UUID = UUID(), name: String, contact: String) {
        self.id = id
        self.name = name
        self.contact = contact
    }
    
    init(participant: TripParticipant) {
        self.id = participant.id
        self.name = participant.name
        self.contact = participant.contact ?? ""
    }
    
    func makeParticipant() -> TripParticipant {
        TripParticipant(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), contact: contact.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
    }
}

struct TripSegmentDraft: Identifiable, Hashable {
    var id: UUID
    var title: String
    var notes: String
    var location: String
    var startDate: Date
    var endDate: Date?
    var segmentType: TripSegmentType
    var travelMode: TripTravelMode?
    
    init(id: UUID = UUID(), title: String, notes: String, location: String, startDate: Date, endDate: Date?, segmentType: TripSegmentType, travelMode: TripTravelMode?) {
        self.id = id
        self.title = title
        self.notes = notes
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.segmentType = segmentType
        self.travelMode = travelMode
    }
    
    init(segment: TripSegment) {
        self.id = segment.id
        self.title = segment.title
        self.notes = segment.notes ?? ""
        self.location = segment.location ?? ""
        self.startDate = segment.startDate
        self.endDate = segment.endDate
        self.segmentType = segment.segmentType
        self.travelMode = segment.travelMode
    }
    
    func makeSegment() -> TripSegment {
        TripSegment(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            startDate: startDate,
            endDate: endDate,
            segmentType: segmentType,
            travelMode: travelMode,
            sourceIdentifier: nil
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

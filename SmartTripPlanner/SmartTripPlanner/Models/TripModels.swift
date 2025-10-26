import Foundation

enum TravelReservationKind: String, Codable, CaseIterable, Hashable {
    case flight
    case hotel
    case carRental
    case train
    case cruise
    case dining
    case activity
    case other
}

struct ReservationLocation: Codable, Hashable {
    var name: String
    var address: String?
    var coordinate: Coordinate?
    var code: String?
    var timeZoneIdentifier: String?
    var notes: String?
    
    init(name: String,
         address: String? = nil,
         coordinate: Coordinate? = nil,
         code: String? = nil,
         timeZoneIdentifier: String? = nil,
         notes: String? = nil) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.code = code
        self.timeZoneIdentifier = timeZoneIdentifier
        self.notes = notes
    }
}

struct TravelReservation: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: TravelReservationKind
    var title: String
    var provider: String?
    var confirmationCode: String?
    var travelers: [String]
    var startDate: Date?
    var endDate: Date?
    var origin: ReservationLocation?
    var destination: ReservationLocation?
    var notes: String?
    var rawEmailIdentifier: String?
    var attachments: [String]
    
    init(id: UUID = UUID(),
         kind: TravelReservationKind,
         title: String,
         provider: String? = nil,
         confirmationCode: String? = nil,
         travelers: [String] = [],
         startDate: Date? = nil,
         endDate: Date? = nil,
         origin: ReservationLocation? = nil,
         destination: ReservationLocation? = nil,
         notes: String? = nil,
         rawEmailIdentifier: String? = nil,
         attachments: [String] = []) {
        self.id = id
        self.kind = kind
        self.title = title
        self.provider = provider
        self.confirmationCode = confirmationCode
        self.travelers = travelers
        self.startDate = startDate
        self.endDate = endDate
        self.origin = origin
        self.destination = destination
        self.notes = notes
        self.rawEmailIdentifier = rawEmailIdentifier
        self.attachments = attachments
    }
}

struct ItineraryItem: Identifiable, Codable, Hashable {
    enum ItemType: String, Codable, CaseIterable {
        case reservation
        case activity
        case reminder
        case note
    }
    
    var id: UUID
    var title: String
    var detail: String?
    var type: ItemType
    var reservation: TravelReservation?
    var startDate: Date?
    var endDate: Date?
    var location: ReservationLocation?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(),
         title: String,
         detail: String? = nil,
         type: ItemType,
         reservation: TravelReservation? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         location: ReservationLocation? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.detail = detail
        self.type = type
        self.reservation = reservation
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Trip: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var description: String?
    var notes: String?
    var reservations: [TravelReservation]
    var itineraryItems: [ItineraryItem]
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(),
         name: String,
         destination: String,
         startDate: Date,
         endDate: Date,
         description: String? = nil,
         notes: String? = nil,
         reservations: [TravelReservation] = [],
         itineraryItems: [ItineraryItem] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.description = description
        self.notes = notes
        self.reservations = reservations.sorted(by: Trip.defaultReservationSort)
        self.itineraryItems = itineraryItems.sorted(by: Trip.defaultItinerarySort)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var days: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }
    
    func updatingReservations(_ reservations: [TravelReservation]) -> Trip {
        Trip(id: id,
             name: name,
             destination: destination,
             startDate: startDate,
             endDate: endDate,
             description: description,
             notes: notes,
             reservations: reservations,
             itineraryItems: itineraryItems,
             createdAt: createdAt,
             updatedAt: Date())
    }
    
    func updatingItinerary(_ itinerary: [ItineraryItem]) -> Trip {
        Trip(id: id,
             name: name,
             destination: destination,
             startDate: startDate,
             endDate: endDate,
             description: description,
             notes: notes,
             reservations: reservations,
             itineraryItems: itinerary,
             createdAt: createdAt,
             updatedAt: Date())
    }
    
    private static func defaultReservationSort(lhs: TravelReservation, rhs: TravelReservation) -> Bool {
        switch (lhs.startDate, rhs.startDate) {
        case let (l?, r?):
            return l < r
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
    
    private static func defaultItinerarySort(lhs: ItineraryItem, rhs: ItineraryItem) -> Bool {
        switch (lhs.startDate, rhs.startDate) {
        case let (l?, r?):
            if l == r {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return l < r
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

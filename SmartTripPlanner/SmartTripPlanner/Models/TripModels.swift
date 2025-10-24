import Foundation
import CloudKit

struct Trip: Identifiable, Codable, Hashable, Sendable, CloudSyncable {
    enum Status: String, Codable, CaseIterable, Sendable {
        case planning
        case booked
        case inProgress
        case completed
        case cancelled

        var displayName: String {
            switch self {
            case .planning: return "Planning"
            case .booked: return "Booked"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }
    }

    var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var status: Status
    var notes: String
    var itinerary: [ItineraryItem]
    var packingItems: [PackingItem]
    var documents: [TravelDocument]
    var collaborators: [Collaborator]
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        status: Status = .planning,
        notes: String = "",
        itinerary: [ItineraryItem] = [],
        packingItems: [PackingItem] = [],
        documents: [TravelDocument] = [],
        collaborators: [Collaborator] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.notes = notes
        self.itinerary = itinerary
        self.packingItems = packingItems
        self.documents = documents
        self.collaborators = collaborators
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
    }

    static var recordType: CKRecord.RecordType { "Trip" }

    mutating func touch() {
        updatedAt = Date()
    }

    var durationInDays: Int {
        max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0, 0)
    }

    var formattedDateRange: String {
        let formatter = Trip.dateFormatter
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var isOngoing: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var nextItineraryItem: ItineraryItem? {
        itinerary
            .sorted(by: { $0.startDate < $1.startDate })
            .first(where: { $0.startDate > Date() })
    }

    static func syncIdentifier(for id: UUID) -> String {
        id.uuidString
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct ItineraryItem: Identifiable, Codable, Hashable, Sendable {
    enum Category: String, Codable, CaseIterable, Sendable {
        case flight
        case lodging
        case transportation
        case dining
        case activity
        case meeting
        case other

        var displayName: String {
            switch self {
            case .flight: return "Flight"
            case .lodging: return "Lodging"
            case .transportation: return "Transportation"
            case .dining: return "Dining"
            case .activity: return "Activity"
            case .meeting: return "Meeting"
            case .other: return "Other"
            }
        }
    }

    struct Reminder: Identifiable, Codable, Hashable, Sendable {
        var id: UUID
        var offset: TimeInterval
        var message: String

        init(id: UUID = UUID(), offset: TimeInterval, message: String) {
            self.id = id
            self.offset = offset
            self.message = message
        }
    }

    var id: UUID
    var title: String
    var locationName: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var category: Category
    var reminders: [Reminder]

    init(
        id: UUID = UUID(),
        title: String,
        locationName: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        category: Category = .other,
        reminders: [Reminder] = []
    ) {
        self.id = id
        self.title = title
        self.locationName = locationName
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.category = category
        self.reminders = reminders
    }
}

struct PackingItem: Identifiable, Codable, Hashable, Sendable {
    enum Category: String, Codable, CaseIterable, Sendable {
        case clothing
        case toiletries
        case electronics
        case documentation
        case essentials
        case medicine
        case other

        var displayName: String {
            switch self {
            case .clothing: return "Clothing"
            case .toiletries: return "Toiletries"
            case .electronics: return "Electronics"
            case .documentation: return "Documentation"
            case .essentials: return "Essentials"
            case .medicine: return "Medicine"
            case .other: return "Other"
            }
        }
    }

    let id: UUID
    var name: String
    var quantity: Int
    var category: Category
    var isPacked: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int = 1,
        category: Category = .essentials,
        isPacked: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = max(1, quantity)
        self.category = category
        self.isPacked = isPacked
        self.notes = notes
    }
}

struct TravelDocument: Identifiable, Codable, Hashable, Sendable {
    enum DocumentType: String, Codable, CaseIterable, Sendable {
        case passport
        case ticket
        case reservation
        case insurance
        case visa
        case health
        case custom

        var displayName: String {
            switch self {
            case .passport: return "Passport"
            case .ticket: return "Ticket"
            case .reservation: return "Reservation"
            case .insurance: return "Insurance"
            case .visa: return "Visa"
            case .health: return "Health"
            case .custom: return "Other"
            }
        }

        var iconName: String {
            switch self {
            case .passport: return "person.text.rectangle"
            case .ticket: return "ticket"
            case .reservation: return "calendar.badge.clock"
            case .insurance: return "shield.fill"
            case .visa: return "checkmark.shield"
            case .health: return "cross.case.fill"
            case .custom: return "doc"
            }
        }
    }

    var id: UUID
    var name: String
    var type: DocumentType
    var referenceCode: String?
    var expirationDate: Date?
    var notes: String?
    var fileIdentifier: String?

    init(
        id: UUID = UUID(),
        name: String,
        type: DocumentType,
        referenceCode: String? = nil,
        expirationDate: Date? = nil,
        notes: String? = nil,
        fileIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.referenceCode = referenceCode
        self.expirationDate = expirationDate
        self.notes = notes
        self.fileIdentifier = fileIdentifier
    }
}

struct Collaborator: Identifiable, Codable, Hashable, Sendable {
    enum Permission: String, Codable, CaseIterable, Sendable {
        case view
        case edit
    }

    var id: UUID
    var name: String
    var email: String
    var isOwner: Bool
    var permission: Permission

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        isOwner: Bool = false,
        permission: Permission = .view
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.isOwner = isOwner
        self.permission = permission
    }
}

extension Trip {
    static let sample: Trip = Trip(
        name: "Weekend in Paris",
        destination: "Paris, France",
        startDate: Date().addingTimeInterval(86_400 * 14),
        endDate: Date().addingTimeInterval(86_400 * 17),
        status: .planning,
        itinerary: [
            ItineraryItem(
                title: "Flight to Paris",
                locationName: "SFO International",
                startDate: Date().addingTimeInterval(86_400 * 14 + 18_000),
                endDate: Date().addingTimeInterval(86_400 * 14 + 24_000),
                category: .flight
            ),
            ItineraryItem(
                title: "Dinner Reservation",
                locationName: "Le Jules Verne",
                startDate: Date().addingTimeInterval(86_400 * 15 + 65_000),
                endDate: Date().addingTimeInterval(86_400 * 15 + 72_000),
                category: .dining
            )
        ],
        packingItems: [
            PackingItem(name: "Passport", category: .documentation),
            PackingItem(name: "Camera", category: .electronics)
        ],
        documents: [
            TravelDocument(name: "Flight Confirmation", type: .ticket),
            TravelDocument(name: "Hotel Reservation", type: .reservation)
        ],
        collaborators: [
            Collaborator(name: "Alex Johnson", email: "alex@example.com", isOwner: true, permission: .edit)
        ]
    )

    static func sample(named name: String) -> Trip {
        Trip(
            name: name,
            destination: "Sample Destination",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86_400 * 5)
        )
    }
}

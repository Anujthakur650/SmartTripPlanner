import Foundation
import SwiftData

// MARK: - Shared Protocols

protocol DeterministicIdentifiedEntity: AnyObject {
    var id: UUID { get set }
}

protocol TimestampedEntity: AnyObject {
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    func markUpdated()
}

extension TimestampedEntity {
    func markUpdated() {
        let now = Date()
        if createdAt > now {
            createdAt = now
        }
        updatedAt = now
    }
}

protocol SoftDeletableEntity: DeterministicIdentifiedEntity {
    var isDeleted: Bool { get set }
    var deletedAt: Date? { get set }
    func markDeleted()
}

extension SoftDeletableEntity {
    func markDeleted() {
        isDeleted = true
        deletedAt = Date()
    }
}

protocol CloudIdentifiableEntity: AnyObject {
    var cloudIdentifier: String? { get set }
    var lastSyncedAt: Date? { get set }
}

// MARK: - Schema Definition

enum TripDataSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            Trip.self,
            Segment.self,
            DayPlanItem.self,
            Place.self,
            Route.self,
            PackingItem.self,
            DocumentAsset.self,
            Collaborator.self,
            ActivityLog.self
        ]
    }

    enum SegmentTransport: String, Codable, CaseIterable {
        case flight
        case train
        case car
        case bus
        case ferry
        case bicycle
        case walking
        case transit
        case rideshare
        case custom
    }

    enum PackingItemCategory: String, Codable, CaseIterable {
        case clothing
        case documents
        case electronics
        case toiletries
        case medication
        case other
    }

    enum CollaboratorRole: String, Codable, CaseIterable {
        case owner
        case editor
        case viewer
    }

    enum ActivityKind: String, Codable, CaseIterable {
        case created
        case updated
        case deleted
        case synced
        case shared
        case custom
    }

    @Model final class UserProfile: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var email: String
        var phoneNumber: String?
        var homeAirportCode: String?
        @Relationship(deleteRule: .cascade, inverse: \Trip.owner) var trips: [Trip]
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            displayName: String,
            email: String,
            phoneNumber: String? = nil,
            homeAirportCode: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.email = email
            self.phoneNumber = phoneNumber
            self.homeAirportCode = homeAirportCode
            self.trips = []
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class Trip: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var name: String
        var summary: String?
        var startDate: Date
        var endDate: Date
        var currencyCode: String?
        var owner: UserProfile?
        @Relationship(deleteRule: .nullify, inverse: \Segment.trip) var segments: [Segment]
        @Relationship(deleteRule: .nullify, inverse: \DayPlanItem.trip) var dayPlanItems: [DayPlanItem]
        @Relationship(deleteRule: .nullify, inverse: \Route.trip) var routes: [Route]
        @Relationship(deleteRule: .nullify, inverse: \PackingItem.trip) var packingItems: [PackingItem]
        @Relationship(deleteRule: .nullify, inverse: \DocumentAsset.trip) var documents: [DocumentAsset]
        @Relationship(deleteRule: .nullify, inverse: \Collaborator.trip) var collaborators: [Collaborator]
        @Relationship(deleteRule: .cascade, inverse: \ActivityLog.trip) var activityLogs: [ActivityLog]
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            name: String,
            summary: String? = nil,
            startDate: Date,
            endDate: Date,
            currencyCode: String? = nil,
            owner: UserProfile? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.summary = summary
            self.startDate = startDate
            self.endDate = endDate
            self.currencyCode = currencyCode
            self.owner = owner
            self.segments = []
            self.dayPlanItems = []
            self.routes = []
            self.packingItems = []
            self.documents = []
            self.collaborators = []
            self.activityLogs = []
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class Segment: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var name: String
        var transport: SegmentTransport
        var notes: String?
        var departureDate: Date?
        var arrivalDate: Date?
        @Relationship(inverse: \Trip.segments) var trip: Trip?
        var origin: Place?
        var destination: Place?
        var route: Route?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            name: String,
            transport: SegmentTransport,
            notes: String? = nil,
            departureDate: Date? = nil,
            arrivalDate: Date? = nil,
            trip: Trip? = nil,
            origin: Place? = nil,
            destination: Place? = nil,
            route: Route? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.transport = transport
            self.notes = notes
            self.departureDate = departureDate
            self.arrivalDate = arrivalDate
            self.trip = trip
            self.origin = origin
            self.destination = destination
            self.route = route
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class DayPlanItem: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var title: String
        var notes: String?
        var scheduledDate: Date
        var order: Int
        @Relationship(inverse: \Trip.dayPlanItems) var trip: Trip?
        var segment: Segment?
        var place: Place?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            title: String,
            notes: String? = nil,
            scheduledDate: Date,
            order: Int,
            trip: Trip? = nil,
            segment: Segment? = nil,
            place: Place? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.title = title
            self.notes = notes
            self.scheduledDate = scheduledDate
            self.order = order
            self.trip = trip
            self.segment = segment
            self.place = place
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class Place: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var name: String
        var subtitle: String?
        var latitude: Double
        var longitude: Double
        var locality: String?
        var administrativeArea: String?
        var country: String?
        var isoCountryCode: String?
        var category: String?
        var mapItemIdentifier: String?
        var trip: Trip?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            name: String,
            subtitle: String? = nil,
            latitude: Double,
            longitude: Double,
            locality: String? = nil,
            administrativeArea: String? = nil,
            country: String? = nil,
            isoCountryCode: String? = nil,
            category: String? = nil,
            mapItemIdentifier: String? = nil,
            trip: Trip? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.subtitle = subtitle
            self.latitude = latitude
            self.longitude = longitude
            self.locality = locality
            self.administrativeArea = administrativeArea
            self.country = country
            self.isoCountryCode = isoCountryCode
            self.category = category
            self.mapItemIdentifier = mapItemIdentifier
            self.trip = trip
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class Route: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var name: String
        var distance: Double
        var expectedTravelTime: TimeInterval
        var transport: SegmentTransport
        var advisoryNotes: [String]
        var origin: Place?
        var destination: Place?
        @Relationship(inverse: \Trip.routes) var trip: Trip?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            name: String,
            distance: Double,
            expectedTravelTime: TimeInterval,
            transport: SegmentTransport,
            advisoryNotes: [String] = [],
            origin: Place? = nil,
            destination: Place? = nil,
            trip: Trip? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.distance = distance
            self.expectedTravelTime = expectedTravelTime
            self.transport = transport
            self.advisoryNotes = advisoryNotes
            self.origin = origin
            self.destination = destination
            self.trip = trip
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class PackingItem: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var name: String
        var notes: String?
        var isPacked: Bool
        var category: PackingItemCategory
        @Relationship(inverse: \Trip.packingItems) var trip: Trip?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            name: String,
            notes: String? = nil,
            isPacked: Bool = false,
            category: PackingItemCategory = .other,
            trip: Trip? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.notes = notes
            self.isPacked = isPacked
            self.category = category
            self.trip = trip
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class DocumentAsset: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var title: String
        var fileName: String
        var mimeType: String
        @Attribute(.externalStorage) var data: Data?
        var remoteURL: URL?
        @Relationship(inverse: \Trip.documents) var trip: Trip?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            title: String,
            fileName: String,
            mimeType: String,
            data: Data? = nil,
            remoteURL: URL? = nil,
            trip: Trip? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.title = title
            self.fileName = fileName
            self.mimeType = mimeType
            self.data = data
            self.remoteURL = remoteURL
            self.trip = trip
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class Collaborator: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var email: String
        var role: CollaboratorRole
        var displayName: String?
        var invitationStatus: String
        var trip: Trip?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            email: String,
            role: CollaboratorRole,
            displayName: String? = nil,
            invitationStatus: String = "pending",
            trip: Trip? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.email = email
            self.role = role
            self.displayName = displayName
            self.invitationStatus = invitationStatus
            self.trip = trip
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }

    @Model final class ActivityLog: SoftDeletableEntity, TimestampedEntity, CloudIdentifiableEntity {
        @Attribute(.unique) var id: UUID
        var kind: ActivityKind
        var message: String
        var metadata: [String: String]
        var actorIdentifier: String?
        var trip: Trip?
        var createdAt: Date
        var updatedAt: Date
        var isDeleted: Bool
        var deletedAt: Date?
        var cloudIdentifier: String?
        var lastSyncedAt: Date?

        init(
            id: UUID = UUID(),
            kind: ActivityKind,
            message: String,
            metadata: [String: String] = [:],
            actorIdentifier: String? = nil,
            trip: Trip? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDeleted: Bool = false,
            deletedAt: Date? = nil,
            cloudIdentifier: String? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.id = id
            self.kind = kind
            self.message = message
            self.metadata = metadata
            self.actorIdentifier = actorIdentifier
            self.trip = trip
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
            self.deletedAt = deletedAt
            self.cloudIdentifier = cloudIdentifier
            self.lastSyncedAt = lastSyncedAt
        }
    }
}

enum TripDataSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { TripDataSchemaV1.versionIdentifier }
    static var models: [any PersistentModel.Type] { TripDataSchemaV1.models }
}

enum TripDataMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TripDataSchemaV1.self] }

    static var stages: [SchemaMigrationStage] {
        []
    }
}

// MARK: - Namespaced Typealiases

typealias UserProfileRecord = TripDataSchemaV1.UserProfile
typealias TripRecord = TripDataSchemaV1.Trip
typealias SegmentRecord = TripDataSchemaV1.Segment
typealias DayPlanItemRecord = TripDataSchemaV1.DayPlanItem
typealias PlaceRecord = TripDataSchemaV1.Place
typealias RouteRecord = TripDataSchemaV1.Route
typealias PackingItemRecord = TripDataSchemaV1.PackingItem
typealias DocumentAssetRecord = TripDataSchemaV1.DocumentAsset
typealias CollaboratorRecord = TripDataSchemaV1.Collaborator
typealias ActivityLogRecord = TripDataSchemaV1.ActivityLog

typealias SegmentTransportKind = TripDataSchemaV1.SegmentTransport
typealias PackingItemCategoryKind = TripDataSchemaV1.PackingItemCategory
typealias CollaboratorRoleKind = TripDataSchemaV1.CollaboratorRole
typealias ActivityKind = TripDataSchemaV1.ActivityKind

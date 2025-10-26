import Foundation
#if canImport(PassKit)
import PassKit
#endif

@MainActor
final class TripsRepository: ObservableObject {
    enum RepositoryError: LocalizedError, Identifiable {
        case persistenceFailed(String)
        case invalidICS(String)
        case invalidTemplate(String)
        case invalidPKPass(String)
        case unsupportedImport
        case validation(String)
        case missingTrip
        
        var id: String { localizedDescription }
        
        var errorDescription: String? {
            switch self {
            case let .persistenceFailed(message):
                return "Unable to save trips: \(message)"
            case let .invalidICS(message):
                return "Calendar import failed: \(message)"
            case let .invalidTemplate(message):
                return "Template import failed: \(message)"
            case let .invalidPKPass(message):
                return "Pass import failed: \(message)"
            case .unsupportedImport:
                return "This type of import is not supported on this device."
            case let .validation(message):
                return message
            case .missingTrip:
                return "The trip could not be located."
            }
        }
    }
    
    struct Storage {
        let directory: URL
        let tripsURL: URL
        
        init(directory: URL) {
            self.directory = directory
            self.tripsURL = directory.appendingPathComponent("trips.json")
        }
        
        static func `default`() -> Storage {
            let root: URL
            if let appSupport = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
                root = appSupport.appendingPathComponent("Trips", isDirectory: true)
            } else {
                root = FileManager.default.temporaryDirectory.appendingPathComponent("Trips", isDirectory: true)
            }
            if !FileManager.default.fileExists(atPath: root.path) {
                try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            }
            return Storage(directory: root)
        }
        
        static func temporary(identifier: String = UUID().uuidString) -> Storage {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TripsTests-\(identifier)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return Storage(directory: dir)
        }
    }
    
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: RepositoryError?
    @Published private(set) var needsSync = false
    @Published private(set) var recentlyDeletedTrip: Trip?
    
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storage: Storage
    private let parser: ICSParser
    private let now: () -> Date
    
    init(storage: Storage = .default(), parser: ICSParser = ICSParser(), now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.parser = parser
        self.now = now
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        loadPersistedTrips()
    }
    
    func loadPersistedTrips() {
        guard FileManager.default.fileExists(atPath: storage.tripsURL.path) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try Data(contentsOf: storage.tripsURL)
            let decoded = try decoder.decode([Trip].self, from: data)
            trips = decoded.sorted(by: { $0.startDate < $1.startDate })
        } catch {
            lastError = .persistenceFailed(error.localizedDescription)
        }
    }
    
    func upsert(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip.updating { updated in
                updated.lastSyncedAt = nil
            }
        } else {
            var newTrip = trip
            newTrip.createdAt = now()
            newTrip.updatedAt = now()
            newTrip.lastSyncedAt = nil
            trips.append(newTrip)
        }
        trips.sort(by: { $0.startDate < $1.startDate })
        needsSync = true
        persistTrips()
    }
    
    func createTrip(name: String,
                    destinations: [TripDestination],
                    startDate: Date,
                    endDate: Date,
                    participants: [TripParticipant],
                    preferredTravelModes: [TripTravelMode],
                    segments: [TripSegment],
                    notes: String?,
                    source: TripSource = TripSource(kind: .manual)) throws -> Trip {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError.validation("Trip name cannot be empty.")
        }
        guard !destinations.isEmpty else {
            throw RepositoryError.validation("Please add at least one destination.")
        }
        guard startDate <= endDate else {
            throw RepositoryError.validation("The start date must be before the end date.")
        }
        let trip = Trip(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            destinations: destinations,
            startDate: startDate,
            endDate: endDate,
            participants: participants,
            preferredTravelModes: preferredTravelModes,
            segments: segments,
            notes: notes,
            source: source,
            createdAt: now(),
            updatedAt: now(),
            lastSyncedAt: nil
        )
        upsert(trip)
        return trip
    }
    
    func updateTrip(_ trip: Trip) throws {
        guard trips.contains(where: { $0.id == trip.id }) else {
            throw RepositoryError.missingTrip
        }
        upsert(trip)
    }
    
    func deleteTrip(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        recentlyDeletedTrip = trips.remove(at: index)
        needsSync = true
        persistTrips()
    }
    
    func restoreLastDeletedTrip() {
        guard let trip = recentlyDeletedTrip else { return }
        upsert(trip)
        recentlyDeletedTrip = nil
    }
    
    func importICS(data: Data, reference: String? = nil) throws -> Trip {
        do {
            let parsed = try parser.parse(data: data)
            let rawString = String(data: data, encoding: .utf8)
            let destinations = parsed.destinations.isEmpty ? [TripDestination(name: parsed.name, arrival: parsed.startDate, departure: parsed.endDate)] : parsed.destinations
            let trip = Trip(
                name: parsed.name,
                destinations: destinations,
                startDate: parsed.startDate,
                endDate: parsed.endDate,
                participants: [],
                preferredTravelModes: parsed.travelModes,
                segments: parsed.segments,
                notes: nil,
                source: TripSource(kind: .ics, reference: reference, rawPayload: rawString, metadata: parsed.calendarName.map { ["calendarName": $0] }),
                createdAt: now(),
                updatedAt: now(),
                lastSyncedAt: nil
            )
            upsert(trip)
            return trip
        } catch let error as ICSParserError {
            throw RepositoryError.invalidICS(error.localizedDescription)
        } catch {
            throw RepositoryError.invalidICS(error.localizedDescription)
        }
    }
    
    func importTemplate(data: Data, reference: String? = nil) throws -> Trip {
        do {
            let template = try decoder.decode(TripTemplate.self, from: data)
            let destinations = template.destinations.map { $0.makeDestination() }
            let participants = template.participants.map { $0.makeParticipant() }
            let segments = template.segments.map { $0.makeSegment() }
            let trip = Trip(
                name: template.name,
                destinations: destinations,
                startDate: template.startDate,
                endDate: template.endDate,
                participants: participants,
                preferredTravelModes: template.travelModes,
                segments: segments,
                notes: template.notes,
                source: TripSource(kind: .template, reference: reference, rawPayload: String(data: data, encoding: .utf8), metadata: template.metadata),
                createdAt: now(),
                updatedAt: now(),
                lastSyncedAt: nil
            )
            upsert(trip)
            return trip
        } catch {
            throw RepositoryError.invalidTemplate(error.localizedDescription)
        }
    }
    
    func importPKPass(data: Data, reference: String? = nil) throws -> Trip {
        #if canImport(PassKit)
        do {
            let pass = try PKPass(data: data)
            let name = [pass.organizationName, pass.localizedName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let startDate = pass.passActivationDate ?? pass.relevantDate ?? now()
            let endDate = pass.expirationDate ?? startDate
            let destinationName = pass.localizedDescription
            let segmentTitle = pass.localizedName.isEmpty ? "Pass" : pass.localizedName
            let segment = TripSegment(
                title: segmentTitle,
                notes: pass.localizedDescription,
                location: destinationName,
                startDate: startDate,
                endDate: endDate,
                segmentType: .transport,
                travelMode: inferMode(from: pass),
                sourceIdentifier: pass.serialNumber
            )
            let destination = TripDestination(name: destinationName.isEmpty ? name : destinationName, arrival: startDate, departure: endDate)
            let payload = data.base64EncodedString()
            let metadata = [
                "serialNumber": pass.serialNumber,
                "passType": pass.passType.rawValue,
            ]
            let trip = Trip(
                name: name.isEmpty ? "Imported Pass" : name,
                destinations: [destination],
                startDate: startDate,
                endDate: endDate,
                participants: [],
                preferredTravelModes: segment.travelMode.map { [$0] } ?? [],
                segments: [segment],
                notes: pass.localizedDescription,
                source: TripSource(kind: .pkpass, reference: reference, rawPayload: payload, metadata: metadata),
                createdAt: now(),
                updatedAt: now(),
                lastSyncedAt: nil
            )
            upsert(trip)
            return trip
        } catch {
            throw RepositoryError.invalidPKPass(error.localizedDescription)
        }
        #else
        throw RepositoryError.unsupportedImport
        #endif
    }
    
    func markSynced(at date: Date = Date()) {
        needsSync = false
        trips = trips.map { trip in
            var updated = trip
            updated.lastSyncedAt = date
            return updated
        }
        persistTrips()
    }
    
    private func persistTrips() {
        do {
            if !FileManager.default.fileExists(atPath: storage.directory.path) {
                try FileManager.default.createDirectory(at: storage.directory, withIntermediateDirectories: true)
            }
            let data = try encoder.encode(trips)
            try data.write(to: storage.tripsURL, options: [.atomic])
        } catch {
            lastError = .persistenceFailed(error.localizedDescription)
        }
    }
    
    #if canImport(PassKit)
    private func inferMode(from pass: PKPass) -> TripTravelMode? {
        switch pass.passType {
        case .boardingPass:
            switch pass.boardingPass?.transitType ?? .unknown {
            case .air: return .flight
            case .bus: return .bus
            case .train, .subway: return .train
            case .boat, .ferry: return .boat
            case .generic, .unknown:
                return .publicTransit
            @unknown default:
                return .publicTransit
            }
        case .coupon, .eventTicket, .storeCard, .generic, .payment:
            return .other
        @unknown default:
            return .other
        }
    }
    #endif
}

private struct TripTemplate: Codable {
    var name: String
    var startDate: Date
    var endDate: Date
    var destinations: [TripDestinationTemplate]
    var participants: [TripParticipantTemplate] = []
    var travelModes: [TripTravelMode] = []
    var segments: [TripSegmentTemplate] = []
    var notes: String?
    var metadata: [String: String]?
}

private struct TripDestinationTemplate: Codable {
    var id: UUID?
    var name: String
    var arrival: Date
    var departure: Date
    var notes: String?
    
    func makeDestination() -> TripDestination {
        TripDestination(id: id ?? UUID(), name: name, arrival: arrival, departure: departure, notes: notes)
    }
}

private struct TripParticipantTemplate: Codable {
    var id: UUID?
    var name: String
    var contact: String?
    
    func makeParticipant() -> TripParticipant {
        TripParticipant(id: id ?? UUID(), name: name, contact: contact)
    }
}

private struct TripSegmentTemplate: Codable {
    var id: UUID?
    var title: String
    var notes: String?
    var location: String?
    var startDate: Date
    var endDate: Date?
    var segmentType: TripSegmentType
    var travelMode: TripTravelMode?
    var sourceIdentifier: String?
    
    func makeSegment() -> TripSegment {
        TripSegment(
            id: id ?? UUID(),
            title: title,
            notes: notes,
            location: location,
            startDate: startDate,
            endDate: endDate,
            segmentType: segmentType,
            travelMode: travelMode,
            sourceIdentifier: sourceIdentifier
        )
    }
}

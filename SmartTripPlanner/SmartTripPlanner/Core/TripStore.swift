import Foundation

@MainActor
final class TripStore: ObservableObject {
    @Published private(set) var trips: [Trip]
    
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storeURL: URL
    
    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        let baseDirectory = directory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.storeURL = baseDirectory.appendingPathComponent("trip-store.json")
        if let existingTrips = try? loadTrips() {
            self.trips = existingTrips
        } else {
            self.trips = Trip.sampleTrips
            try? persistTrips(trips)
        }
    }
    
    func trip(id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }
    
    func add(_ trip: Trip) {
        var newTrip = trip
        newTrip.createdAt = Date()
        newTrip.updatedAt = Date()
        trips.append(newTrip)
        sortTrips()
        try? persistTrips(trips)
    }
    
    func update(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        var updatedTrip = trip
        updatedTrip.updatedAt = Date()
        trips[index] = updatedTrip
        sortTrips()
        try? persistTrips(trips)
    }
    
    func remove(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        try? persistTrips(trips)
    }
    
    func replace(with newTrips: [Trip]) {
        trips = newTrips
        sortTrips()
        try? persistTrips(trips)
    }
    
    func clear() {
        trips = []
        try? persistTrips(trips)
    }
    
    private func sortTrips() {
        trips.sort { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.startDate < rhs.startDate
        }
    }
    
    private func loadTrips() throws -> [Trip] {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            throw TripStoreError.missingFile
        }
        let data = try Data(contentsOf: storeURL)
        guard !data.isEmpty else {
            return []
        }
        return try decoder.decode([Trip].self, from: data)
    }
    
    private func persistTrips(_ trips: [Trip]) throws {
        let data = try encoder.encode(trips)
        let directory = storeURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: storeURL, options: .atomic)
    }
}

enum TripStoreError: LocalizedError {
    case missingFile
}

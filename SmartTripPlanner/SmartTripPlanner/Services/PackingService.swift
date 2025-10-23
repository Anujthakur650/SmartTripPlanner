import Foundation

protocol Syncing: AnyObject {
    func syncToCloud<T: Encodable>(data: T, recordType: String, recordID: String) async throws
}

extension SyncService: Syncing {}

@MainActor
final class PackingService: ObservableObject {
    struct PackingSession: Equatable {
        var trip: Trip
        var weather: WeatherReport
        var list: TripPackingList
    }
    
    private let generator: PackingListGenerator
    private let store: PackingListStore
    private let weatherService: WeatherService
    private weak var syncService: Syncing?
    private var sessions: [UUID: PackingSession] = [:]
    
    init(generator: PackingListGenerator = PackingListGenerator(),
         store: PackingListStore = PackingListStore(),
         weatherService: WeatherService,
         syncService: Syncing? = nil) {
        self.generator = generator
        self.store = store
        self.weatherService = weatherService
        self.syncService = syncService
    }
    
    func session(for trip: Trip, regenerateList: Bool = false, forceWeatherRefresh: Bool = false) async throws -> PackingSession {
        if !regenerateList && !forceWeatherRefresh, let cached = sessions[trip.id] {
            return cached
        }
        let weather: WeatherReport
        if trip.coordinate == nil {
            weather = placeholderWeather(for: trip)
        } else {
            do {
                weather = try await weatherService.weatherReport(for: trip, forceRefresh: forceWeatherRefresh)
            } catch {
                if let cached = weatherService.cachedReport(for: trip) {
                    weather = cached
                } else {
                    weather = placeholderWeather(for: trip)
                }
            }
        }
        let regenerate = regenerateList || store.loadList(for: trip.id) == nil
        var list = loadOrGenerateList(for: trip, weather: weather, regenerate: regenerate)
        list.setWeatherDigest(weather.digest())
        try store.saveList(list)
        let session = PackingSession(trip: trip, weather: weather, list: list)
        sessions[trip.id] = session
        await sync(list)
        return session
    }
    
    func cachedSession(for tripId: UUID) -> PackingSession? {
        sessions[tripId]
    }
    
    func togglePacked(itemID: UUID, for trip: Trip) async throws -> PackingSession {
        var session = try await ensureSession(for: trip)
        session.list.togglePacked(id: itemID)
        try store.saveList(session.list)
        sessions[trip.id] = session
        await sync(session.list)
        return session
    }
    
    func remove(itemID: UUID, for trip: Trip) async throws -> PackingSession {
        var session = try await ensureSession(for: trip)
        session.list.removeItem(id: itemID)
        try store.saveList(session.list)
        sessions[trip.id] = session
        await sync(session.list)
        return session
    }
    
    func addManualItem(name: String, category: PackingCategory, quantity: Int = 1, notes: String? = nil, trip: Trip) async throws -> PackingSession {
        var session = try await ensureSession(for: trip)
        let item = PackingListItem(name: name,
                                   category: category,
                                   quantity: max(quantity, 1),
                                   notes: notes,
                                   origin: .manual)
        session.list.addItem(item)
        try store.saveList(session.list)
        sessions[trip.id] = session
        await sync(session.list)
        return session
    }
    
    func updateItem(_ item: PackingListItem, trip: Trip) async throws -> PackingSession {
        var session = try await ensureSession(for: trip)
        session.list.updateItem(item)
        try store.saveList(session.list)
        sessions[trip.id] = session
        await sync(session.list)
        return session
    }
    
    func regenerateKeepingManualItems(for trip: Trip, forceWeatherRefresh: Bool = false) async throws -> PackingSession {
        let session = try await session(for: trip, regenerateList: true, forceWeatherRefresh: forceWeatherRefresh)
        return session
    }
    
    private func ensureSession(for trip: Trip) async throws -> PackingSession {
        if let existing = sessions[trip.id] {
            return existing
        }
        return try await session(for: trip)
    }
    
    private func loadOrGenerateList(for trip: Trip, weather: WeatherReport, regenerate: Bool) -> TripPackingList {
        let context = PackingContext(trip: trip, weather: weather)
        var list = store.loadList(for: trip.id) ?? TripPackingList(tripId: trip.id)
        if regenerate || list.weatherDigest != weather.digest() {
            let generatedItems = generator.generate(for: context)
            list.regenerate(with: generatedItems)
        }
        list.setWeatherDigest(weather.digest())
        return list
    }
    
    private func placeholderWeather(for trip: Trip) -> WeatherReport {
        let coordinate = trip.coordinate ?? Coordinate(latitude: 0, longitude: 0)
        return WeatherReport(tripId: trip.id,
                             cacheKey: "placeholder-\(trip.id.uuidString)",
                             location: coordinate,
                             period: trip.dateRange,
                             timezoneIdentifier: nil,
                             generatedAt: Date(),
                             source: .cache,
                             daily: [],
                             hourly: [],
                             providerMetadata: nil)
    }
    
    private func sync(_ list: TripPackingList) {
        guard let syncService else { return }
        Task {
            try? await syncService.syncToCloud(data: list, recordType: "PackingList", recordID: list.tripId.uuidString)
        }
    }
}

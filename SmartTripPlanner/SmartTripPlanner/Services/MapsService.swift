import Foundation
import MapKit
import CoreLocation

@MainActor
final class MapsService: NSObject, ObservableObject {
    enum MapServiceError: LocalizedError, Identifiable {
        case offline
        case searchFailed(message: String)
        case routingFailed(message: String, hasFallback: Bool)
        case locationPermissionDenied
        
        var id: String { localizedDescription }
        
        var errorDescription: String? {
            switch self {
            case .offline:
                return "You appear to be offline."
            case let .searchFailed(message):
                return message
            case let .routingFailed(message, _):
                return message
            case .locationPermissionDenied:
                return "Location permission denied."
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .offline:
                return "Reconnect to the internet to search for new places."
            case .searchFailed:
                return "Please try your search again."
            case let .routingFailed(_, hasFallback):
                return hasFallback ? "A previously saved route has been loaded." : "Try a different transport mode or check your connection."
            case .locationPermissionDenied:
                return "Enable location permissions in Settings to center the map on your position."
            }
        }
    }
    
    private struct SearchCacheKey: Hashable {
        let query: String
        let categories: Set<MapCategory>
    }
    
    private struct RouteRequest: Hashable {
        let source: Place
        let destination: Place
        let mode: TransportMode
        let includeAlternatives: Bool
    }
    
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var searchResults: [Place] = []
    @Published private(set) var suggestions: [MapSearchSuggestion] = []
    @Published private(set) var savedPlaces: [Place] = []
    @Published private(set) var savedRoutes: [SavedRoute] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var isRouting: Bool = false
    @Published private(set) var currentRoute: MKRoute?
    @Published private(set) var alternativeRoutes: [MKRoute] = []
    @Published private(set) var lastSearchError: MapServiceError?
    @Published private(set) var lastRoutingError: MapServiceError?
    @Published private(set) var offlineFallbackRoute: SavedRoute?
    @Published private(set) var currentTransportMode: TransportMode = .driving
    @Published private(set) var cachedSnapshotURL: URL?
    
    private let locationManager = CLLocationManager()
    private let searchCompleter = MKLocalSearchCompleter()
    private let analyticsService: AnalyticsService
    
    private var searchTask: Task<Void, Never>?
    private var routingTask: Task<Void, Never>?
    private var searchCache: [SearchCacheKey: [Place]] = [:]
    private var lastSearchKey: SearchCacheKey?
    private var lastRouteRequest: RouteRequest?
    private var persistenceLoaded = false
    
    private let offlineMapCache = OfflineMapCache()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private let placesURL: URL
    private let routesURL: URL
    
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
        let directory: URL
        if let appSupport = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            directory = appSupport.appendingPathComponent("Maps", isDirectory: true)
        } else {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("Maps", isDirectory: true)
        }
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.placesURL = directory.appendingPathComponent("places.json")
        self.routesURL = directory.appendingPathComponent("routes.json")
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        searchCompleter.delegate = self
    }
    
    func loadPersistedDataIfNeeded() {
        guard !persistenceLoaded else { return }
        persistenceLoaded = true
        loadSavedPlaces()
        loadSavedRoutes()
    }
    
    func updateSearchSuggestions(for fragment: String) {
        searchCompleter.queryFragment = fragment
    }
    
    func clearSearch() {
        searchResults = []
        lastSearchError = nil
    }
    
    func searchPlaces(for query: String, categories: Set<MapCategory>, near coordinate: CLLocationCoordinate2D?) async {
        searchTask?.cancel()
        lastSearchError = nil
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = SearchCacheKey(query: normalizedQuery.lowercased(), categories: categories)
        lastSearchKey = cacheKey
        if let cached = searchCache[cacheKey] {
            searchResults = cached
            analyticsService.log(map: .searchSucceeded, metadata: ["source": "cache", "query": normalizedQuery])
            return
        }
        isSearching = true
        analyticsService.log(map: .searchStarted, metadata: ["query": normalizedQuery])
        searchTask = Task { [weak self] in
            guard let self else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = normalizedQuery
            if let coordinate {
                request.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
            }
            let categorySet = categories.reduce(into: Set<MKPointOfInterestCategory>()) { result, category in
                result.formUnion(category.pointOfInterestCategories)
            }
            if !categorySet.isEmpty {
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: categorySet)
            }
            do {
                let response = try await MKLocalSearch(request: request).start()
                let places = response.mapItems.map { Place(mapItem: $0) }
                await MainActor.run {
                    self.isSearching = false
                    self.searchResults = places
                    self.searchCache[cacheKey] = places
                    self.analyticsService.log(map: .searchSucceeded, metadata: ["query": normalizedQuery, "count": "\(places.count)"])
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isSearching = false
                    let message = error.localizedDescription
                    self.lastSearchError = .searchFailed(message: message)
                    self.analyticsService.log(map: .searchFailed, metadata: ["query": normalizedQuery, "reason": message])
                }
            }
        }
    }
    
    func retryLastSearch() async {
        guard let lastSearchKey else { return }
        await searchPlaces(for: lastSearchKey.query, categories: lastSearchKey.categories, near: currentLocation?.coordinate)
    }
    
    func logSuggestionSelection(_ suggestion: MapSearchSuggestion) {
        analyticsService.log(map: .suggestionSelected, metadata: ["query": suggestion.formattedQuery])
    }
    
    func calculateRoute(from source: Place, to destination: Place, mode: TransportMode, includeAlternatives: Bool = true, isOnline: Bool) async {
        routingTask?.cancel()
        currentTransportMode = mode
        lastRoutingError = nil
        offlineFallbackRoute = nil
        cachedSnapshotURL = nil
        lastRouteRequest = RouteRequest(source: source, destination: destination, mode: mode, includeAlternatives: includeAlternatives)
        
        guard isOnline else {
            isRouting = false
            let fallback = savedRoute(from: source, to: destination, mode: mode)
            offlineFallbackRoute = fallback
            cachedSnapshotURL = await offlineMapCache.getCachedSnapshot(for: destination.coordinate.locationCoordinate)
            lastRoutingError = .offline
            analyticsService.log(map: .routeFailed, metadata: ["mode": mode.rawValue, "reason": "offline"])
            return
        }
        
        isRouting = true
        analyticsService.log(map: .routeRequested, metadata: ["mode": mode.rawValue])
        let request = MKDirections.Request()
        request.source = source.makeMapItem()
        request.destination = destination.makeMapItem()
        request.transportType = mode.mkTransportType
        request.requestsAlternateRoutes = includeAlternatives
        
        routingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await MKDirections(request: request).calculate()
                guard let primary = response.routes.first else {
                    throw NSError(domain: "MapsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No routes found"])
                }
                await MainActor.run {
                    self.currentRoute = primary
                    if response.routes.count > 1 {
                        self.alternativeRoutes = Array(response.routes.dropFirst())
                    } else {
                        self.alternativeRoutes = []
                    }
                    self.isRouting = false
                    self.analyticsService.log(map: .routeSucceeded, metadata: ["mode": mode.rawValue, "distance": "\(Int(primary.distance))"])
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.currentRoute = nil
                    self.alternativeRoutes = []
                    self.isRouting = false
                    let fallback = self.savedRoute(from: source, to: destination, mode: mode)
                    self.offlineFallbackRoute = fallback
                    let message = error.localizedDescription
                    self.lastRoutingError = .routingFailed(message: message, hasFallback: fallback != nil)
                    self.analyticsService.log(map: .routeFailed, metadata: ["mode": mode.rawValue, "reason": message])
                }
            }
        }
    }
    
    func retryLastRoute(isOnline: Bool) async {
        guard let request = lastRouteRequest else { return }
        await calculateRoute(from: request.source, to: request.destination, mode: request.mode, includeAlternatives: request.includeAlternatives, isOnline: isOnline)
    }
    
    func saveRoute(from source: Place, to destination: Place, mode: TransportMode) {
        guard let primaryRoute = currentRoute else { return }
        let alternatives = alternativeRoutes.map { routeSnapshot(from: $0) }
        let snapshot = routeSnapshot(from: primaryRoute)
        let savedRoute = SavedRoute(from: source, to: destination, mode: mode, primary: snapshot, alternatives: alternatives)
        replaceOrAppendRoute(savedRoute)
        persistRoutes()
        analyticsService.log(map: .routeSaved, metadata: ["mode": mode.rawValue, "distance": "\(Int(primaryRoute.distance))"])
    }
    
    func openInAppleMaps(place: Place) {
        analyticsService.log(map: .openInAppleMaps, metadata: ["type": "place"])
        place.makeMapItem().openInMaps()
    }
    
    func openRouteInAppleMaps(from source: Place, to destination: Place, mode: TransportMode) {
        analyticsService.log(map: .openInAppleMaps, metadata: ["type": "route", "mode": mode.rawValue])
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: mode.appleMapsLaunchOption]
        MKMapItem.openMaps(with: [source.makeMapItem(), destination.makeMapItem()], launchOptions: launchOptions)
    }
    
    func cacheSnapshot(for place: Place, radius: CLLocationDistance = 2_000) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.offlineMapCache.cacheMapSnapshot(for: place.coordinate.locationCoordinate, radius: radius)
                let cachedURL = await self.offlineMapCache.getCachedSnapshot(for: place.coordinate.locationCoordinate)
                await MainActor.run {
                    self.cachedSnapshotURL = cachedURL
                }
            } catch {
                // Snapshot caching is best-effort; ignore failures for now.
            }
        }
    }
    
    func cachedSnapshot(for place: Place) async -> URL? {
        await offlineMapCache.getCachedSnapshot(for: place.coordinate.locationCoordinate)
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func toggleBookmark(for place: Place) {
        if let index = savedPlaces.firstIndex(where: { $0.id == place.id }) {
            savedPlaces[index].isBookmarked.toggle()
            analyticsService.log(map: .placeBookmarkToggled, metadata: ["state": savedPlaces[index].isBookmarked ? "bookmarked" : "unbookmarked"])
            persistPlaces()
            return
        }
        var newPlace = place
        newPlace.isBookmarked.toggle()
        savePlace(newPlace)
        analyticsService.log(map: .placeBookmarkToggled, metadata: ["state": newPlace.isBookmarked ? "bookmarked" : "unbookmarked"])
    }
    
    func savePlace(_ place: Place, association: PlaceAssociation? = nil) {
        var updatedPlace = place
        if let association {
            updatedPlace.association = association
        }
        if let index = indexForPlace(updatedPlace) {
            let existing = savedPlaces[index]
            updatedPlace.createdAt = existing.createdAt
            savedPlaces[index] = merge(existing: existing, with: updatedPlace)
        } else {
            savedPlaces.append(updatedPlace)
        }
        savedPlaces.sort { $0.createdAt > $1.createdAt }
        persistPlaces()
        cacheSnapshot(for: updatedPlace)
        analyticsService.log(map: .placeSaved, metadata: ["name": updatedPlace.name])
    }
    
    func deleteSavedPlace(_ place: Place) {
        if let index = savedPlaces.firstIndex(where: { $0.id == place.id }) {
            savedPlaces.remove(at: index)
            persistPlaces()
        }
    }
    
    func savedRoute(from source: Place, to destination: Place, mode: TransportMode) -> SavedRoute? {
        savedRoutes.first(where: { route in
            route.mode == mode &&
            route.from.coordinateKey == source.coordinateKey &&
            route.to.coordinateKey == destination.coordinateKey
        })
    }
    
    // MARK: - Private helpers
    
    private func routeSnapshot(from route: MKRoute) -> RouteSnapshot {
        RouteSnapshot(name: route.name, expectedTravelTime: route.expectedTravelTime, distance: route.distance, advisoryNotices: route.advisoryNotices)
    }
    
    private func replaceOrAppendRoute(_ route: SavedRoute) {
        if let index = savedRoutes.firstIndex(where: { $0.from.coordinateKey == route.from.coordinateKey && $0.to.coordinateKey == route.to.coordinateKey && $0.mode == route.mode }) {
            savedRoutes[index] = route
        } else {
            savedRoutes.append(route)
        }
        savedRoutes.sort { $0.createdAt > $1.createdAt }
    }
    
    private func indexForPlace(_ place: Place) -> Int? {
        if let index = savedPlaces.firstIndex(where: { $0.id == place.id }) {
            return index
        }
        return savedPlaces.firstIndex(where: { $0.coordinateKey == place.coordinateKey })
    }
    
    private func merge(existing: Place, with updated: Place) -> Place {
        Place(
            id: existing.id,
            name: updated.name,
            subtitle: updated.subtitle.isEmpty ? existing.subtitle : updated.subtitle,
            coordinate: updated.coordinate,
            locality: updated.locality ?? existing.locality,
            administrativeArea: updated.administrativeArea ?? existing.administrativeArea,
            country: updated.country ?? existing.country,
            isoCountryCode: updated.isoCountryCode ?? existing.isoCountryCode,
            category: updated.category ?? existing.category,
            phoneNumber: updated.phoneNumber ?? existing.phoneNumber,
            url: updated.url ?? existing.url,
            mapItemIdentifier: updated.mapItemIdentifier ?? existing.mapItemIdentifier,
            isBookmarked: updated.isBookmarked || existing.isBookmarked,
            association: updated.association ?? existing.association,
            createdAt: existing.createdAt
        )
    }
    
    private func loadSavedPlaces() {
        guard let data = try? Data(contentsOf: placesURL) else { return }
        if let places = try? decoder.decode([Place].self, from: data) {
            savedPlaces = places
        }
    }
    
    private func loadSavedRoutes() {
        guard let data = try? Data(contentsOf: routesURL) else { return }
        if let routes = try? decoder.decode([SavedRoute].self, from: data) {
            savedRoutes = routes
        }
    }
    
    private func persistPlaces() {
        guard let data = try? encoder.encode(savedPlaces) else { return }
        try? data.write(to: placesURL)
    }
    
    private func persistRoutes() {
        guard let data = try? encoder.encode(savedRoutes) else { return }
        try? data.write(to: routesURL)
    }
}

extension MapsService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.map { MapSearchSuggestion(title: $0.title, subtitle: $0.subtitle) }
        Task { @MainActor in
            self.suggestions = suggestions
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}

extension MapsService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastSearchError = .searchFailed(message: error.localizedDescription)
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .denied, .restricted:
                self.lastSearchError = .locationPermissionDenied
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

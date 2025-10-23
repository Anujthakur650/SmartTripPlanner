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
    @Published private(set) var offlineStatusMessage: String?
    
    @available(iOS 17.0, *)
    @Published private(set) var offlineRegions: [OfflineMapRegionState] = []
    
    @available(iOS 17.0, *)
    @Published private(set) var offlineSuggestions: [OfflineRegionSuggestion] = []
    
    @available(iOS 17.0, *)
    @Published private(set) var offlineDownloads: [OfflineDownloadSnapshot] = []
    
    @available(iOS 17.0, *)
    @Published private(set) var offlineStorageUsage: OfflineStorageUsage = .zero
    
    private let locationManager = CLLocationManager()
    private let searchCompleter = MKLocalSearchCompleter()
    private let analyticsService: AnalyticsService
    
    private var searchTask: Task<Void, Never>?
    private var routingTask: Task<Void, Never>?
    private var searchCache: [SearchCacheKey: [Place]] = [:]
    private var lastSearchKey: SearchCacheKey?
    private var lastRouteRequest: RouteRequest?
    private var offlineFocusPlace: Place?
    private var persistenceLoaded = false
    
    @available(iOS 17.0, *)
    private let offlineMapManager = MKOfflineMapManager.shared
    
    @available(iOS 17.0, *)
    private var activeOfflineDownloads: [UUID: MKOfflineMapDownload] = [:]
    
    @available(iOS 17.0, *)
    private var activeOfflineDownloadTasks: [UUID: Task<Void, Never>] = [:]
    
    @available(iOS 17.0, *)
    private var suggestionIndex: [UUID: OfflineRegionSuggestion] = [:]
    
    @available(iOS 17.0, *)
    private var offlineMapsByIdentifier: [UUID: MKOfflineMap] = [:]
    
    @available(iOS 17.0, *)
    private var offlineSourceMetadata: [UUID: String] = [:]
    
    @available(iOS 17.0, *)
    private lazy var offlineByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()
    
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
    
    var supportsOfflineDownloads: Bool {
        if #available(iOS 17.0, *) {
            return true
        }
        return false
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
    
    func setOfflineFocus(_ place: Place?) {
        offlineFocusPlace = place
        if #available(iOS 17.0, *) {
            recalculateOfflineSuggestions()
        }
    }
    
    func calculateRoute(from source: Place, to destination: Place, mode: TransportMode, includeAlternatives: Bool = true, isOnline: Bool) async {
        routingTask?.cancel()
        currentTransportMode = mode
        lastRoutingError = nil
        offlineFallbackRoute = nil
        lastRouteRequest = RouteRequest(source: source, destination: destination, mode: mode, includeAlternatives: includeAlternatives)
        
        guard isOnline else {
            isRouting = false
            let fallback = savedRoute(from: source, to: destination, mode: mode)
            offlineFallbackRoute = fallback
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
        if #available(iOS 17.0, *) {
            recalculateOfflineSuggestions()
        }
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
        analyticsService.log(map: .placeSaved, metadata: ["name": updatedPlace.name])
        if #available(iOS 17.0, *) {
            recalculateOfflineSuggestions()
        }
    }
    
    func deleteSavedPlace(_ place: Place) {
        if let index = savedPlaces.firstIndex(where: { $0.id == place.id }) {
            savedPlaces.remove(at: index)
            persistPlaces()
            if #available(iOS 17.0, *) {
                recalculateOfflineSuggestions()
            }
        }
    }
    
    func savedRoute(from source: Place, to destination: Place, mode: TransportMode) -> SavedRoute? {
        savedRoutes.first(where: { route in
            route.mode == mode &&
            route.from.coordinateKey == source.coordinateKey &&
            route.to.coordinateKey == destination.coordinateKey
        })
    }
    
    // MARK: - Offline maps (iOS 17+)
    
    func refreshOfflineCollections() {
        guard supportsOfflineDownloads else { return }
        if #available(iOS 17.0, *) {
            updateOfflineCollections()
        }
    }
    
    func downloadOfflineRegion(_ suggestion: OfflineRegionSuggestion) {
        guard supportsOfflineDownloads else { return }
        if #available(iOS 17.0, *) {
            startOfflineDownload(for: suggestion)
        }
    }
    
    func cancelOfflineDownload(id: UUID) {
        guard supportsOfflineDownloads else { return }
        if #available(iOS 17.0, *) {
            guard let download = activeOfflineDownloads[id] else { return }
            download.cancel()
            activeOfflineDownloads[id] = nil
            activeOfflineDownloadTasks[id]?.cancel()
            activeOfflineDownloadTasks[id] = nil
            offlineDownloads.removeAll(where: { $0.id == id })
            offlineStatusMessage = "Cancelled offline map download."
            analyticsService.log(map: .offlineDownloadCancelled, metadata: ["identifier": id.uuidString])
        }
    }
    
    func deleteOfflineRegion(_ region: OfflineMapRegionState) {
        guard supportsOfflineDownloads else { return }
        if #available(iOS 17.0, *) {
            guard let map = offlineMapsByIdentifier[region.mapIdentifier] else { return }
            offlineMapManager.delete(map)
            offlineStatusMessage = "Removed offline region \(region.name)."
            analyticsService.log(map: .offlineRegionDeleted, metadata: ["identifier": region.mapIdentifier.uuidString])
            updateOfflineCollections()
        }
    }
    
    func updateOfflineRegion(_ region: OfflineMapRegionState) {
        guard supportsOfflineDownloads else { return }
        if #available(iOS 17.0, *) {
            guard let map = offlineMapsByIdentifier[region.mapIdentifier] else { return }
            let download = offlineMapManager.update(map)
            let downloadId = UUID()
            activeOfflineDownloads[downloadId] = download
            suggestionIndex[downloadId] = OfflineRegionSuggestion(id: downloadId, name: region.name, detail: region.subtitle, boundingRegion: region.boundingRegion, estimatedBytes: region.bytesOnDisk, sourceDescription: region.sourceDescription)
            startMonitoring(download: download, identifier: downloadId)
            offlineStatusMessage = "Updating offline region \(region.name)…"
            analyticsService.log(map: .offlineDownloadRequested, metadata: ["identifier": region.mapIdentifier.uuidString, "type": "update"])
        }
    }
    
    @available(iOS 17.0, *)
    private func startOfflineDownload(for suggestion: OfflineRegionSuggestion) {
        if activeOfflineDownloads[suggestion.id] != nil {
            return
        }
        suggestionIndex[suggestion.id] = suggestion
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        let region = MKOfflineMap.Region(region: suggestion.boundingRegion, mapConfiguration: configuration)
        let download = offlineMapManager.downloadMap(for: region)
        activeOfflineDownloads[suggestion.id] = download
        analyticsService.log(map: .offlineDownloadRequested, metadata: ["name": suggestion.name])
        offlineStatusMessage = "Downloading \(suggestion.name)…"
        startMonitoring(download: download, identifier: suggestion.id)
        updateDownloadSnapshot(id: suggestion.id, progress: 0, stateDescription: "Queued", source: suggestion.sourceDescription)
    }
    
    @available(iOS 17.0, *)
    private func startMonitoring(download: MKOfflineMapDownload, identifier: UUID) {
        let task = Task { [weak self] in
            guard let self else { return }
            for await status in download.status {
                await self.handle(downloadStatus: status, identifier: identifier)
            }
        }
        activeOfflineDownloadTasks[identifier] = task
    }
    
    @available(iOS 17.0, *)
    private func handle(downloadStatus status: MKOfflineMapDownload.Status, identifier: UUID) async {
        switch status {
        case .enqueued:
            updateDownloadSnapshot(id: identifier, progress: 0, stateDescription: "Queued", source: suggestionIndex[identifier]?.sourceDescription ?? "")
            if let name = suggestionIndex[identifier]?.name {
                offlineStatusMessage = "Queued download for \(name)."
            }
        case let .inProgress(progress):
            updateDownloadSnapshot(id: identifier, progress: progress.fractionCompleted, stateDescription: "Downloading", source: suggestionIndex[identifier]?.sourceDescription ?? "")
            let percent = Int(progress.fractionCompleted * 100)
            if let name = suggestionIndex[identifier]?.name {
                offlineStatusMessage = "Downloading \(name)… \(percent)%"
            }
        case let .informational(map):
            offlineSourceMetadata[map.identifier] = suggestionIndex[identifier]?.sourceDescription
        case let .complete(map):
            offlineSourceMetadata[map.identifier] = suggestionIndex[identifier]?.sourceDescription
            completeOfflineDownload(identifier: identifier, map: map)
        case .cancelled:
            completeOfflineDownload(identifier: identifier, map: nil, cancelled: true)
        case let .failed(error):
            completeOfflineDownload(identifier: identifier, map: nil, error: error)
        @unknown default:
            break
        }
    }
    
    @available(iOS 17.0, *)
    private func completeOfflineDownload(identifier: UUID, map: MKOfflineMap?, cancelled: Bool = false, error: Error? = nil) {
        activeOfflineDownloads[identifier] = nil
        activeOfflineDownloadTasks[identifier]?.cancel()
        activeOfflineDownloadTasks[identifier] = nil
        suggestionIndex[identifier] = nil
        if cancelled {
            offlineDownloads.removeAll(where: { $0.id == identifier })
            offlineStatusMessage = "Offline download cancelled."
            return
        }
        if let error {
            updateDownloadSnapshot(id: identifier, progress: 0, stateDescription: "Failed", source: "", replace: true)
            offlineStatusMessage = "Offline download failed: \(error.localizedDescription)"
            analyticsService.log(map: .offlineDownloadFailed, metadata: ["reason": error.localizedDescription])
            return
        }
        guard let map else { return }
        updateOfflineCollections()
        offlineStatusMessage = "Offline map \(map.name) ready."
        analyticsService.log(map: .offlineDownloadCompleted, metadata: ["identifier": map.identifier.uuidString])
    }
    
    @available(iOS 17.0, *)
    private func updateDownloadSnapshot(id: UUID, progress: Double, stateDescription: String, source: String, replace: Bool = false) {
        let clampedProgress = min(max(progress, 0), 1)
        if replace {
            offlineDownloads.removeAll(where: { $0.id == id })
        }
        if let index = offlineDownloads.firstIndex(where: { $0.id == id }) {
            offlineDownloads[index].progress = clampedProgress
            offlineDownloads[index].stateDescription = stateDescription
            offlineDownloads[index].sourceDescription = source
        } else {
            let suggestion = suggestionIndex[id]
            let snapshot = OfflineDownloadSnapshot(id: id, name: suggestion?.name ?? "Offline Region", detail: suggestion?.detail ?? "", progress: clampedProgress, stateDescription: stateDescription, sourceDescription: source.isEmpty ? (suggestion?.sourceDescription ?? "") : source)
            offlineDownloads.append(snapshot)
        }
        offlineDownloads.sort { $0.name < $1.name }
    }
    
    @available(iOS 17.0, *)
    private func updateOfflineCollections() {
        let maps = offlineMapManager.offlineMaps
        offlineMapsByIdentifier = Dictionary(uniqueKeysWithValues: maps.map { ($0.identifier, $0) })
        offlineRegions = maps.map { convert(map: $0) }
        offlineStorageUsage = OfflineStorageUsage(
            bytesUsed: maps.reduce(0) { partialResult, map in
                partialResult + (map.byteCount)
            },
            bytesAvailable: offlineMapManager.storageLimit
        )
        offlineRegions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        recalculateOfflineSuggestions()
    }
    
    @available(iOS 17.0, *)
    private func recalculateOfflineSuggestions() {
        var generated: [OfflineRegionSuggestion] = []
        var seenKeys = Set<String>()
        let downloadedKeys = Set(offlineRegions.map { regionHash($0.boundingRegion) })
        if let focus = offlineFocusPlace, let suggestion = makeSuggestion(for: focus, source: "Selected destination") {
            let key = regionHash(suggestion.boundingRegion)
            if !downloadedKeys.contains(key) {
                seenKeys.insert(key)
                generated.append(suggestion)
            }
        }
        for place in savedPlaces {
            guard let suggestion = makeSuggestion(for: place, source: place.isBookmarked ? "Bookmarked place" : "Saved place") else { continue }
            let key = regionHash(suggestion.boundingRegion)
            if downloadedKeys.contains(key) || seenKeys.contains(key) { continue }
            seenKeys.insert(key)
            generated.append(suggestion)
        }
        for route in savedRoutes {
            guard let suggestion = makeSuggestion(for: route) else { continue }
            let key = regionHash(suggestion.boundingRegion)
            if downloadedKeys.contains(key) || seenKeys.contains(key) { continue }
            seenKeys.insert(key)
            generated.append(suggestion)
        }
        generated.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        offlineSuggestions = generated
    }
    
    @available(iOS 17.0, *)
    private func makeSuggestion(for place: Place, source: String, span: CLLocationDegrees = 0.3) -> OfflineRegionSuggestion? {
        let region = MKCoordinateRegion(center: place.coordinate.locationCoordinate, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
        return OfflineRegionSuggestion(name: place.name, detail: place.addressDescription, boundingRegion: region, estimatedBytes: nil, sourceDescription: source)
    }
    
    @available(iOS 17.0, *)
    private func makeSuggestion(for route: SavedRoute) -> OfflineRegionSuggestion? {
        guard let region = region(for: [route.from.coordinate.locationCoordinate, route.to.coordinate.locationCoordinate]) else { return nil }
        let detail = "\(route.from.name) → \(route.to.name)"
        return OfflineRegionSuggestion(name: "Route to \(route.to.name)", detail: detail, boundingRegion: region, estimatedBytes: nil, sourceDescription: "Saved route")
    }
    
    @available(iOS 17.0, *)
    private func convert(map: MKOfflineMap) -> OfflineMapRegionState {
        let subtitle = makeSubtitle(for: map.boundingRegion)
        let source = offlineSourceMetadata[map.identifier] ?? "Downloaded region"
        let status: OfflineRegionStatus
        switch map.status {
        case .available:
            status = .available(updatedAt: map.lastUpdated)
        case .needsUpdate:
            status = .needsUpdate(updatedAt: map.lastUpdated)
        case .downloading:
            status = .downloading(progress: map.downloadProgress.fractionCompleted)
        case .failed:
            status = .failed(message: nil)
        case .unknown:
            status = .notDownloaded
        @unknown default:
            status = .notDownloaded
        }
        return OfflineMapRegionState(mapIdentifier: map.identifier, name: map.name, subtitle: subtitle, boundingRegion: map.boundingRegion, bytesOnDisk: map.byteCount, status: status, lastUpdated: map.lastUpdated, sourceDescription: source)
    }
    
    @available(iOS 17.0, *)
    private func makeSubtitle(for region: MKCoordinateRegion) -> String {
        let center = region.center
        return String(format: "Lat %.2f°, Lon %.2f° (%.2f × %.2f°)", center.latitude, center.longitude, region.span.latitudeDelta, region.span.longitudeDelta)
    }
    
    @available(iOS 17.0, *)
    private func regionHash(_ region: MKCoordinateRegion) -> String {
        String(format: "%.3f-%.3f-%.3f-%.3f", region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta)
    }
    
    @available(iOS 17.0, *)
    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let padding = 0.25
        let latitudeDelta = max((maxLat - minLat) * (1 + padding), 0.1)
        let longitudeDelta = max((maxLon - minLon) * (1 + padding), 0.1)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        return MKCoordinateRegion(center: center, span: span)
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

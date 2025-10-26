import Foundation
import MapKit
import Combine

@MainActor
final class MapViewModel: ObservableObject {
    typealias ServiceError = MapsService.MapServiceError
    
    @Published var searchText: String = ""
    @Published var selectedCategories: Set<MapCategory> = [.all]
    @Published var selectedPlace: Place?
    @Published var routeOrigin: Place?
    @Published var selectedMode: TransportMode = .driving
    @Published private(set) var searchResults: [Place] = []
    @Published private(set) var suggestions: [MapSearchSuggestion] = []
    @Published private(set) var savedPlaces: [Place] = []
    @Published private(set) var savedRoutes: [SavedRoute] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var isRouting: Bool = false
    @Published private(set) var currentRoute: MKRoute?
    @Published private(set) var alternativeRoutes: [MKRoute] = []
    @Published private(set) var searchError: ServiceError?
    @Published private(set) var routingError: ServiceError?
    @Published private(set) var offlineFallbackRoute: SavedRoute?
    @Published private(set) var cachedSnapshotURL: URL?
    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published var presentedError: ServiceError?
    @Published var infoMessage: String?
    
    private(set) var lastRouteOrigin: Place?
    
    private var mapsService: MapsService?
    private weak var appEnvironment: AppEnvironment?
    private var cancellables: Set<AnyCancellable> = []
    private var lastAction: LastAction?
    private var suggestionsTask: Task<Void, Never>?
    
    enum LastAction {
        case search
        case route
    }
    
    func configure(with container: DependencyContainer, appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
        guard mapsService !== container.mapsService else { return }
        self.mapsService = container.mapsService
        mapsService?.loadPersistedDataIfNeeded()
        bindService()
    }
    
    func handleSearchTextChange() {
        suggestionsTask?.cancel()
        let currentText = searchText
        guard let mapsService else { return }
        suggestionsTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                mapsService.updateSearchSuggestions(for: currentText)
            }
        }
    }
    
    func performSearch() {
        guard let mapsService else { return }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            mapsService.clearSearch()
            searchResults = []
            return
        }
        if trimmed != searchText {
            searchText = trimmed
        }
        lastAction = .search
        let isOnline = appEnvironment?.isOnline ?? true
        if !isOnline {
            presentedError = .offline
        }
        infoMessage = nil
        Task {
            await mapsService.searchPlaces(for: trimmed, categories: activeCategories, near: currentLocation)
        }
    }
    
    func selectSuggestion(_ suggestion: MapSearchSuggestion) {
        searchText = suggestion.formattedQuery
        mapsService?.logSuggestionSelection(suggestion)
        performSearch()
    }
    
    func clearSearchResults() {
        mapsService?.clearSearch()
        searchResults = []
    }
    
    func toggleCategory(_ category: MapCategory) {
        if category == .all {
            selectedCategories = [.all]
        } else {
            selectedCategories.remove(.all)
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
            } else {
                selectedCategories.insert(category)
            }
            if selectedCategories.isEmpty {
                selectedCategories = [.all]
            }
        }
    }
    
    func selectPlace(_ place: Place) {
        selectedPlace = place
        mapsService?.cacheSnapshot(for: place)
    }
    
    func setRouteOrigin(_ place: Place) {
        routeOrigin = place
        lastRouteOrigin = place
    }
    
    func useCurrentLocationAsOrigin() {
        if let coordinate = currentLocation {
            let place = Place(
                name: "Current Location",
                subtitle: "",
                coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            routeOrigin = place
            lastRouteOrigin = place
            infoMessage = nil
        } else {
            infoMessage = "Current location is unavailable. Check location permissions."
        }
    }
    
    func routeToSelectedPlace() {
        guard let destination = selectedPlace, let mapsService else { return }
        let isOnline = appEnvironment?.isOnline ?? true
        guard let origin = routeOrigin ?? currentLocationPlace else {
            infoMessage = "Set a starting point or enable location services to get directions."
            return
        }
        lastRouteOrigin = origin
        lastAction = .route
        Task {
            await mapsService.calculateRoute(from: origin, to: destination, mode: selectedMode, includeAlternatives: true, isOnline: isOnline)
        }
    }
    
    func retryLastAction() {
        guard let mapsService else { return }
        switch lastAction {
        case .search:
            Task { await mapsService.retryLastSearch() }
        case .route:
            let isOnline = appEnvironment?.isOnline ?? true
            Task { await mapsService.retryLastRoute(isOnline: isOnline) }
        case .none:
            break
        }
    }
    
    func saveSelectedPlace(association: PlaceAssociation?, bookmarked: Bool) {
        guard var place = selectedPlace else { return }
        place.isBookmarked = bookmarked
        if let association {
            place.association = association
        }
        mapsService?.savePlace(place, association: association)
        selectedPlace = place
    }
    
    func toggleBookmark(for place: Place) {
        mapsService?.toggleBookmark(for: place)
    }
    
    func saveCurrentRoute() {
        guard let destination = selectedPlace, let origin = lastRouteOrigin else { return }
        mapsService?.saveRoute(from: origin, to: destination, mode: selectedMode)
    }
    
    func openPlaceInMaps(_ place: Place) {
        mapsService?.openInAppleMaps(place: place)
    }
    
    func openSelectedPlaceInMaps() {
        guard let place = selectedPlace else { return }
        mapsService?.openInAppleMaps(place: place)
    }
    
    func openSelectedRouteInMaps() {
        guard let destination = selectedPlace, let origin = lastRouteOrigin else { return }
        mapsService?.openRouteInAppleMaps(from: origin, to: destination, mode: selectedMode)
    }
    
    func openSavedRoute(_ route: SavedRoute) {
        mapsService?.openRouteInAppleMaps(from: route.from, to: route.to, mode: route.mode)
    }
    
    var activeCategories: Set<MapCategory> {
        if selectedCategories.contains(.all) {
            return []
        }
        return selectedCategories
    }
    
    var displayedPlaces: [Place] {
        if !searchResults.isEmpty {
            return searchResults
        }
        return savedPlaces
    }
    
    var hasOfflineData: Bool {
        !savedPlaces.isEmpty || !savedRoutes.isEmpty
    }
    
    private var currentLocationPlace: Place? {
        guard let coordinate = currentLocation else { return nil }
        return Place(
            name: "Current Location",
            subtitle: "",
            coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )
    }
    
    private func bindService() {
        guard let mapsService else { return }
        cancellables.removeAll()
        
        mapsService.$searchResults
            .receive(on: RunLoop.main)
            .sink { [weak self] results in
                guard let self else { return }
                self.searchResults = results
                if let selected = self.selectedPlace,
                   let updated = results.first(where: { $0.id == selected.id }) {
                    self.selectedPlace = updated
                }
            }
            .store(in: &cancellables)
        
        mapsService.$suggestions
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.suggestions = $0 }
            .store(in: &cancellables)
        
        mapsService.$savedPlaces
            .receive(on: RunLoop.main)
            .sink { [weak self] places in
                guard let self else { return }
                self.savedPlaces = places
                if let selected = self.selectedPlace,
                   let updated = places.first(where: { $0.id == selected.id }) {
                    self.selectedPlace = updated
                }
            }
            .store(in: &cancellables)
        
        mapsService.$savedRoutes
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.savedRoutes = $0 }
            .store(in: &cancellables)
        
        mapsService.$isSearching
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isSearching = $0 }
            .store(in: &cancellables)
        
        mapsService.$isRouting
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isRouting = $0 }
            .store(in: &cancellables)
        
        mapsService.$currentRoute
            .receive(on: RunLoop.main)
            .sink { [weak self] route in
                self?.currentRoute = route
                if route != nil {
                    self?.infoMessage = nil
                }
            }
            .store(in: &cancellables)
        
        mapsService.$alternativeRoutes
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.alternativeRoutes = $0 }
            .store(in: &cancellables)
        
        mapsService.$currentLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                self?.currentLocation = location?.coordinate
            }
            .store(in: &cancellables)
        
        mapsService.$lastSearchError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self else { return }
                self.searchError = error
                if let error {
                    self.presentedError = error
                } else {
                    self.presentedError = nil
                }
            }
            .store(in: &cancellables)
        
        mapsService.$lastRoutingError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self else { return }
                self.routingError = error
                if let error {
                    self.presentedError = error
                    if case .offline = error {
                        self.infoMessage = "Routing is unavailable offline. Showing saved data if available."
                    } else {
                        self.infoMessage = nil
                    }
                } else {
                    self.infoMessage = nil
                }
            }
            .store(in: &cancellables)
        
        mapsService.$offlineFallbackRoute
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.offlineFallbackRoute = $0 }
            .store(in: &cancellables)
        
        mapsService.$cachedSnapshotURL
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.cachedSnapshotURL = $0 }
            .store(in: &cancellables)
    }
}

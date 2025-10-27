import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var viewModel = MapViewModel()
    @State private var position: MapCameraPosition = .automatic
    @State private var mapSelection: Place.ID?
    @State private var editingPlace: Place?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapSection
                    .frame(height: 320)
                    .overlay(alignment: .top) {
                        if let infoMessage = viewModel.infoMessage {
                            infoBanner(text: infoMessage)
                        } else if !appEnvironment.isOnline {
                            infoBanner(
                                text: "Offline mode – search is limited to cached results and saved places."
                            )
                        }
                    }
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        searchControls
                        suggestionsSection
                        placesSection
                        if let selectedPlace = viewModel.selectedPlace {
                            PlaceDetailCardView(
                                viewModel: viewModel,
                                editingPlace: $editingPlace,
                                place: selectedPlace
                            )
                        }
                        routesSection
                        savedRoutesSection
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: centerMap) {
                        Image(systemName: "location.fill")
                    }
                    .accessibilityLabel("Center map on current location")
                }
            }
            .task {
                viewModel.configure(with: container, appEnvironment: appEnvironment)
                container.mapsService.requestLocationPermission()
            }
            .onChange(of: viewModel.searchText) { _ in
                viewModel.handleSearchTextChange()
            }
            .alert(item: $viewModel.presentedError) { error in
                alert(for: error)
            }
            .sheet(item: $editingPlace) { place in
                AssociationEditorView(
                    place: place,
                    onSave: { tripName, day, bookmark in
                        var association: PlaceAssociation?
                        if !tripName.isEmpty || day != nil {
                            association = PlaceAssociation(
                                tripId: nil,
                                tripName: tripName.isEmpty ? nil : tripName,
                                dayPlanDate: day
                            )
                        }
                        viewModel.selectPlace(place)
                        viewModel.saveSelectedPlace(association: association, bookmarked: bookmark)
                    }
                )
            }
        }
    }
}

private extension MapView {
    var mapSection: some View {
        Map(position: $position, interactionModes: .all, showsUserLocation: true, selection: $mapSelection) {
            if let primaryRoute = viewModel.currentRoute {
                MapPolyline(primaryRoute.polyline)
                    .stroke(.blue, lineWidth: 5)
            }
            ForEach(Array(viewModel.alternativeRoutes.enumerated()), id: \.offset) { _, route in
                MapPolyline(route.polyline)
                    .stroke(.blue.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [6]))
            }
            ForEach(viewModel.displayedPlaces) { place in
                Marker(place.name, coordinate: place.coordinate.locationCoordinate)
                    .tint(place.id == viewModel.selectedPlace?.id ? .red : .accentColor)
                    .tag(place.id)
            }
        }
        .mapStyle(.standard)
        .onChange(of: mapSelection) { newValue in
            guard let id = newValue, let place = place(with: id) else { return }
            select(place: place, center: false)
        }
    }
    
    var searchControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TextField("Search for places or addresses", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { viewModel.performSearch() }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.clearSearchResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: viewModel.performSearch) {
                    Image(systemName: "magnifyingglass")
                        .padding(8)
                        .background(Circle().fill(Color.accentColor.opacity(0.15)))
                }
                .accessibilityLabel("Search")
            }
            categoryChips
        }
    }
    
    var suggestionsSection: some View {
        Group {
            if !viewModel.suggestions.isEmpty && !viewModel.searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.headline)
                    ForEach(viewModel.suggestions) { suggestion in
                        Button {
                            viewModel.selectSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isSearching {
                ProgressView("Searching for places…")
            }
            if viewModel.displayedPlaces.isEmpty {
                ContentUnavailableView(
                    "No places yet",
                    systemImage: "mappin.slash",
                    description: Text("Search for locations or browse your saved points of interest.")
                )
                .frame(maxWidth: .infinity)
            } else {
                if !viewModel.searchResults.isEmpty {
                    sectionHeader("Search Results")
                    ForEach(viewModel.searchResults) { place in
                        placeRow(for: place)
                    }
                }
                if !viewModel.savedPlaces.isEmpty {
                    sectionHeader("Saved Places")
                    ForEach(viewModel.savedPlaces) { place in
                        placeRow(for: place)
                    }
                }
            }
        }
    }
    
    var routesSection: some View {
        Group {
            if let route = viewModel.currentRoute, let destination = viewModel.selectedPlace {
                RouteSummaryView(
                    route: route,
                    alternatives: viewModel.alternativeRoutes,
                    mode: viewModel.selectedMode,
                    onSave: viewModel.saveCurrentRoute,
                    onOpenInMaps: viewModel.openSelectedRouteInMaps
                )
                .transition(.opacity)
                .onAppear {
                    mapSelection = destination.id
                    center(on: destination)
                }
            } else if let fallback = viewModel.offlineFallbackRoute {
                SavedRouteSummaryCard(route: fallback)
            }
        }
    }
    
    var savedRoutesSection: some View {
        Group {
            if !viewModel.savedRoutes.isEmpty {
                sectionHeader("Saved Routes")
                    .padding(.top, 8)
                ForEach(viewModel.savedRoutes) { route in
                    SavedRouteRow(route: route) {
                        viewModel.setRouteOrigin(route.from)
                        viewModel.selectPlace(route.to)
                        viewModel.selectedMode = route.mode
                        mapSelection = route.to.id
                        center(on: route.to)
                    } onOpen: {
                        viewModel.openSavedRoute(route)
                    }
                }
            }
        }
    }
    
    var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapCategory.allCases) { category in
                    Button {
                        viewModel.toggleCategory(category)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.systemImage)
                            Text(category.displayName)
                        }
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            viewModel.selectedCategories.contains(category)
                                ? Color.accentColor.opacity(0.2)
                                : Color(.secondarySystemBackground)
                        )
                        .foregroundColor(
                            viewModel.selectedCategories.contains(category)
                                ? .accentColor
                                : .primary
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    func placeRow(for place: Place) -> some View {
        Button {
            select(place: place, center: true)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: place.isBookmarked ? "bookmark.fill" : "mappin.circle")
                    .foregroundColor(place.isBookmarked ? .accentColor : .secondary)
                    .font(.title3)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    Text(place.addressDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let association = place.association?.summary {
                        Label(association, systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Set as Origin") {
                viewModel.setRouteOrigin(place)
            }
            Button(place.isBookmarked ? "Remove Bookmark" : "Bookmark") {
                viewModel.toggleBookmark(for: place)
            }
            Button("Open in Apple Maps") {
                viewModel.openPlaceInMaps(place)
            }
        }
    }
    
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    func infoBanner(text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.85))
    }
    
    func alert(for error: MapsService.MapServiceError) -> Alert {
        switch error {
        case .offline:
            return Alert(
                title: Text("Offline"),
                message: Text(error.recoverySuggestion ?? ""),
                dismissButton: .default(Text("OK"))
            )
        default:
            let messageComponents = [error.errorDescription, error.recoverySuggestion]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            let messageText = messageComponents.isEmpty
                ? "An unexpected map error occurred."
                : messageComponents.joined(separator: "\n\n")
            return Alert(
                title: Text("Map Error"),
                message: Text(messageText),
                primaryButton: .default(Text("Retry"), action: viewModel.retryLastAction),
                secondaryButton: .cancel()
            )
        }
    }
    
    func centerMap() {
        if let place = viewModel.selectedPlace {
            center(on: place)
            mapSelection = place.id
        } else if let coordinate = viewModel.currentLocation {
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            position = .region(region)
        } else {
            container.mapsService.requestLocationPermission()
            viewModel.infoMessage = "Location permission is required to center on your position."
        }
    }
    
    func center(on place: Place) {
        let coordinate = place.coordinate.locationCoordinate
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        position = .region(region)
    }
    
    func select(place: Place, center shouldCenter: Bool) {
        viewModel.selectPlace(place)
        mapSelection = place.id
        if shouldCenter {
            center(on: place)
        }
    }
    
    func place(with id: Place.ID) -> Place? {
        viewModel.displayedPlaces.first(where: { $0.id == id })
    }
}

#Preview {
    MapView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}

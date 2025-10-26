import SwiftUI
import MapKit
import UIKit

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
                            infoBanner(text: "Offline mode – search is limited to cached results and saved places.")
                        }
                    }
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        searchControls
                        suggestionsSection
                        placesSection
                        if let selectedPlace = viewModel.selectedPlace {
                            placeDetailCard(for: selectedPlace)
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
                            association = PlaceAssociation(tripId: nil, tripName: tripName.isEmpty ? nil : tripName, dayPlanDate: day)
                        }
                        viewModel.selectPlace(place)
                        viewModel.saveSelectedPlace(association: association, bookmarked: bookmark)
                    }
                )
            }
        }
    }
    
    private var mapSection: some View {
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
    
    private var searchControls: some View {
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
    
    private var suggestionsSection: some View {
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
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var placesSection: some View {
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
    
    private var routesSection: some View {
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
    
    private var savedRoutesSection: some View {
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
                    } onOpen {
                        viewModel.openSavedRoute(route)
                    }
                }
            }
        }
    }
    
    private var categoryChips: some View {
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
                        .background(viewModel.selectedCategories.contains(category) ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                        .foregroundColor(viewModel.selectedCategories.contains(category) ? .accentColor : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func placeRow(for place: Place) -> some View {
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
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
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
    
    private func placeDetailCard(for place: Place) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    if !place.addressDescription.isEmpty {
                        Text(place.addressDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let association = place.association?.summary {
                        Label(association, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    editingPlace = place
                } label: {
                    Label("Add to Trip", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            
            if !appEnvironment.isOnline, let snapshotURL = viewModel.offlineSnapshotURL(for: place), let snapshotImage = UIImage(contentsOfFile: snapshotURL.path) {
                Image(uiImage: snapshotImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Label("Offline Snapshot", systemImage: "icloud.slash")
                            .font(.caption2)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(8)
                    }
            }
            
            HStack(spacing: 12) {
                Button {
                    viewModel.toggleBookmark(for: place)
                } label: {
                    Label(place.isBookmarked ? "Bookmarked" : "Bookmark", systemImage: place.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                
                Button(action: viewModel.openSelectedPlaceInMaps) {
                    Label("Open in Maps", systemImage: "arrow.up.right.square")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            
            Picker("Mode", selection: $viewModel.selectedMode) {
                ForEach(TransportMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 8) {
                if let origin = viewModel.routeOrigin {
                    Label("From: \(origin.name)", systemImage: "mappin")
                        .font(.footnote)
                }
                HStack {
                    Button("Use Current Location", action: viewModel.useCurrentLocationAsOrigin)
                    Spacer()
                    Button("Clear Start") {
                        viewModel.routeOrigin = nil
                    }
                    .disabled(viewModel.routeOrigin == nil)
                }
                .font(.footnote)
            }
            
            Button(action: viewModel.routeToSelectedPlace) {
                Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRouting)
            
            if viewModel.isRouting {
                ProgressView("Calculating route…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(radius: 4, y: 2)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func infoBanner(text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.85))
    }
    
    private func alert(for error: MapsService.MapServiceError) -> Alert {
        switch error {
        case .offline:
            return Alert(
                title: Text("Offline"),
                message: Text(error.recoverySuggestion ?? ""),
                dismissButton: .default(Text("OK"))
            )
        default:
            let messageComponents = [error.errorDescription, error.recoverySuggestion].compactMap { $0 }.filter { !$0.isEmpty }
            let messageText = messageComponents.isEmpty ? "An unexpected map error occurred." : messageComponents.joined(separator: "\n\n")
            return Alert(
                title: Text("Map Error"),
                message: Text(messageText),
                primaryButton: .default(Text("Retry"), action: viewModel.retryLastAction),
                secondaryButton: .cancel()
            )
        }
    }
    
    private func centerMap() {
        if let place = viewModel.selectedPlace {
            center(on: place)
            mapSelection = place.id
        } else if let coordinate = viewModel.currentLocation {
            let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
            position = .region(region)
        } else {
            container.mapsService.requestLocationPermission()
            viewModel.infoMessage = "Location permission is required to center on your position."
        }
    }
    
    private func center(on place: Place) {
        let coordinate = place.coordinate.locationCoordinate
        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        position = .region(region)
    }
    
    private func select(place: Place, center shouldCenter: Bool) {
        viewModel.selectPlace(place)
        mapSelection = place.id
        if shouldCenter {
            center(on: place)
        }
    }
    
    private func place(with id: Place.ID) -> Place? {
        viewModel.displayedPlaces.first(where: { $0.id == id })
    }
}

private struct RouteSummaryView: View {
    let route: MKRoute
    let alternatives: [MKRoute]
    let mode: TransportMode
    var onSave: () -> Void
    var onOpenInMaps: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Route Summary", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.headline)
                Spacer()
                Image(systemName: mode.systemImage)
                    .foregroundColor(.accentColor)
            }
            Text("Estimated time: \(formatDuration(route.expectedTravelTime))")
                .font(.subheadline)
            Text("Distance: \(formatDistance(route.distance))")
                .font(.subheadline)
            if !route.advisoryNotices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .font(.caption.weight(.semibold))
                    ForEach(route.advisoryNotices, id: \.self) { notice in
                        Text("• \(notice)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alternatives")
                        .font(.caption.weight(.semibold))
                    ForEach(alternatives.indices, id: \.self) { index in
                        let alt = alternatives[index]
                        Text("Option \(index + 2): \(formatDuration(alt.expectedTravelTime)), \(formatDistance(alt.distance))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            HStack {
                Button("Save Route", action: onSave)
                Button("Open in Apple Maps", action: onOpenInMaps)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(radius: 4, y: 2)
    }
    
    private func formatDuration(_ value: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = value > 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .full
        return formatter.string(from: value) ?? "--"
    }
    
    private func formatDistance(_ value: CLLocationDistance) -> String {
        let measurement = Measurement(value: value / 1000, unit: UnitLength.kilometers)
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
}

private struct SavedRouteRow: View {
    let route: SavedRoute
    var onSelect: () -> Void
    var onOpen: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(route.from.name) → \(route.to.name)")
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: route.mode.systemImage)
                    .foregroundColor(.accentColor)
            }
            Text("Primary: \(formatDuration(route.primary.expectedTravelTime)), \(formatDistance(route.primary.distance))")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Text("Saved on \(formatDate(route.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Open in Maps", action: onOpen)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .onTapGesture(perform: onSelect)
    }
    
    private func formatDuration(_ value: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = value > 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: value) ?? "--"
    }
    
    private func formatDistance(_ value: CLLocationDistance) -> String {
        let measurement = Measurement(value: value / 1000, unit: UnitLength.kilometers)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.unitStyle = .short
        return formatter.string(from: measurement)
    }
    
    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct SavedRouteSummaryCard: View {
    let route: SavedRoute
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Saved Route Available", systemImage: "tray.full")
                .font(.headline)
            Text("Showing saved details for when you're offline.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Primary: \(formatDuration(route.primary.expectedTravelTime)), \(formatDistance(route.primary.distance))")
                .font(.footnote)
            if !route.alternatives.isEmpty {
                Text("Alternatives: \(route.alternatives.count)")
                    .font(.footnote)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(radius: 4, y: 2)
    }
    
    private func formatDuration(_ value: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = value > 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .full
        return formatter.string(from: value) ?? "--"
    }
    
    private func formatDistance(_ value: CLLocationDistance) -> String {
        let measurement = Measurement(value: value / 1000, unit: UnitLength.kilometers)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.unitStyle = .medium
        return formatter.string(from: measurement)
    }
}

private struct AssociationEditorView: View {
    let place: Place
    var onSave: (String, Date?, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tripName: String = ""
    @State private var includeDate: Bool = false
    @State private var dayPlanDate: Date = .now
    @State private var bookmarked: Bool = true
    
    init(place: Place, onSave: @escaping (String, Date?, Bool) -> Void) {
        self.place = place
        self.onSave = onSave
        _tripName = State(initialValue: place.association?.tripName ?? "")
        if let day = place.association?.dayPlanDate {
            _includeDate = State(initialValue: true)
            _dayPlanDate = State(initialValue: day)
        }
        _bookmarked = State(initialValue: place.isBookmarked)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip or Day Plan", text: $tripName)
                    Toggle("Include day plan", isOn: $includeDate.animation())
                    if includeDate {
                        DatePicker("Day", selection: $dayPlanDate, displayedComponents: .date)
                    }
                }
                Section("Bookmark") {
                    Toggle("Bookmark this place", isOn: $bookmarked)
                }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(tripName, includeDate ? dayPlanDate : nil, bookmarked)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}

import SwiftUI
import MapKit

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
                        infoOverlay
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
            .alert(item: $viewModel.presentedError) { alert(for: $0) }
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

#Preview {
    MapView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}

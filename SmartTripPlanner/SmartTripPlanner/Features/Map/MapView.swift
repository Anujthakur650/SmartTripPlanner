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
                mapHeader
                Divider()
                contentList
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
            .task { setup() }
            .onChange(of: viewModel.searchText, perform: onSearchTextChange(_:))
            .alert(item: $viewModel.presentedError, content: alert(for:))
            .sheet(item: $editingPlace, content: associationEditor(for:))
        }
    }
}

#Preview {
    MapView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}

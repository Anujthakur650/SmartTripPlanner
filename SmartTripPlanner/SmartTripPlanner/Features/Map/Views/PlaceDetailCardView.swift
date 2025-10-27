import SwiftUI

struct PlaceDetailCardView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var editingPlace: Place?
    let place: Place
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            bookmarkingActions
            transportPicker
            originControls
            routeButton
            routingIndicator
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .shadow(radius: 4, y: 2)
    }
    
    private var header: some View {
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
    }
    
    private var bookmarkingActions: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.toggleBookmark(for: place)
            } label: {
                Label(
                    place.isBookmarked ? "Bookmarked" : "Bookmark",
                    systemImage: place.isBookmarked ? "bookmark.fill" : "bookmark"
                )
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            
            Button(action: viewModel.openSelectedPlaceInMaps) {
                Label("Open in Maps", systemImage: "arrow.up.right.square")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var transportPicker: some View {
        Picker("Mode", selection: $viewModel.selectedMode) {
            ForEach(TransportMode.allCases) { mode in
                Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var originControls: some View {
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
    }
    
    private var routeButton: some View {
        Button(action: viewModel.routeToSelectedPlace) {
            Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isRouting)
    }
    
    @ViewBuilder
    private var routingIndicator: some View {
        if viewModel.isRouting {
            ProgressView("Calculating route…")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

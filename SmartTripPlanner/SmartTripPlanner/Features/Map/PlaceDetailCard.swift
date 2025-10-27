import SwiftUI

struct PlaceDetailCard: View {
    let place: Place
    @Binding var selectedMode: TransportMode
    @Binding var routeOrigin: Place?
    let isRouting: Bool
    let onEdit: () -> Void
    let onToggleBookmark: (Place) -> Void
    let onOpenInMaps: () -> Void
    let onUseCurrentLocation: () -> Void
    let onClearRouteOrigin: () -> Void
    let onRoute: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            actionButtons
            modePicker
            originControls
            routeButton
            routingStatus
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
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
            Button(action: onEdit) {
                Label("Add to Trip", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onToggleBookmark(place)
            } label: {
                Label(place.isBookmarked ? "Bookmarked" : "Bookmark", systemImage: place.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            
            Button(action: onOpenInMaps) {
                Label("Open in Maps", systemImage: "arrow.up.right.square")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var modePicker: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(TransportMode.allCases) { mode in
                Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var originControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let origin = routeOrigin {
                Label("From: \(origin.name)", systemImage: "mappin")
                    .font(.footnote)
            }
            HStack {
                Button("Use Current Location", action: onUseCurrentLocation)
                Spacer()
                Button("Clear Start", action: onClearRouteOrigin)
                    .disabled(routeOrigin == nil)
            }
            .font(.footnote)
        }
    }
    
    private var routeButton: some View {
        Button(action: onRoute) {
            Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRouting)
    }
    
    @ViewBuilder
    private var routingStatus: some View {
        if isRouting {
            ProgressView("Calculating route…")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

import SwiftUI
import MapKit

struct RouteSummaryView: View {
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

struct SavedRouteRow: View {
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

struct SavedRouteSummaryCard: View {
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

struct AssociationEditorView: View {
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

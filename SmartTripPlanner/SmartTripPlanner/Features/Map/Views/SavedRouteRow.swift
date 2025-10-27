import SwiftUI
import CoreLocation

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
            Text(primarySummary(for: route))
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .onTapGesture(perform: onSelect)
    }
    
    private func primarySummary(for route: SavedRoute) -> String {
        "Primary: \(formatDuration(route.primary.expectedTravelTime)), "
            + "\(formatDistance(route.primary.distance))"
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

import SwiftUI

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

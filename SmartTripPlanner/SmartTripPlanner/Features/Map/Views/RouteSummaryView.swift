import SwiftUI
import MapKit
import CoreLocation

struct RouteSummaryView: View {
    let route: MKRoute
    let alternatives: [MKRoute]
    let mode: TransportMode
    var onSave: () -> Void
    var onOpenInMaps: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Route Summary",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                )
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
                        Text(alternativeSummary(for: index))
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .shadow(radius: 4, y: 2)
    }
    
    private func alternativeSummary(for index: Int) -> String {
        let alternative = alternatives[index]
        return "Option \(index + 2): \(formatDuration(alternative.expectedTravelTime)), "
            + "\(formatDistance(alternative.distance))"
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

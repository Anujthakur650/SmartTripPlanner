import SwiftUI

struct TripRowView: View {
    let trip: Trip
    @EnvironmentObject private var appEnvironment: AppEnvironment
    
    private var travelModes: [TripTravelMode] {
        Array(trip.allTravelModes).sorted { $0.displayName < $1.displayName }
    }
    
    private var destinationsSummary: String {
        if trip.destinations.isEmpty {
            return trip.primaryDestination
        }
        return trip.destinations.map { $0.name }.joined(separator: " • ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(trip.name)
                    .font(.headline)
                    .foregroundColor(appEnvironment.theme.textPrimaryColor)
                Spacer()
                Label("\(trip.durationInDays) days", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if !destinationsSummary.isEmpty {
                    Label(destinationsSummary, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            if !travelModes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(travelModes, id: \.self) { mode in
                        HStack(spacing: 4) {
                            Image(systemName: mode.systemImage)
                            Text(mode.displayName)
                        }
                        .font(.caption2)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(appEnvironment.theme.primaryColor.opacity(0.1))
                        .foregroundColor(appEnvironment.theme.primaryColor)
                        .clipShape(Capsule())
                    }
                }
            }
            if !trip.participants.isEmpty {
                Label("Guests: \(trip.participants.map { $0.name }.joined(separator: ", "))", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appEnvironment.theme.cardBackgroundColor)
        .cornerRadius(appEnvironment.theme.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: appEnvironment.theme.shadowRadius, x: 0, y: 2)
    }
}

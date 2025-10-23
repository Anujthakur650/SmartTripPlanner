import SwiftUI

struct TripsView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var tripStore: TripStore
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if tripStore.trips.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("No trips yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start planning your next adventure")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(tripStore.trips) { trip in
                            TripCard(trip: trip)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        tripStore.remove(trip)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addTrip) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func addTrip() {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 4, to: today) ?? today
        let newTrip = Trip(
            name: "New Trip",
            destination: "Destination",
            coordinate: nil,
            startDate: today,
            endDate: end,
            tripType: .leisure,
            activities: []
        )
        tripStore.add(newTrip)
    }
}

struct TripCard: View {
    let trip: Trip
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.name)
                .font(.headline)
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.theme.primaryColor)
                Text(trip.destination)
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(theme.theme.secondaryColor)
                Text(trip.tripType.displayName)
                    .font(.caption)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(theme.theme.secondaryColor)
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
            }
            
            if !trip.activities.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(theme.theme.primaryColor)
                    Text(trip.activities
                        .map { $0.displayName }
                        .sorted()
                        .joined(separator: ", "))
                    .font(.caption)
                    .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(theme: theme.theme)
    }
}

#Preview {
    let container = DependencyContainer()
    return TripsView()
        .environmentObject(container)
        .environmentObject(container.tripStore)
        .environmentObject(container.appEnvironment)
}

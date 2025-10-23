import SwiftUI

struct TripsView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var trips: [Trip] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if trips.isEmpty {
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
                        ForEach(trips) { trip in
                            TripCard(trip: trip)
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
        let newTrip = Trip(
            id: UUID(),
            name: "New Trip",
            destination: "Destination",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7)
        )
        trips.append(newTrip)
    }
}

struct Trip: Identifiable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
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
                Image(systemName: "calendar")
                    .foregroundColor(theme.theme.secondaryColor)
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) - \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(theme: theme.theme)
    }
}

#Preview {
    TripsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}

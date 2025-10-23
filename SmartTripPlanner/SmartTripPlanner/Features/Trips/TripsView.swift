import SwiftUI

struct TripsView: View {
    @EnvironmentObject var dataStore: TravelDataStore
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if dataStore.trips.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text(String(localized: "No trips yet"))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(String(localized: "Start planning your next adventure"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(dataStore.trips) { trip in
                            TripCard(trip: trip)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(String(localized: "Trips"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addTrip) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add trip"))
                }
            }
        }
    }
    
    private func addTrip() {
        dataStore.addTrip()
    }
}

struct TripCard: View {
    let trip: Trip
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.name)
                .font(.headline)
            
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.theme.primaryColor)
                Text(trip.destination)
                    .font(.subheadline)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(theme.theme.secondaryColor)
                Text(dateRange(for: trip))
                    .font(.caption)
            }
            
            if !trip.travelers.isEmpty {
                Label("\(trip.travelers.count)" + " " + String(localized: trip.travelers.count == 1 ? "traveler" : "travelers"), systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(theme: theme.theme)
        .accessibilityElement(children: .combine)
    }
    
    private func dateRange(for trip: Trip) -> String {
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }
}

#Preview {
    TripsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
        .environmentObject(TravelDataStore())
}

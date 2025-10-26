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

struct Trip: Identifiable, Codable {
    struct Location: Codable {
        var latitude: Double
        var longitude: Double
    }
    
    struct ItineraryItem: Identifiable, Codable {
        let id: UUID
        var title: String
        var startTime: Date?
        var location: Location?
        
        init(id: UUID = UUID(), title: String, startTime: Date? = nil, location: Location? = nil) {
            self.id = id
            self.title = title
            self.startTime = startTime
            self.location = location
        }
    }
    
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date?
    var endDate: Date?
    var itineraryItems: [ItineraryItem]
    
    init(id: UUID,
         name: String,
         destination: String,
         startDate: Date? = nil,
         endDate: Date? = nil,
         itineraryItems: [ItineraryItem] = []) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.itineraryItems = itineraryItems
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
            
            if let startDate = trip.startDate, let endDate = trip.endDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.theme.secondaryColor)
                    Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                }
            } else if let startDate = trip.startDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.theme.secondaryColor)
                    Text(startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                }
            } else if let endDate = trip.endDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.theme.secondaryColor)
                    Text(endDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                }
            } else {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(theme.theme.secondaryColor)
                    Text("Dates TBD")
                        .font(.caption)
                }
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

import SwiftUI

struct TripsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var weatherViewModel = TripWeatherViewModel()
    @State private var trips: [Trip]
    @State private var showingAddSheet = false
    
    init(initialTrips: [Trip] = []) {
        self._trips = State(initialValue: initialTrips)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TripWeatherPanel(state: weatherViewModel.state) {
                        weatherViewModel.retry()
                    }
                    .padding(.horizontal)
                    tripsContent
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("add_trip_button")
                }
            }
            .task {
                weatherViewModel.configure(with: container)
                weatherViewModel.refresh(for: trips)
            }
            .onChange(of: trips) { newTrips in
                weatherViewModel.refresh(for: newTrips)
            }
            .sheet(isPresented: $showingAddSheet) {
                TripEditorView { newTrip in
                    trips.append(newTrip)
                    showingAddSheet = false
                }
            }
        }
    }
    
    @ViewBuilder
    private var tripsContent: some View {
        if trips.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 20) {
                ForEach(trips) { trip in
                    TripCard(trip: trip)
                        .environmentObject(appEnvironment)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var emptyState: some View {
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal)
    }
}

struct Trip: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var notes: String
    
    init(id: UUID = UUID(), name: String, destination: String, startDate: Date, endDate: Date, notes: String = "") {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }
    
    var dateRangeDescription: String {
        "\(startDate.formatted(date: .abbreviated, time: .omitted)) – \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }
    
    var daysUntil: Int? {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: startDate)
        guard let diff = Calendar.current.dateComponents([.day], from: today, to: start).day else { return nil }
        return diff
    }
    
    var durationInDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }
    
    static var previewSamples: [Trip] {
        let calendar = Calendar.current
        let parisStart = calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        let parisEnd = calendar.date(byAdding: .day, value: 10, to: parisStart) ?? Date()
        let tokyoStart = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let tokyoEnd = calendar.date(byAdding: .day, value: 7, to: tokyoStart) ?? Date()
        return [
            Trip(name: "Paris Getaway", destination: "Paris, France", startDate: parisStart, endDate: parisEnd, notes: "Visit the Louvre and enjoy croissants."),
            Trip(name: "Tokyo Adventure", destination: "Tokyo, Japan", startDate: tokyoStart, endDate: tokyoEnd, notes: "Explore Shibuya and Tsukiji Market."),
            Trip(name: "Road Trip", destination: "San Francisco, CA", startDate: Date().addingTimeInterval(86400 * 14), endDate: Date().addingTimeInterval(86400 * 19), notes: "Drive the Pacific Coast Highway.")
        ]
    }
}

struct TripCard: View {
    let trip: Trip
    @EnvironmentObject private var theme: AppEnvironment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.headline)
                        .accessibilityIdentifier("trip_name_\(trip.id.uuidString)")
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let daysUntil = trip.daysUntil {
                    Text(daysUntil >= 0 ? "\(daysUntil) days" : "In progress")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.theme.primaryColor.opacity(0.15)))
                        .foregroundColor(theme.theme.primaryColor)
                }
            }
            HStack(spacing: 12) {
                Label(trip.dateRangeDescription, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(theme.theme.secondaryColor)
                Spacer()
                Label("\(trip.durationInDays) days", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

struct TripEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var destination: String = ""
    @State private var startDate: Date = Date().addingTimeInterval(86400)
    @State private var endDate: Date = Date().addingTimeInterval(86400 * 4)
    @State private var notes: String = ""
    var onSave: (Trip) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Trip name", text: $name)
                    TextField("Destination", text: $destination)
                }
                Section("Dates") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trip = Trip(name: name.isEmpty ? "New Trip" : name,
                                        destination: destination.isEmpty ? "" : destination,
                                        startDate: startDate,
                                        endDate: endDate,
                                        notes: notes)
                        onSave(trip)
                        dismiss()
                    }
                    .disabled(destination.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    TripsView(initialTrips: Trip.previewSamples)
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}

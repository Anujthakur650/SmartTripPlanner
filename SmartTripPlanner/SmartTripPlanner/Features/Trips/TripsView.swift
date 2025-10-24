import SwiftUI

struct TripsView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var trips: [Trip]
    @State private var isLoading = false
    @State private var syncError: String?
    
    init(initialTrips: [Trip] = []) {
        _trips = State(initialValue: initialTrips)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let syncError {
                        errorBanner(syncError)
                    }
                    
                    if isLoading && trips.isEmpty {
                        ProgressView("Loading trips…")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if trips.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(trips) { trip in
                                TripCard(trip: trip)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if appEnvironment.isSyncing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else if let lastSyncDate = container.syncService.lastSyncDate {
                        Text("Synced \(lastSyncDate, style: .time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addTrip) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Trip")
                }
            }
            .refreshable { await loadTrips(force: true) }
            .task { await loadTrips() }
        }
    }
    
    @MainActor
    private func loadTrips(force: Bool = false) async {
        if (isRunningInPreviews || isRunningTests), !force {
            if trips.isEmpty {
                trips = [Trip.sample]
            }
            return
        }
        
        guard !isLoading || force else { return }
        isLoading = true
        syncError = nil
        
        do {
            trips = try await container.syncService.fetchAll(as: Trip.self)
        } catch {
            syncError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    private func addTrip() {
        var newTrip = Trip(
            name: "New Trip",
            destination: "Destination",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date().addingTimeInterval(604_800)
        )
        newTrip.touch()
        trips.insert(newTrip, at: 0)
        persistTrip(newTrip)
    }
    
    private func persistTrip(_ trip: Trip) {
        Task { @MainActor in
            do {
                try await container.syncService.save(trip)
            } catch {
                syncError = error.localizedDescription
            }
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .font(.footnote)
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

struct TripCard: View {
    let trip: Trip
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trip.name)
                    .font(.headline)
                Spacer()
                Text(trip.status.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundColor(statusColor)
            }
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.theme.primaryColor)
                Text(trip.destination)
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(theme.theme.secondaryColor)
                Text(trip.formattedDateRange)
                    .font(.caption)
            }
            
            if let nextItem = trip.nextItineraryItem {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(theme.theme.primaryColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextItem.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(nextItem.startDate, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle(theme: theme.theme)
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .planning:
            return theme.theme.secondaryColor
        case .booked:
            return theme.theme.primaryColor
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
}

#Preview {
    let container = DependencyContainer()
    return TripsView(initialTrips: [Trip.sample])
        .environmentObject(container)
        .environmentObject(container.appEnvironment)
}

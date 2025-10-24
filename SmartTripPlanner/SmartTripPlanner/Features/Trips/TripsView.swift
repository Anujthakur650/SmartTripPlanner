import SwiftUI

struct TripsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var trips: [Trip] = Trip.sampleData
    
    var body: some View {
        let theme = appEnvironment.theme
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    SectionHeader(
                        title: "Upcoming trips",
                        caption: "Keep every journey calm and organised",
                        actionTitle: "New trip",
                        action: addTrip
                    )
                    if trips.isEmpty {
                        EmptyStateView(
                            icon: "suitcase.rolling",
                            title: "You're all packed with potential",
                            message: "Start planning your next adventure with a single tap.",
                            actionTitle: "Create a trip",
                            action: addTrip
                        )
                        .padding(.top, theme.spacing.l)
                    } else {
                        VStack(spacing: theme.spacing.l) {
                            ForEach(trips) { trip in
                                TripSummaryCard(trip: trip)
                            }
                            AppButton(title: "Add another trip", style: .primary, action: addTrip)
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.l)
            }
            .background(theme.colors.background.resolved(for: colorScheme))
            .navigationTitle("Trips")
        }
    }
    
    private func addTrip() {
        let newTrip = Trip(
            id: UUID(),
            name: "Creative Retreat",
            destination: "Kyoto, Japan",
            startDate: Date().addingTimeInterval(60 * 60 * 24 * 40),
            endDate: Date().addingTimeInterval(60 * 60 * 24 * 46),
            status: .planning,
            nextActivity: Trip.Activity(
                time: "May 14",
                icon: "house",
                title: "Confirm ryokan stay",
                detail: "Follow up on the tatami suite request"
            ),
            highlights: ["Tea ceremony", "Night market"]
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
    var status: Status
    var nextActivity: Activity?
    var highlights: [String]
    
    struct Activity {
        let time: String
        let icon: String
        let title: String
        let detail: String
    }
    
    enum Status {
        case confirmed
        case planning
        case exploring
        
        var label: String {
            switch self {
            case .confirmed: return "Confirmed"
            case .planning: return "In planning"
            case .exploring: return "Idea"
            }
        }
        
        var tagStyle: TagLabel.Style {
            switch self {
            case .confirmed: return .success
            case .planning: return .info
            case .exploring: return .neutral
            }
        }
    }
    
    var dateRange: String {
        let start = startDate.formatted(date: .abbreviated, time: .omitted)
        let end = endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }
    
    static let sampleData: [Trip] = [
        Trip(
            id: UUID(),
            name: "Andalusian Escape",
            destination: "Seville, Spain",
            startDate: Date().addingTimeInterval(60 * 60 * 24 * 14),
            endDate: Date().addingTimeInterval(60 * 60 * 24 * 21),
            status: .confirmed,
            nextActivity: Trip.Activity(
                time: "Apr 22",
                icon: "airplane.circle.fill",
                title: "Flight IB 6171",
                detail: "Check-in opens at 09:00"
            ),
            highlights: ["Rooftop tapas", "Flamenco night", "Cooking class"]
        ),
        Trip(
            id: UUID(),
            name: "Nordic Discovery",
            destination: "Reykjavík, Iceland",
            startDate: Date().addingTimeInterval(60 * 60 * 24 * 52),
            endDate: Date().addingTimeInterval(60 * 60 * 24 * 58),
            status: .planning,
            nextActivity: Trip.Activity(
                time: "Jun 04",
                icon: "sparkles",
                title: "Reserve northern lights tour",
                detail: "Hold two seats with local guide"
            ),
            highlights: ["Blue Lagoon", "Glacier walk", "City food tour"]
        ),
        Trip(
            id: UUID(),
            name: "Alpine Daydream",
            destination: "Lake Como, Italy",
            startDate: Date().addingTimeInterval(60 * 60 * 24 * 74),
            endDate: Date().addingTimeInterval(60 * 60 * 24 * 80),
            status: .exploring,
            nextActivity: nil,
            highlights: ["Villa stay", "Sunrise hike"]
        )
    ]
}

private struct TripSummaryCard: View {
    let trip: Trip
    @EnvironmentObject private var appEnvironment: AppEnvironment
    
    var body: some View {
        let theme = appEnvironment.theme
        let spacing = theme.spacing
        Card(title: trip.name, subtitle: "\(trip.destination) • \(trip.dateRange)", style: .elevated) {
            VStack(alignment: .leading, spacing: spacing.m) {
                TagLabel(text: trip.status.label, style: trip.status.tagStyle)
                if let activity = trip.nextActivity {
                    ListRow(
                        icon: activity.icon,
                        title: activity.title,
                        subtitle: activity.detail,
                        tagText: activity.time,
                        tagStyle: .info
                    ) {
                        Image(systemName: "chevron.right")
                    }
                }
                if !trip.highlights.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.xs) {
                            ForEach(trip.highlights, id: \.self) { highlight in
                                TagLabel(text: highlight, style: .neutral)
                            }
                        }
                        .padding(.vertical, spacing.xs)
                    }
                }
                AppButton(title: "Open itinerary", style: .secondary, fillWidth: false, action: {})
            }
        }
    }
}

#Preview {
    TripsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}

import SwiftUI

struct PlannerView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDate = Date()
    @State private var events: [PlannerEvent] = PlannerEvent.sampleData
    @State private var newEventTitle: String = ""
    @State private var newEventDetail: String = ""
    @State private var newEventTime: Date = Date()
    @State private var shouldNotify: Bool = true
    
    private var theme: Theme { appEnvironment.theme }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    Card(title: "Plan your day", subtitle: selectedDate.formatted(date: .long, time: .omitted), style: .muted) {
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                    SectionHeader(
                        title: "Timeline",
                        caption: "Track the beats of your trip"
                    )
                    timelineSection
                    SectionHeader(
                        title: "Quick add",
                        caption: "Capture ideas before they drift"
                    )
                    addEventSection
                }
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.l)
            }
            .background(theme.colors.background.resolved(for: colorScheme))
            .navigationTitle("Planner")
        }
    }
    
    private var timelineSection: some View {
        let todaysEvents = eventsForSelectedDate()
        return Group {
            if todaysEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: "No plans for this day",
                    message: "Tap \"Add event\" to start shaping your itinerary."
                )
            } else {
                Card(style: .standard) {
                    VStack(alignment: .leading, spacing: theme.spacing.m) {
                        ForEach(todaysEvents) { event in
                            TimelineItem(
                                icon: event.icon,
                                time: event.timeString,
                                title: event.title,
                                subtitle: event.detail,
                                status: event.status
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var addEventSection: some View {
        Card(style: .standard) {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                FormTextField(
                    title: "Title",
                    placeholder: "Morning espresso at Piazza",
                    text: $newEventTitle,
                    helper: "Short and descriptive works best",
                    icon: "text.quote"
                )
                FormTextField(
                    title: "Details",
                    placeholder: "Optional notes or meeting point",
                    text: $newEventDetail,
                    helper: nil,
                    icon: "note.text"
                )
                DatePicker("Time", selection: $newEventTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                FormToggleRow(
                    title: "Reminder",
                    isOn: $shouldNotify,
                    helper: "We'll nudge you 30 minutes beforehand"
                )
                AppButton(
                    title: "Add event",
                    style: .primary,
                    isDisabled: newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: addEvent
                )
            }
        }
    }
    
    private func eventsForSelectedDate() -> [PlannerEvent] {
        let calendar = Calendar.current
        return events
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted(by: { $0.date < $1.date })
    }
    
    private func addEvent() {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newEventTime)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        let combinedDate = calendar.date(from: dateComponents) ?? selectedDate
        let event = PlannerEvent(
            id: UUID(),
            date: combinedDate,
            icon: shouldNotify ? "bell" : "circle",
            title: newEventTitle,
            detail: newEventDetail.isEmpty ? "No notes" : newEventDetail,
            status: shouldNotify ? .planned : .inProgress
        )
        events.append(event)
        newEventTitle = ""
        newEventDetail = ""
    }
}

struct PlannerEvent: Identifiable {
    let id: UUID
    var date: Date
    var icon: String
    var title: String
    var detail: String
    var status: TimelineItem.Status
    
    var timeString: String {
        date.formatted(date: .omitted, time: .shortened)
    }
    
    static let sampleData: [PlannerEvent] = {
        let calendar = Calendar.current
        let today = Date()
        let morning = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today) ?? today
        let midday = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today
        let evening = calendar.date(bySettingHour: 18, minute: 15, second: 0, of: today) ?? today
        return [
            PlannerEvent(
                id: UUID(),
                date: morning,
                icon: "cup.and.saucer.fill",
                title: "Café con leche",
                detail: "La Lola, around the corner",
                status: .completed
            ),
            PlannerEvent(
                id: UUID(),
                date: midday,
                icon: "fork.knife",
                title: "Lunch tasting menu",
                detail: "Market hall table 5",
                status: .inProgress
            ),
            PlannerEvent(
                id: UUID(),
                date: evening,
                icon: "music.quarternote.3",
                title: "Flamenco show",
                detail: "Doors open 17:45",
                status: .planned
            )
        ]
    }()
}

#Preview {
    PlannerView()
        .environmentObject(AppEnvironment())
}

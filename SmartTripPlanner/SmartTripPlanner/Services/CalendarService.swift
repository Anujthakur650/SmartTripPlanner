import Foundation
import EventKit

@MainActor
class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    
    func requestAccess() async throws {
        isAuthorized = try await eventStore.requestFullAccessToEvents()
    }
    
    func createEvent(title: String, startDate: Date, endDate: Date, location: String? = nil) async throws -> String {
        guard isAuthorized else {
            try await requestAccess()
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
    
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EKEvent] {
        guard isAuthorized else {
            try await requestAccess()
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    func deleteEvent(withIdentifier identifier: String) throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            throw NSError(domain: "CalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }
        try eventStore.remove(event, span: .thisEvent)
    }
}

import Foundation

@MainActor
protocol ItineraryDataSource: AnyObject {
    var trips: [Trip] { get }
    var packingItems: [PackingItem] { get }
    var documents: [TravelDocument] { get }
    var dayPlans: [DayPlan] { get }
    var segments: [TripSegment] { get }
}

@MainActor
final class TravelDataStore: ObservableObject, ItineraryDataSource {
    @Published private(set) var trips: [Trip]
    @Published private(set) var packingItems: [PackingItem]
    @Published private(set) var documents: [TravelDocument]
    @Published private(set) var dayPlans: [DayPlan]
    @Published private(set) var segments: [TripSegment]
    
    private let calendar: Calendar
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
        let today = calendar.startOfDay(for: Date())
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        let inSevenDays = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        self.trips = [Trip(
            name: String(localized: "European Explorer"),
            destination: String(localized: "Paris, France"),
            startDate: today,
            endDate: inSevenDays,
            travelers: [String(localized: "Alex"), String(localized: "Jordan")],
            notes: String(localized: "Remember to confirm the Louvre tickets and dinner reservations.")
        )]
        self.packingItems = [
            PackingItem(name: String(localized: "Passport")),
            PackingItem(name: String(localized: "Camera")),
            PackingItem(name: String(localized: "Walking Shoes")),
            PackingItem(name: String(localized: "Light Jacket"))
        ]
        self.documents = [
            TravelDocument(name: String(localized: "Flight to Paris"), type: .ticket),
            TravelDocument(name: String(localized: "Hotel Confirmation"), type: .reservation),
            TravelDocument(name: String(localized: "Travel Insurance"), type: .insurance)
        ]
        let dayOneItems = [
            DayPlanItem(time: DateComponents(hour: 9, minute: 30), title: String(localized: "Breakfast at Café de Flore"), details: String(localized: "Classic Parisian breakfast with croissants."), location: String(localized: "Saint-Germain-des-Prés")),
            DayPlanItem(time: DateComponents(hour: 11, minute: 0), title: String(localized: "Visit the Louvre"), details: String(localized: "Explore the Denon Wing and Mona Lisa.")),
            DayPlanItem(time: DateComponents(hour: 18, minute: 30), title: String(localized: "Seine River Cruise"), details: String(localized: "Sunset cruise with dinner."))
        ]
        let dayTwoItems = [
            DayPlanItem(time: DateComponents(hour: 10, minute: 0), title: String(localized: "Montmartre Walking Tour"), details: String(localized: "Guided tour through artist quarter.")),
            DayPlanItem(time: DateComponents(hour: 14, minute: 0), title: String(localized: "Cooking Class"), details: String(localized: "Learn to bake macarons."))
        ]
        self.dayPlans = [
            DayPlan(date: today, title: String(localized: "Arrival & Museums"), items: dayOneItems),
            DayPlan(date: inThreeDays, title: String(localized: "Neighborhood Exploration"), items: dayTwoItems)
        ]
        self.segments = [
            TripSegment(
                title: String(localized: "Flight to Paris"),
                subtitle: String(localized: "SFO → CDG"),
                mode: .flight,
                departure: TripSegment.Event(date: today, location: String(localized: "San Francisco International Airport"), notes: String(localized: "Check in 3 hours early.")),
                arrival: TripSegment.Event(date: calendar.date(byAdding: .hour, value: 11, to: today) ?? today, location: String(localized: "Charles de Gaulle Airport"), notes: String(localized: "Arrange airport transfer.")),
                notes: String(localized: "Upgrade to extra legroom seats."))
        ]
    }
    
    func addTrip() {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 5, to: start) ?? start
        let trip = Trip(name: String(localized: "New Trip"), destination: String(localized: "Destination"), startDate: start, endDate: end)
        trips.append(trip)
    }
    
    func deleteTrips(at offsets: IndexSet) {
        trips.remove(atOffsets: offsets)
    }
    
    func addPackingItem(name: String = String(localized: "New Item")) {
        packingItems.append(PackingItem(name: name))
    }
    
    func togglePackingItem(_ item: PackingItem) {
        guard let index = packingItems.firstIndex(where: { $0.id == item.id }) else { return }
        packingItems[index].isChecked.toggle()
    }
    
    func deletePackingItems(at offsets: IndexSet) {
        packingItems.remove(atOffsets: offsets)
    }
    
    func addDocument(name: String = String(localized: "New Document"), type: TravelDocument.DocumentType = .other) {
        documents.append(TravelDocument(name: name, type: type))
    }
    
    func deleteDocuments(at offsets: IndexSet) {
        documents.remove(atOffsets: offsets)
    }
    
    func addPlan(on date: Date) {
        let plan = DayPlan(date: calendar.startOfDay(for: date), title: String(localized: "New Day Plan"))
        dayPlans.append(plan)
        dayPlans.sort { $0.date < $1.date }
    }
    
    func items(for date: Date) -> [DayPlanItem] {
        let dayStart = calendar.startOfDay(for: date)
        guard let plan = dayPlans.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) else {
            return []
        }
        return plan.items
    }
}

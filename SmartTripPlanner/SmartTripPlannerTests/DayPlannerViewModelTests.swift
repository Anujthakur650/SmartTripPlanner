import XCTest
@testable import SmartTripPlanner

@MainActor
final class DayPlannerViewModelTests: XCTestCase {
    private var repository: MockPlannerRepository!
    private var suggestionProvider: MockSuggestionProvider!
    private var haptics: MockHaptics!
    private var environment: AppEnvironment!
    private var calendar: Calendar!
    
    override func setUp() {
        super.setUp()
        repository = MockPlannerRepository()
        suggestionProvider = MockSuggestionProvider()
        haptics = MockHaptics()
        environment = AppEnvironment()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(abbreviation: "GMT") ?? .current
    }
    
    override func tearDown() {
        repository = nil
        suggestionProvider = nil
        haptics = nil
        environment = nil
        calendar = nil
        super.tearDown()
    }
    
    func testMoveItemMaintainsChronologicalOrdering() {
        let day = calendar.date(from: DateComponents(year: 2024, month: 5, day: 12))!
        let breakfast = DayPlanItem(
            title: "Breakfast",
            startDate: calendar.combine(day: day, hour: 9, minute: 0),
            duration: 60 * 60
        )
        let museum = DayPlanItem(
            title: "Museum",
            startDate: calendar.combine(day: day, hour: 11, minute: 0),
            duration: 90 * 60
        )
        let state = PlannerState(days: [DayPlan(date: day, items: [breakfast, museum])], activityLog: [])
        repository.state = state
        let dependencies = DayPlannerViewModel.Dependencies(
            repository: repository,
            environment: environment,
            suggestionProvider: suggestionProvider,
            haptics: haptics
        )
        let viewModel = DayPlannerViewModel(
            dependencies: dependencies,
            selectedDate: day,
            calendar: calendar,
            initialState: state
        )
        viewModel.configureIfNeeded(dependencies)
        
        let moveResult = viewModel.moveItem(
            with: museum.id,
            from: day.isoDayIdentifier,
            to: day,
            proposedStartDate: calendar.combine(day: day, hour: 8, minute: 30)
        )
        XCTAssertTrue(moveResult)
        let items = viewModel.items(for: day)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.id, museum.id)
        XCTAssertEqual(items.last?.id, breakfast.id)
        XCTAssertEqual(items.first?.startDate, calendar.combine(day: day, hour: 8, minute: 30))
        XCTAssertEqual(haptics.successCount, 1)
    }
    
    func testMoveItemPreventsOverlapConflicts() {
        let day = calendar.date(from: DateComponents(year: 2024, month: 6, day: 20))!
        let meeting = DayPlanItem(
            title: "Client Meeting",
            startDate: calendar.combine(day: day, hour: 9, minute: 0),
            duration: 60 * 60
        )
        let lunch = DayPlanItem(
            title: "Lunch",
            startDate: calendar.combine(day: day, hour: 10, minute: 0),
            duration: 60 * 60
        )
        let state = PlannerState(days: [DayPlan(date: day, items: [meeting, lunch])], activityLog: [])
        repository.state = state
        let dependencies = DayPlannerViewModel.Dependencies(
            repository: repository,
            environment: environment,
            suggestionProvider: suggestionProvider,
            haptics: haptics
        )
        let viewModel = DayPlannerViewModel(
            dependencies: dependencies,
            selectedDate: day,
            calendar: calendar,
            initialState: state
        )
        viewModel.configureIfNeeded(dependencies)
        
        let result = viewModel.moveItem(
            with: lunch.id,
            from: day.isoDayIdentifier,
            to: day,
            proposedStartDate: calendar.combine(day: day, hour: 9, minute: 30)
        )
        XCTAssertFalse(result)
        let itemsAfter = viewModel.items(for: day)
        XCTAssertEqual(itemsAfter[1].startDate, calendar.combine(day: day, hour: 10, minute: 0))
        XCTAssertNotNil(viewModel.conflict)
        XCTAssertEqual(haptics.errorCount, 1)
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockPlannerRepository: PlannerRepositoryProviding {
    var state: PlannerState = .empty
    private(set) var savedStates: [PlannerState] = []
    
    func loadState() async -> PlannerState {
        state
    }
    
    func save(state: PlannerState, isOnline: Bool) async {
        savedStates.append(state)
        self.state = state
    }
    
    func flushPendingIfNeeded(isOnline: Bool) async {}
}

private final class MockSuggestionProvider: QuickAddSuggestionProviding {
    func suggestions(for tripType: TripType, recentItems: [DayPlanItem]) -> [QuickAddSuggestion] { [] }
    func recordUsage(_ item: DayPlanItem) {}
}

private final class MockHaptics: HapticFeedbackProviding {
    private(set) var successCount = 0
    private(set) var warningCount = 0
    private(set) var errorCount = 0
    
    func success() {
        successCount += 1
    }
    
    func warning() {
        warningCount += 1
    }
    
    func error() {
        errorCount += 1
    }
}

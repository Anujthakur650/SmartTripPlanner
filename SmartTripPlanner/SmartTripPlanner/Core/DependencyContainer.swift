import Foundation
import SwiftUI
import Combine

@MainActor
class DependencyContainer: ObservableObject {
    let appEnvironment: AppEnvironment
    let analyticsService: AnalyticsService
    let weatherService: WeatherService
    let mapsService: MapsService
    let calendarService: CalendarService
    let emailService: EmailService
    let exportService: ExportService
    let dataController: TripDataController
    let syncService: SyncService
    let tripsRepository: TripsRepository
    let plannerRepository: PlannerRepositoryProviding
    let hapticFeedbackService: HapticFeedbackProviding
    let quickAddSuggestionProvider: QuickAddSuggestionProviding
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.appEnvironment = AppEnvironment()
        self.analyticsService = AnalyticsService()
        self.weatherService = WeatherService()
        self.mapsService = MapsService(analyticsService: analyticsService)
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.exportService = ExportService()
        let dataController = TripDataController()
        self.dataController = dataController
        let syncService = SyncService(coordinator: dataController.syncCoordinator)
        self.syncService = syncService
        self.tripsRepository = TripsRepository()
        self.plannerRepository = DayPlannerRepository(syncService: syncService)
        self.hapticFeedbackService = HapticFeedbackService()
        self.quickAddSuggestionProvider = QuickAddSuggestionProvider()
        self.syncService.scheduleBackgroundSync()
        self.syncService.$isOnline
            .receive(on: RunLoop.main)
            .sink { [weak appEnvironment] isOnline in
                appEnvironment?.isOnline = isOnline
            }
            .store(in: &cancellables)
        self.syncService.$syncStatus
            .receive(on: RunLoop.main)
            .sink { [weak appEnvironment] status in
                appEnvironment?.isSyncing = (status == .syncing)
            }
            .store(in: &cancellables)
    }
}

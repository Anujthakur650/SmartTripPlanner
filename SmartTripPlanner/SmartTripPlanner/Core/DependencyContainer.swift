import Foundation
import SwiftUI

@MainActor
class DependencyContainer: ObservableObject {
    let appEnvironment: AppEnvironment
    let analyticsService: AnalyticsService
    let weatherService: WeatherService
    let mapsService: MapsService
    let calendarService: CalendarService
    let emailService: EmailService
    let exportService: ExportService
    let syncService: SyncService
    let plannerRepository: PlannerRepositoryProviding
    let hapticFeedbackService: HapticFeedbackProviding
    let quickAddSuggestionProvider: QuickAddSuggestionProviding
    
    init() {
        self.appEnvironment = AppEnvironment()
        self.analyticsService = AnalyticsService()
        self.weatherService = WeatherService()
        self.mapsService = MapsService(analyticsService: analyticsService)
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.exportService = ExportService()
        self.syncService = SyncService()
        self.plannerRepository = DayPlannerRepository(syncService: syncService)
        self.hapticFeedbackService = HapticFeedbackService()
        self.quickAddSuggestionProvider = QuickAddSuggestionProvider()
    }
}

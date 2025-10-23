import Foundation
import SwiftUI

@MainActor
class DependencyContainer: ObservableObject {
    let configuration: AppConfiguration
    let appEnvironment: AppEnvironment
    let analyticsService: AnalyticsService
    let weatherService: WeatherService
    let mapsService: MapsService
    let calendarService: CalendarService
    let emailService: EmailService
    let exportService: ExportService
    let syncService: SyncService
    
    init(configuration: AppConfiguration = .shared) {
        self.configuration = configuration
        self.appEnvironment = AppEnvironment()
        self.analyticsService = AnalyticsService()
        self.weatherService = WeatherService()
        self.mapsService = MapsService(analyticsService: analyticsService)
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.exportService = ExportService()
        self.syncService = SyncService()
    }
}

import Foundation
import SwiftUI

@MainActor
final class DependencyContainer: ObservableObject {
    let appEnvironment: AppEnvironment
    let analyticsService: AnalyticsService
    let weatherService: WeatherService
    let mapsService: MapsService
    let calendarService: CalendarService
    let emailService: EmailService
    let exportService: ExportService
    let syncService: SyncService
    
    init(
        appEnvironment: AppEnvironment = AppEnvironment(),
        analyticsService: AnalyticsService = AnalyticsService(),
        weatherService: WeatherService = WeatherService(),
        mapsService: MapsService? = nil,
        calendarService: CalendarService = CalendarService(),
        emailService: EmailService = EmailService(),
        exportService: ExportService = ExportService(),
        syncService: SyncService? = nil
    ) {
        self.appEnvironment = appEnvironment
        self.analyticsService = analyticsService
        self.weatherService = weatherService
        self.mapsService = mapsService ?? MapsService(analyticsService: analyticsService)
        self.calendarService = calendarService
        self.emailService = emailService
        self.exportService = exportService
        self.syncService = syncService ?? SyncService(appEnvironment: appEnvironment)
    }
}

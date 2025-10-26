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
    
    init() {
        let analyticsService = AnalyticsService()
        let appEnvironment = AppEnvironment()
        let weatherService = WeatherService()
        let mapsService = MapsService(analyticsService: analyticsService)
        let calendarService = CalendarService()
        let syncService = SyncService()
        let emailService = EmailService(syncService: syncService)
        let exportService = ExportService()
        
        self.analyticsService = analyticsService
        self.appEnvironment = appEnvironment
        self.weatherService = weatherService
        self.mapsService = mapsService
        self.calendarService = calendarService
        self.syncService = syncService
        self.emailService = emailService
        self.exportService = exportService
    }
}

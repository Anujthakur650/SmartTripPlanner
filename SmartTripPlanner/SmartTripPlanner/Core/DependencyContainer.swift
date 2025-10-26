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
    let offlineMapCache: OfflineMapCache
    
    init() {
        self.appEnvironment = AppEnvironment()
        self.analyticsService = AnalyticsService()
        self.weatherService = WeatherService()
        self.offlineMapCache = OfflineMapCache()
        self.mapsService = MapsService(analyticsService: analyticsService, offlineCache: offlineMapCache)
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.exportService = ExportService()
        self.syncService = SyncService()
    }
}

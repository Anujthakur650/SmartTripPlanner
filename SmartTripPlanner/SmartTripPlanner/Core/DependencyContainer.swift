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
    let travelDataStore: TravelDataStore
    let exportService: ExportService
    let syncService: SyncService
    
    init() {
        self.appEnvironment = AppEnvironment()
        self.analyticsService = AnalyticsService()
        self.weatherService = WeatherService()
        self.mapsService = MapsService(analyticsService: analyticsService)
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.travelDataStore = TravelDataStore()
        self.exportService = ExportService(appEnvironment: appEnvironment, travelDataSource: travelDataStore, mapsDataSource: mapsService)
        self.syncService = SyncService()
    }
}

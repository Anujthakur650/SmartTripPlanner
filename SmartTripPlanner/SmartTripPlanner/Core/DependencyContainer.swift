import Foundation
import SwiftUI

@MainActor
class DependencyContainer: ObservableObject {
    let appEnvironment: AppEnvironment
    let weatherService: WeatherService
    let mapsService: MapsService
    let calendarService: CalendarService
    let emailService: EmailService
    let exportService: ExportService
    let syncService: SyncService
    
    init() {
        self.appEnvironment = AppEnvironment()
        self.weatherService = WeatherService()
        self.mapsService = MapsService()
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.exportService = ExportService()
        self.syncService = SyncService()
    }
}

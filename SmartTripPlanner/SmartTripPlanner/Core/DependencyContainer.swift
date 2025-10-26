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
    let documentStore: DocumentStore
    let offlineMapCache: OfflineMapCache
    
    init() {
        self.appEnvironment = AppEnvironment()
        self.analyticsService = AnalyticsService()
        self.weatherService = WeatherService()
        self.exportService = ExportService()
        if let store = try? DocumentStore() {
            self.documentStore = store
        } else {
            let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("Documents", isDirectory: true)
            self.documentStore = (try? DocumentStore(directory: fallback)) ?? {
                fatalError("Failed to initialize DocumentStore")
            }()
        }
        self.offlineMapCache = OfflineMapCache()
        self.mapsService = MapsService(analyticsService: analyticsService, offlineCache: offlineMapCache)
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.syncService = SyncService()
    }
}

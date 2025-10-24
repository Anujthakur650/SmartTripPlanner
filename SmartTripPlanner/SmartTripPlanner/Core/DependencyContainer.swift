import Combine
import Foundation
import SwiftUI

@MainActor
class DependencyContainer: ObservableObject {
    let appEnvironment: AppEnvironment
    let analyticsService: AnalyticsService
    let weatherService: WeatherService
    let privacySettingsService: PrivacySettingsService
    let syncService: SyncService
    let mapsService: MapsService
    let calendarService: CalendarService
    let emailService: EmailService
    let exportService: ExportService
    let backgroundRefreshService: BackgroundRefreshService
    let accountService: AccountService
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.appEnvironment = AppEnvironment()
        self.analyticsService = AnalyticsService()
        self.weatherService = WeatherService()
        self.privacySettingsService = PrivacySettingsService()
        self.syncService = SyncService()
        self.mapsService = MapsService(analyticsService: analyticsService)
        self.calendarService = CalendarService()
        self.emailService = EmailService()
        self.exportService = ExportService()
        self.backgroundRefreshService = BackgroundRefreshService(syncService: syncService)
        self.accountService = AccountService(
            emailService: emailService,
            syncService: syncService,
            privacySettings: privacySettingsService,
            mapsService: mapsService,
            analyticsService: analyticsService
        )
        configureBindings()
    }
    
    private func configureBindings() {
        analyticsService.isEnabled = privacySettingsService.analyticsEnabled
        analyticsService.diagnosticsOptIn = privacySettingsService.diagnosticsEnabled
        privacySettingsService.$analyticsEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.analyticsService.isEnabled = isEnabled
            }
            .store(in: &cancellables)
        privacySettingsService.$diagnosticsEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.analyticsService.diagnosticsOptIn = isEnabled
            }
            .store(in: &cancellables)
        privacySettingsService.$backgroundRefreshEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.backgroundRefreshService.updateScheduling(isEnabled: isEnabled)
            }
            .store(in: &cancellables)
    }
}

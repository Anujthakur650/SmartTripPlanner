import SwiftUI

@main
struct SmartTripPlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var container: DependencyContainer
    @StateObject private var navigationCoordinator: NavigationCoordinator
    
    init() {
        let dependencyContainer = DependencyContainer()
        _container = StateObject(wrappedValue: dependencyContainer)
        _navigationCoordinator = StateObject(wrappedValue: NavigationCoordinator())
        appDelegate.dependencyContainer = dependencyContainer
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(navigationCoordinator)
                .environmentObject(container.appEnvironment)
                .environmentObject(container.privacySettingsService)
                .environmentObject(container.emailService)
                .environmentObject(container.accountService)
                .onAppear {
                    container.backgroundRefreshService.updateScheduling(
                        isEnabled: container.privacySettingsService.backgroundRefreshEnabled
                    )
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background,
                       container.privacySettingsService.backgroundRefreshEnabled {
                        container.backgroundRefreshService.scheduleBackgroundTasks()
                    }
                }
        }
    }
}

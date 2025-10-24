import BackgroundTasks
import SwiftUI
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    weak var dependencyContainer: DependencyContainer?
    private let minimumFetchInterval: TimeInterval = 60 * 60 // 1 hour
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.setMinimumBackgroundFetchInterval(minimumFetchInterval)
        dependencyContainer?.backgroundRefreshService.registerBackgroundTasks()
        if let isEnabled = dependencyContainer?.privacySettingsService.backgroundRefreshEnabled {
            dependencyContainer?.backgroundRefreshService.updateScheduling(isEnabled: isEnabled)
        }
        return true
    }
    
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let syncService = dependencyContainer?.syncService else {
            completionHandler(.noData)
            return
        }
        Task {
            do {
                try await syncService.syncAllData()
                completionHandler(.newData)
            } catch {
                completionHandler(.failed)
            }
        }
    }
}

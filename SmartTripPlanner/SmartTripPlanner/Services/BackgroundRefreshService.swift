import BackgroundTasks
import Foundation

@MainActor
final class BackgroundRefreshService: ObservableObject {
    private let refreshIdentifier = "com.smarttripplanner.refresh"
    private let processingIdentifier = "com.smarttripplanner.sync"
    private let syncService: SyncService
    private var isRegistered = false
    
    init(syncService: SyncService) {
        self.syncService = syncService
    }
    
    func registerBackgroundTasks() {
        guard !isRegistered else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleAppRefresh(task: refreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingIdentifier, using: nil) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleProcessingTask(task: processingTask)
        }
        isRegistered = true
    }
    
    func updateScheduling(isEnabled: Bool) {
        registerBackgroundTasks()
        if isEnabled {
            scheduleBackgroundTasks()
        } else {
            cancelAllTaskRequests()
        }
    }
    
    func scheduleBackgroundTasks() {
        scheduleAppRefresh()
        scheduleProcessingTask()
    }
    
    func scheduleAppRefresh(earliestBeginDate: Date = Date(timeIntervalSinceNow: 60 * 60)) {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("[BackgroundRefresh] Failed to schedule app refresh: \(error.localizedDescription)")
            #endif
        }
    }
    
    func scheduleProcessingTask(earliestBeginDate: Date = Date(timeIntervalSinceNow: 2 * 60 * 60)) {
        let request = BGProcessingTaskRequest(identifier: processingIdentifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("[BackgroundRefresh] Failed to schedule processing task: \(error.localizedDescription)")
            #endif
        }
    }
    
    func cancelAllTaskRequests() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: processingIdentifier)
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        Task { @MainActor in
            do {
                try await syncService.syncAllData()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func handleProcessingTask(task: BGProcessingTask) {
        scheduleProcessingTask()
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        Task { @MainActor in
            do {
                try await syncService.syncAllData()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
}

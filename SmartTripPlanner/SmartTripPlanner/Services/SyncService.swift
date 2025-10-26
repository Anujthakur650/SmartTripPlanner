import Foundation
import Combine

@MainActor
final class SyncService: ObservableObject {
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(Error)
    }

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published var isOnline: Bool {
        didSet {
            if isOnline != oldValue {
                coordinator.setOnline(isOnline)
            }
        }
    }

    private let coordinator: TripSyncCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: TripSyncCoordinator) {
        self.coordinator = coordinator
        self.isOnline = coordinator.isOnline

        coordinator.$lastSuccessfulSync
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.lastSyncDate = value
            }
            .store(in: &cancellables)

        coordinator.$isOnline
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.isOnline = value
            }
            .store(in: &cancellables)
    }

    func synchronizeNow() async {
        syncStatus = .syncing
        do {
            try await coordinator.processPendingChanges()
            try await coordinator.flushOutboxIfNeeded()
            await coordinator.performPull()
            syncStatus = .success
        } catch {
            syncStatus = .failed(error)
        }
    }

    func scheduleBackgroundSync(interval: TimeInterval = 180) {
        coordinator.scheduleBackgroundSync(interval: interval)
    }
}

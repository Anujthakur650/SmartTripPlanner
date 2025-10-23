import Foundation
import SwiftData

@MainActor
final class TripSyncCoordinator: ObservableObject {
    struct PendingChange {
        let id: UUID
        let entityName: String
        let entityId: UUID
        let isDeletion: Bool
        let description: String
        let work: (ModelContext) throws -> Date
    }

    struct ChangeEnvelope: Codable, Equatable {
        let id: UUID
        let updatedAt: Date
        let isDeleted: Bool
    }

    enum SyncError: Swift.Error, LocalizedError {
        case changeApplicationFailed(String)
        case mergeHandlerMissing(String)

        var errorDescription: String? {
            switch self {
            case let .changeApplicationFailed(reason):
                return "Failed to apply change: \(reason)"
            case let .mergeHandlerMissing(entity):
                return "No merge handler registered for entity \(entity)"
            }
        }
    }

    private let container: ModelContainer
    private let context: ModelContext
    private let cloudAdapter: CloudKitSyncAdapter
    private var pendingChanges: [PendingChange] = []
    private var outboxChanges: [CloudChangePayload] = []
    private var outboxDeletions: [CloudDeletionPayload] = []
    private var remoteUpdateHandlers: [String: (CloudChangePayload, ModelContext) throws -> Void] = [:]
    private var remoteDeletionHandlers: [String: (CloudDeletionPayload, ModelContext) throws -> Void] = [:]
    private var backgroundSyncTask: Task<Void, Never>?
    private var lastPulledAt: Date?
    private var lastServerToken: Data?

    @Published private(set) var isOnline: Bool
    @Published private(set) var lastSuccessfulSync: Date?

    init(
        container: ModelContainer,
        context: ModelContext,
        cloudAdapter: CloudKitSyncAdapter,
        isOnline: Bool = true
    ) {
        self.container = container
        self.context = context
        self.cloudAdapter = cloudAdapter
        self.isOnline = isOnline
    }

    deinit {
        backgroundSyncTask?.cancel()
    }

    func setOnline(_ isOnline: Bool) {
        let previous = self.isOnline
        self.isOnline = isOnline
        guard !previous, isOnline else { return }
        Task { [weak self] in
            guard let self else { return }
            try await self.processPendingChanges()
            try await self.flushOutboxIfNeeded()
        }
    }

    func registerUpdateHandler(
        for entityName: String,
        handler: @escaping (CloudChangePayload, ModelContext) throws -> Void
    ) {
        remoteUpdateHandlers[entityName] = handler
    }

    func registerDeletionHandler(
        for entityName: String,
        handler: @escaping (CloudDeletionPayload, ModelContext) throws -> Void
    ) {
        remoteDeletionHandlers[entityName] = handler
    }

    func enqueueChange(
        description: String,
        entityName: String,
        entityId: UUID,
        isDeletion: Bool = false,
        work: @escaping (ModelContext) throws -> Date
    ) async throws {
        let change = PendingChange(
            id: UUID(),
            entityName: entityName,
            entityId: entityId,
            isDeletion: isDeletion,
            description: description,
            work: work
        )
        do {
            try tryApply(change)
        } catch {
            pendingChanges.append(change)
            throw error
        }
        do {
            try await flushOutboxIfNeeded()
        } catch {
            // Retain change in outbox; caller can retry later when online.
        }
    }

    func scheduleBackgroundSync(interval: TimeInterval = 180) {
        backgroundSyncTask?.cancel()
        backgroundSyncTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard self.isOnline else { continue }
                await self.performPull()
            }
        }
    }

    func performPull() async {
        do {
            let response = try await cloudAdapter.pull(since: lastPulledAt, serverChangeToken: lastServerToken)
            for change in response.updated {
                guard let handler = remoteUpdateHandlers[change.entityName] else {
                    throw SyncError.mergeHandlerMissing(change.entityName)
                }
                try handler(change, context)
            }
            for deletion in response.deleted {
                if let handler = remoteDeletionHandlers[deletion.entityName] {
                    try handler(deletion, context)
                }
            }
            if context.hasChanges {
                try context.save()
            }
            lastPulledAt = Date()
            lastServerToken = response.serverChangeToken
            lastSuccessfulSync = Date()
        } catch {
            // Retain state for retry; logging infrastructure could consume this later.
        }
    }

    func processPendingChanges() async throws {
        guard !pendingChanges.isEmpty else { return }
        var failed: [PendingChange] = []
        for change in pendingChanges {
            do {
                try tryApply(change)
            } catch {
                failed.append(change)
            }
        }
        pendingChanges = failed
        try? await flushOutboxIfNeeded()
    }

    func flushOutboxIfNeeded() async throws {
        guard isOnline else { return }
        guard !outboxChanges.isEmpty || !outboxDeletions.isEmpty else { return }
        do {
            try await cloudAdapter.push(changes: outboxChanges, deletions: outboxDeletions)
            outboxChanges.removeAll()
            outboxDeletions.removeAll()
            lastSuccessfulSync = Date()
        } catch {
            throw error
        }
    }

    func makeEnvelope(for entityId: UUID, updatedAt: Date, isDeleted: Bool) throws -> Data {
        let envelope = ChangeEnvelope(id: entityId, updatedAt: updatedAt, isDeleted: isDeleted)
        return try JSONEncoder().encode(envelope)
    }

    private func tryApply(_ change: PendingChange) throws {
        do {
            let updatedAt = try change.work(context)
            if context.hasChanges {
                try context.save()
            }
            if change.isDeletion {
                outboxDeletions.append(
                    CloudDeletionPayload(
                        entityName: change.entityName,
                        recordIdentifier: change.entityId.uuidString,
                        deletedAt: updatedAt
                    )
                )
            } else {
                let payload = try makeEnvelope(for: change.entityId, updatedAt: updatedAt, isDeleted: false)
                outboxChanges.append(
                    CloudChangePayload(
                        entityName: change.entityName,
                        recordIdentifier: change.entityId.uuidString,
                        payload: payload,
                        modifiedAt: updatedAt
                    )
                )
            }
        } catch {
            throw SyncError.changeApplicationFailed(change.description)
        }
    }

    func shouldAcceptRemoteChange(localUpdatedAt: Date?, remoteUpdatedAt: Date) -> Bool {
        guard let localUpdatedAt else { return true }
        return remoteUpdatedAt >= localUpdatedAt
    }
}

import XCTest
import SwiftData
@testable import SmartTripPlanner

final class TripDataPersistenceTests: XCTestCase {
    @MainActor
    private func makeController(adapter: TestCloudAdapter = TestCloudAdapter()) -> TripDataController {
        TripDataController(inMemory: true, cloudAdapter: adapter)
    }

    @MainActor
    func testRepositoryCRUDOperationsProvideDeterministicIDs() async throws {
        let adapter = TestCloudAdapter()
        let controller = makeController(adapter: adapter)

        let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let profile = UserProfileRecord(id: userId, displayName: "Tester", email: "tester@example.com")

        try await controller.userProfiles.insert(profile)

        let fetched = try controller.userProfiles.entity(with: userId)

        XCTAssertEqual(fetched?.id, userId)
        XCTAssertEqual(adapter.pushedChanges.count, 1)
        XCTAssertEqual(adapter.pushedChanges.first?.first?.recordIdentifier, userId.uuidString)
    }

    @MainActor
    func testOfflineEditsQueueAndFlushWhenConnectivityRestored() async throws {
        let adapter = TestCloudAdapter()
        let controller = makeController(adapter: adapter)

        controller.syncCoordinator.setOnline(false)

        let tripId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let owner = UserProfileRecord(displayName: "Offline", email: "offline@example.com")
        try await controller.userProfiles.insert(owner)
        let trip = TripRecord(id: tripId, name: "Offline Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400), owner: owner)

        try await controller.trips.insert(trip)

        XCTAssertTrue(adapter.pushedChanges.isEmpty)

        controller.syncCoordinator.setOnline(true)
        try await controller.syncCoordinator.flushOutboxIfNeeded()

        XCTAssertEqual(adapter.pushedChanges.count, 1)
        XCTAssertEqual(adapter.pushedChanges.first?.count, 2)
        XCTAssertEqual(adapter.pushedChanges.first?.last?.recordIdentifier, tripId.uuidString)
    }

    @MainActor
    func testConflictResolutionUsesLastWriterWins() async throws {
        let adapter = TestCloudAdapter()
        let controller = makeController(adapter: adapter)

        let tripId = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let owner = UserProfileRecord(displayName: "Conflict Owner", email: "conflict@example.com")
        try await controller.userProfiles.insert(owner)
        let trip = TripRecord(id: tripId, name: "Conflict Trip", startDate: Date(), endDate: Date().addingTimeInterval(7200), owner: owner)
        trip.updatedAt = Date(timeIntervalSince1970: 1)
        try await controller.trips.insert(trip)

        let remoteDate = Date(timeIntervalSince1970: 200)
        let envelope = TripSyncCoordinator.ChangeEnvelope(id: tripId, updatedAt: remoteDate, isDeleted: false)
        let payload = try JSONEncoder().encode(envelope)
        let entityName = String(describing: TripRecord.self)
        adapter.pullResponses.append(
            CloudPullResponse(
                updated: [CloudChangePayload(entityName: entityName, recordIdentifier: tripId.uuidString, payload: payload, modifiedAt: remoteDate)],
                deleted: [],
                serverChangeToken: nil
            )
        )

        await controller.syncCoordinator.performPull()

        let fetched = try controller.trips.entity(with: tripId)
        XCTAssertEqual(fetched?.updatedAt, remoteDate)
        XCTAssertFalse(fetched?.isDeleted ?? true)
    }

    @MainActor
    func testCloudKitPullProcessesDeletionsWithTombstones() async throws {
        let adapter = TestCloudAdapter()
        let controller = makeController(adapter: adapter)

        let docId = UUID(uuidString: "deadbeef-dead-beef-dead-beefdead0001")!
        let owner = UserProfileRecord(displayName: "Doc Owner", email: "doc@example.com")
        try await controller.userProfiles.insert(owner)
        let trip = TripRecord(name: "Doc Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400), owner: owner)
        try await controller.trips.insert(trip)
        let asset = DocumentAssetRecord(id: docId, title: "Ticket", fileName: "ticket.pdf", mimeType: "application/pdf", trip: trip)
        try await controller.documents.insert(asset)

        let deletionPayload = CloudDeletionPayload(entityName: String(describing: DocumentAssetRecord.self), recordIdentifier: docId.uuidString, deletedAt: Date())
        adapter.pullResponses.append(
            CloudPullResponse(updated: [], deleted: [deletionPayload], serverChangeToken: nil)
        )

        await controller.syncCoordinator.performPull()

        let fetched = try controller.documents.entity(with: docId)
        XCTAssertTrue(fetched?.isDeleted ?? false)
        XCTAssertNotNil(fetched?.deletedAt)
    }

    func testMigrationPlanBootstrapsContainer() {
        let configuration = ModelConfiguration(
            for: TripDataSchemaV1.models,
            isStoredInMemoryOnly: true
        )
        XCTAssertNoThrow(
            try ModelContainer(
                for: TripDataSchema.self,
                migrationPlan: TripDataMigrationPlan.self,
                configurations: [configuration]
            )
        )
    }
}

final class TestCloudAdapter: CloudKitSyncAdapter {
    enum TestError: Error {
        case simulated
    }

    private(set) var pushedChanges: [[CloudChangePayload]] = []
    private(set) var pushedDeletions: [[CloudDeletionPayload]] = []
    var pullResponses: [CloudPullResponse] = []
    var shouldFailPush = false

    func push(changes: [CloudChangePayload], deletions: [CloudDeletionPayload]) async throws {
        if shouldFailPush {
            throw TestError.simulated
        }
        if !changes.isEmpty {
            pushedChanges.append(changes)
        }
        if !deletions.isEmpty {
            pushedDeletions.append(deletions)
        }
    }

    func pull(since: Date?, serverChangeToken: Data?) async throws -> CloudPullResponse {
        if !pullResponses.isEmpty {
            return pullResponses.removeFirst()
        }
        return CloudPullResponse(updated: [], deleted: [], serverChangeToken: serverChangeToken)
    }
}

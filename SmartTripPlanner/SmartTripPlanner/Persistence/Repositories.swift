import Foundation
import Combine
import SwiftData

protocol TripDataRepository<Entity>: AnyObject {
    associatedtype Entity: PersistentModel & SoftDeletableEntity & TimestampedEntity
    var changes: AnyPublisher<[Entity], Never> { get }
    func all(includeDeleted: Bool) throws -> [Entity]
    func entity(with id: UUID) throws -> Entity?
    func insert(_ entity: Entity) async throws
    func update(id: UUID, mutate: @escaping (Entity) -> Void) async throws
    func softDelete(id: UUID) async throws
    func hardDelete(id: UUID) async throws
}

final class SwiftDataRepository<Entity>: TripDataRepository where Entity: PersistentModel & SoftDeletableEntity & TimestampedEntity {
    private let context: ModelContext
    private unowned let syncCoordinator: TripSyncCoordinator
    private let entityName: String
    private let subject = CurrentValueSubject<[Entity], Never>([])

    var changes: AnyPublisher<[Entity], Never> {
        subject.eraseToAnyPublisher()
    }

    init(context: ModelContext, syncCoordinator: TripSyncCoordinator, entityName: String, initialFetch: Bool = true) {
        self.context = context
        self.syncCoordinator = syncCoordinator
        self.entityName = entityName
        if initialFetch {
            subject.value = (try? all(includeDeleted: false)) ?? []
        }
    }

    func all(includeDeleted: Bool) throws -> [Entity] {
        var descriptor = FetchDescriptor<Entity>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        if !includeDeleted {
            descriptor.predicate = #Predicate { entity in
                entity.isDeleted == false
            }
        }
        return try context.fetch(descriptor)
    }

    func entity(with id: UUID) throws -> Entity? {
        var descriptor = FetchDescriptor<Entity>(predicate: #Predicate { entity in
            entity.id == id
        })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ entity: Entity) async throws {
        try await syncCoordinator.enqueueChange(
            description: "Insert \(entityName)",
            entityName: entityName,
            entityId: entity.id,
            isDeletion: false
        ) { context in
            context.insert(entity)
            let now = Date()
            entity.updatedAt = now
            if entity.createdAt > now {
                entity.createdAt = now
            }
            return entity.updatedAt
        }
        subject.value = (try? all(includeDeleted: false)) ?? []
    }

    func update(id: UUID, mutate: @escaping (Entity) -> Void) async throws {
        try await syncCoordinator.enqueueChange(
            description: "Update \(entityName)",
            entityName: entityName,
            entityId: id,
            isDeletion: false
        ) { context in
            guard let entity = try context.fetch(
                FetchDescriptor<Entity>(predicate: #Predicate { $0.id == id })
            ).first else {
                throw TripSyncCoordinator.SyncError.changeApplicationFailed("Missing entity \(id)")
            }
            mutate(entity)
            entity.updatedAt = Date()
            return entity.updatedAt
        }
        subject.value = (try? all(includeDeleted: false)) ?? []
    }

    func softDelete(id: UUID) async throws {
        try await syncCoordinator.enqueueChange(
            description: "Soft delete \(entityName)",
            entityName: entityName,
            entityId: id,
            isDeletion: true
        ) { context in
            guard let entity = try context.fetch(
                FetchDescriptor<Entity>(predicate: #Predicate { $0.id == id })
            ).first else {
                throw TripSyncCoordinator.SyncError.changeApplicationFailed("Missing entity \(id)")
            }
            entity.isDeleted = true
            entity.deletedAt = Date()
            entity.updatedAt = entity.deletedAt ?? Date()
            return entity.updatedAt
        }
        subject.value = (try? all(includeDeleted: false)) ?? []
    }

    func hardDelete(id: UUID) async throws {
        try await syncCoordinator.enqueueChange(
            description: "Hard delete \(entityName)",
            entityName: entityName,
            entityId: id,
            isDeletion: true
        ) { context in
            guard let entity = try context.fetch(
                FetchDescriptor<Entity>(predicate: #Predicate { $0.id == id })
            ).first else {
                return Date()
            }
            context.delete(entity)
            return Date()
        }
        subject.value = (try? all(includeDeleted: false)) ?? []
    }
}

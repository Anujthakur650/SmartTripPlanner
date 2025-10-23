# Data Model & Sync Architecture

## Overview

SmartTripPlanner persists all domain entities with **SwiftData** using **CloudKit mirroring** for seamless offline-first behaviour on every Apple platform. A single `ModelContainer` is configured with the CloudKit container `iCloud.com.smarttripplanner.SmartTripPlanner` which mirrors the local store to the user's private database. CloudKit mirroring lets us keep mobile clients in sync while ensuring local reads and writes always succeed, even without connectivity.

`TripDataController` encapsulates the SwiftData stack, exposes entity-specific repositories, and coordinates background synchronisation through `TripSyncCoordinator`. Each repository offers deterministic identifiers (UUIDs supplied at creation time) and surfaces CRUD APIs with soft-deletion (tombstones) to guarantee change history and reliable cloud reconciliation.

## Schema

The schema is defined in `TripDataSchemaV1` and versioned via `TripDataMigrationPlan`. The current model includes the following SwiftData entities:

| Entity | Purpose | Key Relationships / Fields |
| --- | --- | --- |
| **UserProfile** | Represents the current or collaborating user. | `trips` (owns `Trip`), contact info, `lastSyncedAt`. |
| **Trip** | A travel plan owned by a user. | `segments`, `dayPlanItems`, `routes`, `packingItems`, `documents`, `collaborators`, `activityLogs`. |
| **Segment** | A trip section (flight, train, etc.). | Links to `Trip`, `Route`, origin/destination `Place`, transport variant. |
| **DayPlanItem** | Scheduled activity for a day. | References `Trip`, optional `Segment` and `Place`. |
| **Place** | Persisted point of interest/location. | Optional associated `Trip`, geographic metadata. |
| **Route** | Saved navigation details. | Origin/destination `Place`, associated `Trip`, transport metadata. |
| **PackingItem** | Checklist entry. | Linked `Trip`, category, packed flag. |
| **DocumentAsset** | Stored documents/tickets. | Linked `Trip`, file metadata, data blob with external storage. |
| **Collaborator** | Shared trip participant. | Linked `Trip`, role, invitation status. |
| **ActivityLog** | Audit trail for trip events. | Linked `Trip`, captured action metadata. |

Every entity carries:

- `id` – deterministic UUID (enforced unique attribute).
- `createdAt` / `updatedAt` timestamps.
- `isDeleted` + `deletedAt` tombstone fields (except for debug objects).
- `cloudIdentifier` + `lastSyncedAt` metadata used by the sync coordinator.

## Repositories & Sync Coordination

`SwiftDataRepository<T>` implements the data access layer for each entity:

- Provides `insert`, `update`, `softDelete`, and `hardDelete` methods.
- Emits Combine publishers for change observation.
- Normalises timestamps and ensures tombstones are recorded for deletions.

`TripSyncCoordinator` serialises all state changes, queues them when offline, and pushes compact `ChangeEnvelope` payloads to CloudKit through an abstract `CloudKitSyncAdapter`. The default `NoopCloudKitSyncAdapter` keeps tests hermetic; `CloudKitMirroringAdapter` demonstrates CloudKit APIs.

### Offline behaviour & resiliency

- Local mutations always succeed (changes are written to SwiftData first).
- Cloud pushes failing due to network issues remain in an **outbox** and are retried when the coordinator transitions back to `isOnline == true`.
- Pending operations survive transient errors—`TripSyncCoordinator` replays them until they commit.

### Conflict resolution

Remote changes are merged with **last-writer-wins** semantics based on the entity's `updatedAt` timestamp:

1. Incoming payloads include the server-side `updatedAt`. 
2. If the remote timestamp is newer than the local `updatedAt`, the local record adopts the remote mutation; otherwise it is ignored.
3. Deletions are processed as soft deletes (tombstones) so subsequent sync rounds (and other clients) observe the removal.

`SyncService` is a thin facade around the coordinator, exposing `syncStatus`, `lastSyncDate`, and background scheduling while keeping `AppEnvironment` informed about connectivity and sync progress.

## Migrations

`TripDataMigrationPlan` scaffolds schema evolution. New versions are added as successive `VersionedSchema` cases with forward-only stages. `TripDataPersistenceTests.testMigrationPlanBootstrapsContainer` guards against configuration regressions and ensures the migration pipeline can initialise a container, ready for future staged migrations.

## QA & Preview Harness

`TripDataPreviewHarness` (compiled only in `DEBUG`) seeds a temporary in-memory store with representative trips, places, and itinerary data for manual QA or SwiftUI previews. Call `await TripDataPreviewHarness.makeInMemoryController()` from development tooling to obtain a ready-to-use controller without polluting production data.

## Testing

`TripDataPersistenceTests` exercises the persistence layer:

- CRUD operations with deterministic IDs.
- Offline queue replay when connectivity is restored.
- Last-writer-wins conflict resolution.
- CloudKit pull simulations for deletions/tombstones.
- Migration bootstrapping of the model container.

Together these components deliver an offline-first, CloudKit-synchronised foundation that other features can build upon with confidence.

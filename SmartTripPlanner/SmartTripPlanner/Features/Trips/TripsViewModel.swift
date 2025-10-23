import Foundation
import Combine

@MainActor
final class TripsViewModel: ObservableObject {
    enum DateFilter: String, CaseIterable, Identifiable {
        case upcoming
        case ongoing
        case past
        case all
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .upcoming: return "Upcoming"
            case .ongoing: return "Ongoing"
            case .past: return "Past"
            case .all: return "All"
            }
        }
    }
    
    enum ImportKind {
        case ics
        case pkpass
        case template
    }
    
    enum DraftMode {
        case create
        case edit(UUID)
    }
    
    struct UndoState: Identifiable {
        let id = UUID()
        let trip: Trip
        let message: String
    }
    
    @Published var searchText: String = ""
    @Published var selectedDateFilter: DateFilter = .upcoming
    @Published var selectedModes: Set<TripTravelMode> = []
    @Published private(set) var displayedTrips: [Trip] = []
    @Published var presentedError: TripsRepository.RepositoryError?
    @Published var isPresentingDraft: Bool = false
    @Published private(set) var draftMode: DraftMode = .create
    @Published var draft: TripDraft = TripDraft()
    @Published var deletionTarget: Trip?
    @Published private(set) var undoState: UndoState?
    @Published var activeImportKind: ImportKind?
    @Published var isShowingFileImporter: Bool = false
    @Published private(set) var isSyncing: Bool = false
    @Published var focusTrip: Trip?
    @Published var infoMessage: String?
    
    private var repository: TripsRepository?
    private var syncService: SyncService?
    private weak var appEnvironment: AppEnvironment?
    private var cancellables: Set<AnyCancellable> = []
    private var undoTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.25
    
    func configure(with container: DependencyContainer, appEnvironment: AppEnvironment) {
        guard repository == nil else { return }
        self.repository = container.tripsRepository
        self.syncService = container.syncService
        self.appEnvironment = appEnvironment
        draft = TripDraft()
        updateDisplayedTrips()
        bindRepository()
        bindSearch()
        bindFilters()
        bindAppEnvironment(appEnvironment)
    }
    
    func refresh() {
        updateDisplayedTrips()
    }
    
    func beginCreatingTrip() {
        draft = TripDraft()
        draftMode = .create
        isPresentingDraft = true
    }
    
    func beginEditing(_ trip: Trip) {
        draft = TripDraft(trip: trip)
        draftMode = .edit(trip.id)
        isPresentingDraft = true
    }
    
    func cancelDraft() {
        isPresentingDraft = false
    }
    
    func saveDraft() {
        guard let repository else { return }
        draft.ensureChronology()
        let destinations = draft.makeDestinations()
        guard !draft.trimmedName.isEmpty else {
            presentedError = .validation("Trip name cannot be empty.")
            return
        }
        guard !destinations.isEmpty else {
            presentedError = .validation("Please add at least one destination.")
            return
        }
        let participants = draft.makeParticipants()
        let segments = draft.makeSegments()
        let modeSet = draft.preferredTravelModes.union(segments.compactMap { $0.travelMode })
        guard draft.startDate <= draft.endDate else {
            presentedError = .validation("The start date must be before the end date.")
            return
        }
        do {
            switch draftMode {
            case .create:
                let trip = try repository.createTrip(
                    name: draft.trimmedName,
                    destinations: destinations,
                    startDate: draft.startDate,
                    endDate: draft.endDate,
                    participants: participants,
                    preferredTravelModes: Array(modeSet),
                    segments: segments,
                    notes: draft.normalizedNotes,
                    source: TripSource(kind: draft.sourceKind)
                )
                focusTrip = trip
            case let .edit(identifier):
                guard let existing = repository.trips.first(where: { $0.id == identifier }) else {
                    throw TripsRepository.RepositoryError.missingTrip
                }
                let updated = existing.withUpdatedValues(
                    name: draft.trimmedName,
                    destinations: destinations,
                    startDate: draft.startDate,
                    endDate: draft.endDate,
                    participants: participants,
                    preferredTravelModes: Array(modeSet),
                    segments: segments,
                    notes: draft.normalizedNotes
                )
                try repository.updateTrip(updated)
                focusTrip = updated
            }
            isPresentingDraft = false
            draft = TripDraft()
            updateDisplayedTrips()
        } catch let error as TripsRepository.RepositoryError {
            presentedError = error
        } catch {
            presentedError = .persistenceFailed(error.localizedDescription)
        }
    }
    
    func confirmDeletion(of trip: Trip) {
        deletionTarget = trip
    }
    
    func deleteConfirmedTrip() {
        guard let trip = deletionTarget else { return }
        repository?.deleteTrip(trip)
        deletionTarget = nil
    }
    
    func undoDeletion() {
        repository?.restoreLastDeletedTrip()
        undoTask?.cancel()
        undoState = nil
    }
    
    func presentImport(kind: ImportKind) {
        activeImportKind = kind
        isShowingFileImporter = true
    }
    
    func handleImportedData(_ data: Data, reference: String?, kind override: ImportKind? = nil) {
        guard let repository else { return }
        let effectiveKind = override ?? activeImportKind
        guard let effectiveKind else { return }
        do {
            let trip: Trip
            switch effectiveKind {
            case .ics:
                trip = try repository.importICS(data: data, reference: reference)
            case .pkpass:
                trip = try repository.importPKPass(data: data, reference: reference)
            case .template:
                trip = try repository.importTemplate(data: data, reference: reference)
            }
            focusTrip = trip
            updateDisplayedTrips()
        } catch let error as TripsRepository.RepositoryError {
            presentedError = error
        } catch {
            presentedError = .persistenceFailed(error.localizedDescription)
        }
    }
    
    func importSampleICS() {
        guard let data = SampleImports.sampleICS.data(using: .utf8) else { return }
        handleImportedData(data, reference: "Sample.ics", kind: .ics)
    }
    
    func importSampleTemplate() {
        guard let data = SampleImports.sampleTemplate.data(using: .utf8) else { return }
        handleImportedData(data, reference: "SampleTemplate.json", kind: .template)
    }
    
    private func bindRepository() {
        guard let repository else { return }
        repository.$trips
            .sink { [weak self] _ in
                self?.updateDisplayedTrips()
            }
            .store(in: &cancellables)
        repository.$lastError
            .sink { [weak self] error in
                guard let error else { return }
                self?.presentedError = error
            }
            .store(in: &cancellables)
        repository.$recentlyDeletedTrip
            .sink { [weak self] trip in
                guard let self, let trip else { return }
                self.showUndo(for: trip)
            }
            .store(in: &cancellables)
        repository.$needsSync
            .sink { [weak self] needsSync in
                guard let self else { return }
                self.infoMessage = needsSync ? "Changes will sync when you're back online." : nil
                if needsSync {
                    self.triggerSyncIfPossible()
                }
            }
            .store(in: &cancellables)
    }
    
    private func bindSearch() {
        $searchText
            .removeDuplicates()
            .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateDisplayedTrips() }
            .store(in: &cancellables)
    }
    
    private func bindFilters() {
        $selectedDateFilter
            .sink { [weak self] _ in self?.updateDisplayedTrips() }
            .store(in: &cancellables)
        $selectedModes
            .sink { [weak self] _ in self?.updateDisplayedTrips() }
            .store(in: &cancellables)
    }
    
    private func bindAppEnvironment(_ environment: AppEnvironment) {
        environment.$isOnline
            .sink { [weak self] _ in
                self?.triggerSyncIfPossible()
            }
            .store(in: &cancellables)
    }
    
    private func updateDisplayedTrips() {
        guard let repository else {
            displayedTrips = []
            return
        }
        var trips = repository.trips
        trips = applyDateFilter(on: trips)
        trips = applyModeFilter(on: trips)
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            trips = trips.filter { $0.matches(searchText: trimmed) }
        }
        displayedTrips = trips.sorted(by: { $0.startDate < $1.startDate })
    }
    
    private func applyDateFilter(on trips: [Trip]) -> [Trip] {
        switch selectedDateFilter {
        case .all:
            return trips
        case .upcoming:
            return trips.filter { $0.isUpcoming }
        case .ongoing:
            return trips.filter { $0.isOngoing }
        case .past:
            return trips.filter { $0.isPast }
        }
    }
    
    private func applyModeFilter(on trips: [Trip]) -> [Trip] {
        guard !selectedModes.isEmpty else { return trips }
        return trips.filter { trip in
            !trip.allTravelModes.isDisjoint(with: selectedModes)
        }
    }
    
    private func showUndo(for trip: Trip) {
        undoTask?.cancel()
        undoState = UndoState(trip: trip, message: "\(trip.name) deleted")
        undoTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                if self?.undoState?.trip.id == trip.id {
                    self?.undoState = nil
                }
            }
        }
    }
    
    private func triggerSyncIfPossible() {
        guard let repository, repository.needsSync else { return }
        guard appEnvironment?.isOnline ?? true else { return }
        guard let syncService else { return }
        guard syncTask == nil else { return }
        isSyncing = true
        syncTask = Task { [weak self, weak repository] in
            defer { Task { @MainActor [weak self] in self?.isSyncing = false; self?.syncTask = nil } }
            do {
                try await syncService.syncAllData()
                await MainActor.run {
                    repository?.markSynced()
                }
            } catch {
                await MainActor.run {
                    self?.presentedError = .persistenceFailed(error.localizedDescription)
                }
            }
        }
    }
}

private enum SampleImports {
    static let sampleICS: String = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Sample Corp//Trip Planner//EN
X-WR-CALNAME:Coastal Adventure
BEGIN:VEVENT
UID:sample-event-1
DTSTAMP:20240201T080000Z
DTSTART;TZID=America/Los_Angeles:20240412T060000
DTEND;TZID=America/Los_Angeles:20240412T090000
SUMMARY:Flight to San Francisco
LOCATION:Los Angeles International Airport
DESCRIPTION:Depart on Flight SF123 from LAX to SFO.
END:VEVENT
BEGIN:VEVENT
UID:sample-event-2
DTSTAMP:20240201T080000Z
DTSTART;TZID=America/Los_Angeles:20240412T120000
DTEND;TZID=America/Los_Angeles:20240412T130000
SUMMARY:Hotel Check-in
LOCATION:Seaside Hotel, San Francisco
DESCRIPTION:Check-in at noon.
END:VEVENT
BEGIN:VEVENT
UID:sample-event-3
DTSTAMP:20240201T080000Z
DTSTART;TZID=America/Los_Angeles:20240413T150000
DTEND;TZID=America/Los_Angeles:20240413T180000
SUMMARY:Ferry to Sausalito
LOCATION:Pier 33, San Francisco Bay
DESCRIPTION:Afternoon ferry ride to Sausalito and guided tour.
END:VEVENT
END:VCALENDAR
"""
    
    static let sampleTemplate: String = """
{
    "name": "Mountain Getaway",
    "startDate": "2024-06-01T09:00:00Z",
    "endDate": "2024-06-05T18:00:00Z",
    "destinations": [
        {
            "name": "Denver",
            "arrival": "2024-06-01T09:00:00Z",
            "departure": "2024-06-02T20:00:00Z",
            "notes": "Arrive and acclimate"
        },
        {
            "name": "Rocky Mountain National Park",
            "arrival": "2024-06-03T09:00:00Z",
            "departure": "2024-06-05T18:00:00Z",
            "notes": "Hiking and sightseeing"
        }
    ],
    "participants": [
        { "name": "Jamie Green", "contact": "jamie@example.com" },
        { "name": "Avery Blue", "contact": "avery@example.com" }
    ],
    "travelModes": ["car", "walking"],
    "segments": [
        {
            "title": "Drive to Trailhead",
            "notes": "Scenic drive with stops",
            "location": "Trailhead Parking",
            "startDate": "2024-06-03T08:00:00Z",
            "endDate": "2024-06-03T10:00:00Z",
            "segmentType": "transport",
            "travelMode": "car"
        },
        {
            "title": "Afternoon Hike",
            "notes": "Bear Lake Loop",
            "location": "Rocky Mountain National Park",
            "startDate": "2024-06-03T13:00:00Z",
            "endDate": "2024-06-03T17:00:00Z",
            "segmentType": "activity",
            "travelMode": "walking"
        }
    ],
    "notes": "Bring layered clothing for variable mountain weather.",
    "metadata": { "template": "mountain-getaway-v1" }
}
"""
}

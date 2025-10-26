import Foundation

@MainActor
protocol PlannerRepositoryProviding {
    func loadState() async -> PlannerState
    func save(state: PlannerState, isOnline: Bool) async
    func flushPendingIfNeeded(isOnline: Bool) async
}

@MainActor
final class DayPlannerRepository: PlannerRepositoryProviding {
    private let fileURL: URL
    private let pendingURL: URL
    private let syncService: SyncService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var pendingState: PlannerState?
    
    init(syncService: SyncService) {
        self.syncService = syncService
        let directory = DayPlannerRepository.makeStorageDirectory()
        self.fileURL = directory.appendingPathComponent("planner_state.json")
        self.pendingURL = directory.appendingPathComponent("planner_state_pending.json")
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func loadState() async -> PlannerState {
        if let data = try? Data(contentsOf: fileURL), let state = try? decoder.decode(PlannerState.self, from: data) {
            pendingState = try? loadPendingState()
            return state
        }
        if let pending = try? loadPendingState() {
            pendingState = pending
            return pending
        }
        return .empty
    }
    
    func save(state: PlannerState, isOnline: Bool) async {
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[PlannerRepository] Failed to write planner state: \(error)")
            #endif
        }
        
        if isOnline {
            do {
                try await syncService.syncToCloud(data: state, recordType: "PlannerState", recordID: "current")
                pendingState = nil
                try? FileManager.default.removeItem(at: pendingURL)
            } catch {
                pendingState = state
                persistPendingState(state)
            }
        } else {
            pendingState = state
            persistPendingState(state)
        }
    }
    
    func flushPendingIfNeeded(isOnline: Bool) async {
        guard isOnline else { return }
        if let state = pendingState ?? (try? loadPendingState()) {
            do {
                try await syncService.syncToCloud(data: state, recordType: "PlannerState", recordID: "current")
                pendingState = nil
                try? FileManager.default.removeItem(at: pendingURL)
            } catch {
                pendingState = state
            }
        }
    }
    
    private func persistPendingState(_ state: PlannerState) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: pendingURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[PlannerRepository] Failed to persist pending state: \(error)")
            #endif
        }
    }
    
    private func loadPendingState() throws -> PlannerState {
        let data = try Data(contentsOf: pendingURL)
        return try decoder.decode(PlannerState.self, from: data)
    }
    
    private static func makeStorageDirectory() -> URL {
        let fileManager = FileManager.default
        if let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            ensureDirectory(directory)
            return directory
        }
        let fallback = fileManager.temporaryDirectory
        ensureDirectory(fallback)
        return fallback
    }
    
    private static func ensureDirectory(_ url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

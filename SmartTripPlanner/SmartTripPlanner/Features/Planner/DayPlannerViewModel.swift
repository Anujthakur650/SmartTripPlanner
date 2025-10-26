import Foundation
import SwiftUI

@MainActor
final class DayPlannerViewModel: ObservableObject {
    struct Dependencies {
        let repository: PlannerRepositoryProviding
        let environment: AppEnvironment
        let suggestionProvider: QuickAddSuggestionProviding
        let haptics: HapticFeedbackProviding
    }
    
    @Published private(set) var plans: [DayPlan] = []
    @Published private(set) var activityLog: [ActivityLogEntry] = []
    @Published var selectedDate: Date {
        didSet {
            let normalized = selectedDate.startOfDay(in: calendar)
            if normalized != selectedDate {
                selectedDate = normalized
                return
            }
            refreshSuggestions()
        }
    }
    @Published private(set) var dropPreview: DropPreview?
    @Published private(set) var conflict: DayPlanConflict?
    @Published private(set) var suggestions: [QuickAddSuggestion] = []
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSyncing: Bool = false
    @Published var tripType: TripType = .general {
        didSet {
            refreshSuggestions()
        }
    }
    
    let slotHeight: CGFloat = 40
    let slotIntervalMinutes = 15
    private let calendar: Calendar
    private var dependencies: Dependencies?
    private var shouldLoadOnConfigure = true
    private var undoStack: [PlannerState] = []
    private var redoStack: [PlannerState] = []
    private let undoLimit = 50
    private let activityLimit = 100
    private let payloadEncoder = JSONEncoder()
    private let payloadDecoder = JSONDecoder()
    
    private lazy var logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private lazy var logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(selectedDate: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        self.selectedDate = selectedDate.startOfDay(in: calendar)
    }
    
    convenience init(
        dependencies: Dependencies,
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        initialState: PlannerState? = nil
    ) {
        self.init(selectedDate: selectedDate, calendar: calendar)
        self.dependencies = dependencies
        if let initialState {
            applyState(initialState, recordHistory: false)
            shouldLoadOnConfigure = false
        }
    }
    
    func configureIfNeeded(_ dependencies: Dependencies) {
        if let existing = self.dependencies {
            Task {
                await existing.repository.flushPendingIfNeeded(isOnline: existing.environment.isOnline)
            }
            return
        }
        self.dependencies = dependencies
        if shouldLoadOnConfigure {
            Task { await loadState() }
        } else {
            refreshSuggestions()
        }
    }
    
    func visibleDays(around date: Date, range: Int = 2) -> [Date] {
        let normalized = date.startOfDay(in: calendar)
        return ( -range...range ).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: normalized)
        }
    }
    
    func dayPlan(for date: Date) -> DayPlan {
        let normalized = date.startOfDay(in: calendar)
        if let plan = plans.first(where: { $0.date == normalized }) {
            return plan
        }
        return DayPlan(date: normalized, items: [])
    }
    
    func items(for date: Date) -> [DayPlanItem] {
        dayPlan(for: date).items
    }
    
    func dropStartDate(for locationY: CGFloat, on day: Date, slotHeight: CGFloat) -> Date {
        let slots = max(0, Int(locationY / max(slotHeight, 1)))
        let boundedSlots = max(0, min(95, slots))
        let minutes = boundedSlots * slotIntervalMinutes
        let dayStart = day.startOfDay(in: calendar)
        let date = calendar.date(byAdding: .minute, value: minutes, to: dayStart) ?? dayStart
        return date.snapped(to: TimeInterval(slotIntervalMinutes * 60), calendar: calendar)
    }
    
    func dragPayload(for itemID: UUID, on day: Date) -> String? {
        let payload = DayPlanDragPayload(itemID: itemID, sourceDayIdentifier: day.startOfDay(in: calendar).isoDayIdentifier)
        guard let data = try? payloadEncoder.encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func decodeDragPayload(from string: String) -> DayPlanDragPayload? {
        guard let data = string.data(using: .utf8) else { return nil }
        return decodeDragPayload(from: data)
    }
    
    func decodeDragPayload(from data: Data) -> DayPlanDragPayload? {
        try? payloadDecoder.decode(DayPlanDragPayload.self, from: data)
    }
    
    @discardableResult
    func moveItem(
        with id: UUID,
        from sourceDayIdentifier: String,
        to targetDay: Date,
        proposedStartDate: Date
    ) -> Bool {
        guard let dependencies else { return false }
        guard let sourceDay = Date(isoDayIdentifier: sourceDayIdentifier, calendar: calendar) else { return false }
        let normalizedSource = sourceDay.startOfDay(in: calendar)
        let normalizedTarget = targetDay.startOfDay(in: calendar)
        guard let originalItem = item(with: id, on: normalizedSource) else { return false }
        let snappedStart = normalizedStartDate(proposedStartDate, on: normalizedTarget)
        let newEnd = snappedStart.addingTimeInterval(originalItem.duration)
        if let conflictItem = conflictingItem(
            movingItemID: id,
            originDay: normalizedSource,
            targetDay: normalizedTarget,
            proposedStart: snappedStart,
            proposedEnd: newEnd
        ) {
            conflict = DayPlanConflict(type: .overlap, message: "Overlaps with \(conflictItem.title)")
            dependencies.haptics.error()
            return false
        }
        
        pushUndoSnapshot()
        dropPreview = nil
        conflict = nil
        guard let removed = extractItem(with: id, from: normalizedSource) else {
            undoStack.removeLast()
            updateHistoryAvailability()
            return false
        }
        var updatedItem = removed
        updatedItem.startDate = snappedStart
        insert(updatedItem, into: normalizedTarget)
        log("Moved \(updatedItem.title) to \(logDateFormatter.string(from: normalizedTarget)) at \(logTimeFormatter.string(from: snappedStart))")
        dependencies.haptics.success()
        refreshSuggestions()
        persistChanges()
        return true
    }
    
    func removeItem(_ id: UUID, from day: Date) {
        guard let dependencies else { return }
        let normalized = day.startOfDay(in: calendar)
        guard let item = item(with: id, on: normalized) else { return }
        pushUndoSnapshot()
        _ = extractItem(with: id, from: normalized)
        log("Removed \(item.title) from \(logDateFormatter.string(from: normalized))")
        dependencies.haptics.warning()
        refreshSuggestions()
        persistChanges()
    }
    
    func quickAddSuggestion(_ suggestion: QuickAddSuggestion, on day: Date) {
        let normalized = day.startOfDay(in: calendar)
        let start = nextAvailableStart(on: normalized, duration: suggestion.duration)
        let item = DayPlanItem(
            title: suggestion.title,
            startDate: start,
            duration: suggestion.duration,
            location: suggestion.location,
            notes: suggestion.notes,
            tags: suggestion.tags
        )
        addItem(item, to: normalized, logPrefix: "Added suggestion")
    }
    
    func addItem(_ item: DayPlanItem, to day: Date, logPrefix: String = "Added") {
        guard let dependencies else { return }
        let normalized = day.startOfDay(in: calendar)
        let snappedStart = item.startDate.snapped(to: TimeInterval(slotIntervalMinutes * 60), calendar: calendar)
        let newItem = DayPlanItem(
            id: item.id,
            title: item.title,
            startDate: normalizedStartDate(snappedStart, on: normalized),
            duration: item.duration,
            location: item.location,
            notes: item.notes,
            tags: item.tags
        )
        if let conflictItem = conflictingItem(
            movingItemID: newItem.id,
            originDay: normalized,
            targetDay: normalized,
            proposedStart: newItem.startDate,
            proposedEnd: newItem.endDate
        ) {
            conflict = DayPlanConflict(type: .overlap, message: "Overlaps with \(conflictItem.title)")
            dependencies.haptics.error()
            return
        }
        pushUndoSnapshot()
        insert(newItem, into: normalized)
        log("\(logPrefix) \(newItem.title) at \(logTimeFormatter.string(from: newItem.startDate))")
        dependencies.haptics.success()
        dependencies.suggestionProvider.recordUsage(newItem)
        refreshSuggestions()
        persistChanges()
    }
    
    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentState)
        applyState(snapshot, recordHistory: false)
        dependencies?.haptics.warning()
        updateHistoryAvailability()
        persistChanges()
    }
    
    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentState)
        applyState(snapshot, recordHistory: false)
        dependencies?.haptics.success()
        updateHistoryAvailability()
        persistChanges()
    }
    
    func updateDropPreview(day: Date, locationY: CGFloat) {
        let normalized = day.startOfDay(in: calendar)
        let start = dropStartDate(for: locationY, on: normalized, slotHeight: slotHeight)
        dropPreview = DropPreview(dayIdentifier: normalized.isoDayIdentifier, startDate: start)
    }
    
    func clearDropPreview() {
        dropPreview = nil
    }
    
    // MARK: - Private
    
    private func loadState() async {
        guard let dependencies else { return }
        isLoading = true
        let state = await dependencies.repository.loadState()
        applyState(state, recordHistory: false)
        updateHistoryAvailability()
        refreshSuggestions()
        isLoading = false
        await dependencies.repository.flushPendingIfNeeded(isOnline: dependencies.environment.isOnline)
    }
    
    private func applyState(_ state: PlannerState, recordHistory: Bool) {
        plans = state.days.sorted(by: { $0.date < $1.date })
        activityLog = state.activityLog.sorted(by: { $0.timestamp > $1.timestamp }).prefix(activityLimit).map { $0 }
        if recordHistory {
            undoStack.append(state)
        }
        dropPreview = nil
        conflict = nil
    }
    
    private var currentState: PlannerState {
        PlannerState(days: plans, activityLog: activityLog)
    }
    
    private func pushUndoSnapshot() {
        undoStack.append(currentState)
        if undoStack.count > undoLimit {
            undoStack.removeFirst(undoStack.count - undoLimit)
        }
        redoStack.removeAll()
        updateHistoryAvailability()
    }
    
    private func updateHistoryAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    private func persistChanges() {
        guard let dependencies else { return }
        let state = currentState
        let isOnline = dependencies.environment.isOnline
        isSyncing = true
        Task {
            await dependencies.repository.save(state: state, isOnline: isOnline)
            await dependencies.repository.flushPendingIfNeeded(isOnline: isOnline)
            await MainActor.run {
                self.isSyncing = false
            }
        }
    }
    
    private func log(_ message: String) {
        activityLog.insert(ActivityLogEntry(description: message), at: 0)
        if activityLog.count > activityLimit {
            activityLog.removeLast(activityLog.count - activityLimit)
        }
    }
    
    private func refreshSuggestions() {
        guard let dependencies else { return }
        let recent = items(for: selectedDate)
        suggestions = dependencies.suggestionProvider.suggestions(for: tripType, recentItems: recent)
    }
    
    private func item(with id: UUID, on day: Date) -> DayPlanItem? {
        let normalized = day.startOfDay(in: calendar)
        return plans.first(where: { $0.date == normalized })?.items.first(where: { $0.id == id })
    }
    
    private func extractItem(with id: UUID, from day: Date) -> DayPlanItem? {
        let normalized = day.startOfDay(in: calendar)
        guard let index = plans.firstIndex(where: { $0.date == normalized }) else { return nil }
        var plan = plans[index]
        guard let item = plan.removeItem(withID: id) else { return nil }
        if plan.items.isEmpty {
            plans.remove(at: index)
        } else {
            plans[index] = plan
        }
        return item
    }
    
    private func insert(_ item: DayPlanItem, into day: Date) {
        let normalized = day.startOfDay(in: calendar)
        if let index = plans.firstIndex(where: { $0.date == normalized }) {
            var plan = plans[index]
            plan.insert(item)
            plans[index] = plan
        } else {
            var plan = DayPlan(date: normalized)
            plan.insert(item)
            plans.append(plan)
            plans.sort(by: { $0.date < $1.date })
        }
    }
    
    private func conflictingItem(
        movingItemID: UUID,
        originDay: Date,
        targetDay: Date,
        proposedStart: Date,
        proposedEnd: Date
    ) -> DayPlanItem? {
        let normalizedTarget = targetDay.startOfDay(in: calendar)
        let items = plans.first(where: { $0.date == normalizedTarget })?.items ?? []
        for item in items {
            if normalizedTarget == originDay.startOfDay(in: calendar) && item.id == movingItemID {
                continue
            }
            if proposedStart < item.endDate && proposedEnd > item.startDate {
                return item
            }
        }
        return nil
    }
    
    private func normalizedStartDate(_ proposed: Date, on day: Date) -> Date {
        let components = calendar.dateComponents([.hour, .minute, .second], from: proposed)
        let combined = calendar.combine(day: day, hour: components.hour ?? 0, minute: components.minute ?? 0)
        return combined.snapped(to: TimeInterval(slotIntervalMinutes * 60), calendar: calendar)
    }
    
    private func nextAvailableStart(on day: Date, duration: TimeInterval) -> Date {
        let planItems = items(for: day)
        var candidate = calendar.combine(day: day, hour: 8, minute: 0)
        let snappedDuration = max(duration, TimeInterval(slotIntervalMinutes * 60))
        for item in planItems.sorted(by: { $0.startDate < $1.startDate }) {
            if candidate.addingTimeInterval(snappedDuration) <= item.startDate {
                break
            }
            candidate = item.endDate.snapped(to: TimeInterval(slotIntervalMinutes * 60), calendar: calendar)
        }
        return candidate
    }
}

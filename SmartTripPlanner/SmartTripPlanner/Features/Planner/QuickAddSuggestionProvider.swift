import Foundation

protocol QuickAddSuggestionProviding {
    func suggestions(for tripType: TripType, recentItems: [DayPlanItem]) -> [QuickAddSuggestion]
    func recordUsage(_ item: DayPlanItem)
}

final class QuickAddSuggestionProvider: QuickAddSuggestionProviding {
    private var history: [DayPlanItem] = []
    private let maximumHistoryCount = 20
    private let baseSuggestions: [TripType: [QuickAddSuggestion]]
    
    init() {
        self.baseSuggestions = QuickAddSuggestionProvider.makeBaseSuggestions()
    }
    
    func suggestions(for tripType: TripType, recentItems: [DayPlanItem]) -> [QuickAddSuggestion] {
        var unique: [String: QuickAddSuggestion] = [:]
        let defaults = baseSuggestions[tripType] ?? []
        defaults.forEach { unique[$0.title.lowercased()] = $0 }
        
        let recent = Array((recentItems + history).suffix(5))
        for item in recent.reversed() {
            let key = item.title.lowercased()
            if unique[key] == nil {
                unique[key] = QuickAddSuggestion(
                    title: item.title,
                    duration: item.duration,
                    location: item.location,
                    notes: item.notes,
                    tags: item.tags
                )
            }
        }
        
        return Array(unique.values).sorted { $0.title < $1.title }.prefix(8).map { $0 }
    }
    
    func recordUsage(_ item: DayPlanItem) {
        history.append(item)
        if history.count > maximumHistoryCount {
            history.removeFirst(history.count - maximumHistoryCount)
        }
    }
    
    private static func makeBaseSuggestions() -> [TripType: [QuickAddSuggestion]] {
        func suggestions(_ values: [(String, TimeInterval, [String])]) -> [QuickAddSuggestion] {
            values.map { QuickAddSuggestion(title: $0.0, duration: $0.1, tags: $0.2) }
        }
        
        return [
            .general: suggestions([
                ("Breakfast", 45 * 60, ["food"]),
                ("City Tour", 2 * 60 * 60, ["activity"]),
                ("Lunch", 60 * 60, ["food"]),
                ("Museum Visit", 90 * 60, ["culture"]),
                ("Dinner", 90 * 60, ["food"])
            ]),
            .adventure: suggestions([
                ("Hiking", 3 * 60 * 60, ["outdoors", "fitness"]),
                ("Climbing", 2 * 60 * 60, ["outdoors"]),
                ("Kayaking", 120 * 60, ["water"])
            ]),
            .business: suggestions([
                ("Breakfast Meeting", 60 * 60, ["work"]),
                ("Client Presentation", 90 * 60, ["work"]),
                ("Networking Event", 2 * 60 * 60, ["network"])
            ]),
            .family: suggestions([
                ("Zoo Visit", 3 * 60 * 60, ["family"]),
                ("Playground", 90 * 60, ["family"]),
                ("Family Dinner", 2 * 60 * 60, ["family", "food"])
            ]),
            .relaxation: suggestions([
                ("Spa Session", 2 * 60 * 60, ["relax"]),
                ("Beach Time", 3 * 60 * 60, ["relax"]),
                ("Yoga", 75 * 60, ["wellness"])
            ])
        ]
    }
}

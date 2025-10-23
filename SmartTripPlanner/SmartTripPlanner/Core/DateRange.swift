import Foundation

struct DateRange: Codable, Equatable {
    var start: Date
    var end: Date
    
    init(start: Date, end: Date) {
        if start <= end {
            self.start = start
            self.end = end
        } else {
            self.start = end
            self.end = start
        }
    }
    
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
    
    var numberOfDays: Int {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: start)
        let startOfEnd = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startOfStart, to: startOfEnd)
        return max((components.day ?? 0) + 1, 1)
    }
    
    func contains(_ date: Date, in calendar: Calendar = .current) -> Bool {
        let normalized = calendar.startOfDay(for: date)
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        return normalized >= normalizedStart && normalized <= normalizedEnd
    }
    
    func clamped(to other: DateRange) -> DateRange {
        let newStart = max(start, other.start)
        let newEnd = min(end, other.end)
        return DateRange(start: newStart, end: newEnd)
    }
    
    func expandingBy(days: Int, calendar: Calendar = .current) -> DateRange {
        guard let newStart = calendar.date(byAdding: .day, value: -days, to: start),
              let newEnd = calendar.date(byAdding: .day, value: days, to: end) else {
            return self
        }
        return DateRange(start: newStart, end: newEnd)
    }
}

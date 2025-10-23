import Foundation

extension Date {
    func startOfDay(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
    
    func snapped(to interval: TimeInterval, calendar: Calendar = .current) -> Date {
        let seconds = timeIntervalSinceReferenceDate
        let snapInterval = interval
        let remainder = seconds.truncatingRemainder(dividingBy: snapInterval)
        let snappedSeconds: TimeInterval
        if remainder >= snapInterval / 2 {
            snappedSeconds = seconds + (snapInterval - remainder)
        } else {
            snappedSeconds = seconds - remainder
        }
        return Date(timeIntervalSinceReferenceDate: snappedSeconds)
    }
    
    func adding(minutes: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: self) ?? self
    }
    
    var isoDayIdentifier: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let normalized = startOfDay(in: formatter.calendar)
        return formatter.string(from: normalized)
    }
    
    init?(isoDayIdentifier: String, calendar: Calendar = .current) {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDayIdentifier) else {
            return nil
        }
        self = calendar.startOfDay(for: date)
    }
}

extension Calendar {
    func combine(day: Date, with time: Date) -> Date {
        let dayComponents = dateComponents([.year, .month, .day], from: day)
        let timeComponents = dateComponents([.hour, .minute, .second], from: time)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return self.date(from: components) ?? day
    }
    
    func combine(day: Date, hour: Int, minute: Int) -> Date {
        var components = dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return date(from: components) ?? day
    }
}

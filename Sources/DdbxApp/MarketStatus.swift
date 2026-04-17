import Foundation

enum MarketStatus: Equatable {
    case preOpen(opensIn: TimeInterval)
    case open
    case closed(reopensTomorrow: Bool)
}

enum LSE {
    static let timeZone = TimeZone(identifier: "Europe/London")!
    static let openMinute = 8 * 60
    static let closeMinute = 16 * 60 + 30

    static func status(at now: Date = Date()) -> MarketStatus {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let weekday = components.weekday ?? 1
        let isWeekday = (2...6).contains(weekday)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if isWeekday && minutes >= openMinute && minutes < closeMinute {
            return .open
        }

        if isWeekday && minutes < openMinute {
            let openDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
            return .preOpen(opensIn: openDate.timeIntervalSince(now))
        }

        return .closed(reopensTomorrow: nextDayIsWeekday(after: now, calendar: calendar))
    }

    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int((seconds / 60.0).rounded(.up)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private static func nextDayIsWeekday(after date: Date, calendar: Calendar) -> Bool {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
        let weekday = calendar.component(.weekday, from: tomorrow)
        return (2...6).contains(weekday)
    }
}

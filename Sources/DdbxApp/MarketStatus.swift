import Foundation

enum NextOpen: Equatable {
    case tomorrow
    case named(String)
}

enum ClosureReason: Equatable {
    case weekend
    case afterHours
    case holiday(name: String)
}

enum MarketStatus: Equatable {
    case preOpen(opensIn: TimeInterval, earlyCloseToday: String?)
    case open(earlyCloseToday: String?)
    case closed(reopens: NextOpen, reason: ClosureReason)
}

enum LSE {
    static let timeZone = TimeZone(identifier: "Europe/London")!
    static let openMinute = 8 * 60
    static let closeMinute = 16 * 60 + 30
    static let halfDayCloseMinute = 12 * 60 + 30

    static func status(at now: Date = Date(), holidays: [Date: String] = [:]) -> MarketStatus {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let weekday = components.weekday ?? 1
        let isWeekday = (2...6).contains(weekday)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let dayKey = calendar.startOfDay(for: now)

        if let holidayName = holidays[dayKey] {
            return .closed(
                reopens: nextOpen(after: now, calendar: calendar, holidays: holidays),
                reason: .holiday(name: holidayName)
            )
        }

        if !isWeekday {
            return .closed(
                reopens: nextOpen(after: now, calendar: calendar, holidays: holidays),
                reason: .weekend
            )
        }

        let month = components.month ?? 0
        let day = components.day ?? 0
        let earlyCloseName: String? = {
            guard month == 12 else { return nil }
            if day == 24 { return "Christmas Eve" }
            if day == 31 { return "New Year’s Eve" }
            return nil
        }()
        let todaysClose = earlyCloseName != nil ? halfDayCloseMinute : closeMinute

        if minutes < openMinute {
            let openDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
            return .preOpen(opensIn: openDate.timeIntervalSince(now), earlyCloseToday: earlyCloseName)
        }

        if minutes < todaysClose {
            return .open(earlyCloseToday: earlyCloseName)
        }

        return .closed(
            reopens: nextOpen(after: now, calendar: calendar, holidays: holidays),
            reason: .afterHours
        )
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

    static func formatCloseTime(minuteOfDay: Int) -> String {
        let h = minuteOfDay / 60
        let m = minuteOfDay % 60
        return String(format: "%d:%02d", h, m)
    }

    private static func nextOpen(after now: Date, calendar: Calendar, holidays: [Date: String]) -> NextOpen {
        let today = calendar.startOfDay(for: now)
        var candidate = today
        for _ in 0..<14 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { break }
            candidate = next
            let weekday = calendar.component(.weekday, from: candidate)
            let isWeekday = (2...6).contains(weekday)
            guard isWeekday, holidays[candidate] == nil else { continue }
            let dayDiff = calendar.dateComponents([.day], from: today, to: candidate).day ?? 0
            if dayDiff == 1 {
                return .tomorrow
            }
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            f.timeZone = timeZone
            f.locale = Locale(identifier: "en_GB")
            return .named(f.string(from: candidate))
        }
        return .tomorrow
    }
}

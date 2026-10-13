import Foundation

/// When a routine next applies, in words, for a day it does not apply today.
enum RoutineSchedule {
    /// Days until the routine next applies, 1 meaning tomorrow. `weekdays` use 0 = Sunday; empty means every day, which is never "later".
    static func daysUntilNext(weekdays: [Int], today: Int) -> Int? {
        guard !weekdays.isEmpty else { return nil }
        return (1...7).first { weekdays.contains((today + $0) % 7) }
    }

    /// "Tomorrow", or the weekday's name ("Sunday").
    static func nextLabel(weekdays: [Int], today: Int, names: [String]) -> String? {
        guard let days = daysUntilNext(weekdays: weekdays, today: today) else { return nil }
        return days == 1 ? "Tomorrow" : names[(today + days) % 7]
    }

    /// The weekday (0 = Sunday) it is right now in the routine's own time zone.
    static func weekdayNow(in zone: String, now: Date = Date()) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .current
        return calendar.component(.weekday, from: now) - 1
    }

    /// The next nudge today, from "HH:mm" cues read in the routine's own zone, or nil when none is left. The date returned is an instant.
    static func nextCue(cues: [String], zone: String, now: Date = Date()) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return cues.compactMap { cue -> Date? in
            let hm = cue.split(separator: ":").compactMap { Int($0) }
            guard hm.count == 2 else { return nil }
            return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: hm[0], minute: hm[1]))
        }.filter { $0 > now }.min()
    }
}

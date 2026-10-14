import Foundation

struct DayEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var minutes: Int
}

/// A routine's nudge time and its shared daily count. The engine does not record completion per nudge.
struct RoutineOccurrence: Identifiable {
    let status: Wire.RoutineStatus
    let at: Date
    var id: String { "r:" + status.id + "@" + String(Int(at.timeIntervalSince1970)) }
}

enum TodayLayout {
    static func untimedTasks(_ items: [Wire.PlanItem]) -> [Wire.PlanItem] {
        items.filter { $0.startAt == nil && $0.kind != "event" && $0.deletedAt == nil }
    }

    static func untimedReminders(_ items: [Wire.Reminder]) -> [Wire.Reminder] {
        items.filter { $0.dueAt == nil && $0.snoozedUntil == nil && $0.deletedAt == nil }
    }

    static func untimedRoutines(_ items: [Wire.RoutineStatus], now: Date = Date()) -> [Wire.RoutineStatus] {
        items.filter { $0.scheduled && cueTimes($0, now: now).isEmpty }
    }

    static func routineOccurrences(_ items: [Wire.RoutineStatus], now: Date = Date()) -> [RoutineOccurrence] {
        let occurrences: [RoutineOccurrence] = items.filter(\.scheduled).flatMap { status -> [RoutineOccurrence] in
            cueTimes(status, now: now).map { RoutineOccurrence(status: status, at: $0) }
        }
        return occurrences.sorted { a, b in a.at == b.at ? a.id < b.id : a.at < b.at }
    }

    private static func cueTimes(_ status: Wire.RoutineStatus, now: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: status.routine.timeZone) ?? .current
        let times = status.routine.cues.compactMap { cue -> Date? in
            let parts = cue.split(separator: ":")
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now,
                                 matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first)
        }
        return Array(Set(times)).sorted()
    }
}

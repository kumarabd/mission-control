import Foundation

struct DayEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var minutes: Int
}

enum TodayLayout {
    static func untimedTasks(_ items: [Wire.PlanItem]) -> [Wire.PlanItem] {
        items.filter { $0.startAt == nil && $0.kind != "event" && $0.deletedAt == nil }
    }

    static func untimedReminders(_ items: [Wire.Reminder]) -> [Wire.Reminder] {
        items.filter { $0.dueAt == nil && $0.snoozedUntil == nil && $0.deletedAt == nil }
    }

    /// A routine due today is untimed work. Its nudges are the assistant's cue to consider prompting, not times the person
    /// is due at (project-hub ADR 0007), so they never put the routine on the Schedule rail; they are shown and edited on
    /// the routine's own screen.
    static func untimedRoutines(_ items: [Wire.RoutineStatus]) -> [Wire.RoutineStatus] {
        items.filter(\.scheduled)
    }
}

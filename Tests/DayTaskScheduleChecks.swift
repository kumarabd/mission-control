import Foundation
import SwiftData

@main
struct DayTaskScheduleChecks {
    @MainActor
    static func main() throws {
        let container = try ModelContainer(for: MissionTask.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        defer { withExtendedLifetime(container) {} }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
        let now = date("2026-09-08T10:30:30-07:00")
        let flexible = MissionTask(title: "Flexible", createdAt: date("2026-08-01T12:00:00-07:00"))
        let earlier = MissionTask(title: "Earlier", scheduledAt: date("2026-09-08T09:00:00-07:00"))
        let current = MissionTask(title: "Current", scheduledAt: date("2026-09-08T10:30:00-07:00"))
        let next = MissionTask(title: "Next", scheduledAt: date("2026-09-08T11:00:00-07:00"))
        let sameTime = MissionTask(title: "Same time", scheduledAt: next.scheduledAt)
        let tomorrow = MissionTask(title: "Tomorrow", scheduledAt: date("2026-09-09T00:00:00-07:00"))
        let done = MissionTask(title: "Done", isCompleted: true, scheduledAt: earlier.scheduledAt)
        let tasks = [tomorrow, flexible, next, earlier, current, sameTime, done]
        let schedule = DayTaskSchedule(tasks: tasks, now: now, calendar: calendar)
        precondition(schedule.earlier.map(\.title) == ["Earlier"])
        precondition(schedule.remainingToday.map(\.title) == ["Current", "Next", "Same time"])
        precondition(schedule.later.map(\.title) == ["Tomorrow"])
        precondition(schedule.anytime.map(\.title) == ["Flexible"], "Creation date must not become a deadline")
        precondition(current.scheduledAt! >= schedule.minuteStart && current.scheduledAt! < schedule.minuteEnd)

        let advanced = DayTaskSchedule(tasks: tasks, now: date("2026-09-08T10:31:00-07:00"), calendar: calendar)
        precondition(advanced.earlier.map(\.title) == ["Earlier", "Current"])
        next.isCompleted = true
        precondition(!DayTaskSchedule(tasks: tasks, now: now, calendar: calendar).remainingToday.contains { $0 === next })
        next.isCompleted = false
        next.scheduledAt = nil
        precondition(DayTaskSchedule(tasks: tasks, now: now, calendar: calendar).anytime.contains { $0 === next })
        let nextDay = DayTaskSchedule(tasks: tasks, now: tomorrow.scheduledAt!, calendar: calendar)
        precondition(nextDay.remainingToday.map(\.title) == ["Tomorrow"])
        precondition(nextDay.later.isEmpty)
        precondition(nextDay.anytime.contains { $0 === flexible })

        // Both the 23-hour and 25-hour local days end at midnight, not after 86,400 seconds.
        for day in ["2026-03-08T12:00:00-07:00", "2026-11-01T12:00:00-08:00"] {
            let noon = date(day)
            let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: noon))!
            let lastMinute = MissionTask(title: "Tonight", scheduledAt: midnight.addingTimeInterval(-60))
            let boundary = MissionTask(title: "Next day", scheduledAt: midnight)
            let grouped = DayTaskSchedule(tasks: [boundary, lastMinute], now: noon, calendar: calendar)
            precondition(grouped.remainingToday.map(\.title) == ["Tonight"])
            precondition(grouped.later.map(\.title) == ["Next day"])
        }
        let many = (0..<100).map { MissionTask(title: "Task \($0)") }
        precondition(DayTaskSchedule(tasks: many, now: now, calendar: calendar).anytime.count == 100)
        let empty = DayTaskSchedule(tasks: [], now: now, calendar: calendar)
        precondition(empty.earlier.isEmpty && empty.remainingToday.isEmpty && empty.later.isEmpty && empty.anytime.isEmpty)
        print("PASS: chronological order, equal times, current minute, midnight, DST, completion, removing time, and uncapped flexible tasks")
    }
}

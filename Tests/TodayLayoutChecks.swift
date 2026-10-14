import Foundation

@main
struct TodayLayoutChecks {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        func read<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            try Wire.decoder.decode(T.self, from: Data(contentsOf: directory.appendingPathComponent(name + ".json")))
        }
        var task = try read("plan_item", as: Wire.PlanItem.self)
        task.startAt = nil
        var checkin = task; checkin.id = "checkin"; checkin.kind = "checkin"; checkin.startAt = Date()
        var event = task; event.id = "event"; event.kind = "event"
        var removed = task; removed.id = "removed"; removed.deletedAt = Date()
        precondition(TodayLayout.untimedTasks([task, checkin, event, removed]).map(\.id) == [task.id])
        var reminder = try read("reminder_undated", as: Wire.Reminder.self)
        reminder.dueAt = nil; reminder.snoozedUntil = nil
        var timed = reminder; timed.id = "timed"; timed.dueAt = Date()
        var snoozed = reminder; snoozed.id = "snoozed"; snoozed.snoozedUntil = Date()
        precondition(TodayLayout.untimedReminders([reminder, timed, snoozed]).map(\.id) == [reminder.id])
        let now = ISO8601DateFormatter().date(from: "2026-10-13T19:00:00Z")!
        var routine = try read("routine_status", as: Wire.RoutineStatus.self)
        routine.scheduled = true; routine.routine.timeZone = "America/Los_Angeles"
        routine.routine.cues = ["09:00", "13:00", "17:00", "09:00", "bad", "25:00", "12:99"]
        let occurrences = TodayLayout.routineOccurrences([routine], now: now)
        precondition(occurrences.count == 3)
        precondition(Set(occurrences.map(\.id)).count == 3)
        precondition(occurrences[0].at == ISO8601DateFormatter().date(from: "2026-10-13T16:00:00Z"))
        precondition(occurrences[0].at < now, "Past cues must stay in the schedule")
        precondition(occurrences.allSatisfy { $0.status.count == routine.count }, "Do not assign logs to particular nudges")
        precondition(TodayLayout.untimedRoutines([routine], now: now).isEmpty)
        var untimed = routine; untimed.routine.id = "untimed"; untimed.routine.cues = []
        var offDay = untimed; offDay.routine.id = "offday"; offDay.scheduled = false
        precondition(TodayLayout.untimedRoutines([routine, untimed, offDay], now: now).map(\.id) == [untimed.id])
        precondition(TodayLayout.routineOccurrences([offDay], now: now).isEmpty)
        routine.routine.cues = ["02:30", "03:30"]
        let spring = ISO8601DateFormatter().date(from: "2026-03-08T20:00:00Z")!
        let springTimes = TodayLayout.routineOccurrences([routine], now: spring)
        var zone = Calendar(identifier: .gregorian); zone.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        precondition(Set(springTimes.map(\.at)).count == springTimes.count, "DST adjustment must not duplicate the same instant")
        precondition(springTimes.allSatisfy { zone.isDate($0.at, inSameDayAs: spring) }, "DST must not move today's cue to a different day")
        routine.routine.cues = ["01:30"]
        let fall = ISO8601DateFormatter().date(from: "2026-11-01T20:00:00Z")!
        precondition(TodayLayout.routineOccurrences([routine], now: fall).count == 1, "A repeated clock hour is one nudge")
        print("TodayLayoutChecks passed")
    }
}

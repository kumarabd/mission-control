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
        var routine = try read("routine_status", as: Wire.RoutineStatus.self)
        routine.scheduled = true
        routine.routine.cues = ["09:00", "13:00", "17:00"]
        precondition(TodayLayout.untimedRoutines([routine]).map(\.id) == [routine.id],
                     "A routine is untimed work: its nudge times do not put it on the schedule")
        var offDay = routine; offDay.routine.id = "offday"; offDay.scheduled = false
        precondition(TodayLayout.untimedRoutines([routine, offDay]).map(\.id) == [routine.id], "only on a day it applies")
        print("TodayLayoutChecks passed")
    }
}

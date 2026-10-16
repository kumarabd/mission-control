import Foundation

// How long a finished reminder stays listed, how a repeat is described, and how the day is counted for the ring. Compiled with
// the wire types and DayProgress:
//   xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Domain/DayProgress.swift Tests/ReminderStateChecks.swift -o /private/tmp/reminder-state-checks && /private/tmp/reminder-state-checks
@main
struct ReminderStateChecks {
    static let now = Date(timeIntervalSince1970: 1_791_900_000)
    static func hours(_ h: Double) -> Date { now.addingTimeInterval(h * 3600) }

    static func reminder(state: String = "pending", due: Date? = nil, rule: Wire.Recurrence? = nil, completed: Date? = nil, updated: Date = now) -> Wire.Reminder {
        Wire.Reminder(id: "r", title: "Drink water", notes: "", dueAt: due, snoozedUntil: nil, timeZone: "UTC", recurrence: rule, source: "user",
                      sessionId: nil, turnSeq: nil, link: nil, state: state, completedAt: completed, lastCompletedAt: nil,
                      version: 1, deletedAt: nil, createdAt: now, updatedAt: updated)
    }

    static func routine(_ count: Int, of target: Int, scheduled: Bool = true) -> Wire.RoutineStatus {
        let r = Wire.Routine(id: "x\(count)\(target)", title: "R", minutes: 5, shortTitle: "s", shortMinutes: 1, weekdays: [], targetPerDay: target, nudges: [],
                             timeZone: "UTC", version: 1, deletedAt: nil, createdAt: now, updatedAt: now)
        return Wire.RoutineStatus(routine: r, scheduled: scheduled, target: target, count: count, done: count >= target, variant: nil, streak: 0, daysSinceLast: nil, gap: false, hint: "")
    }

    static func cue(_ state: String, _ id: String) -> Wire.AgendaItem {
        Wire.AgendaItem(reminder: reminder(due: now).with(id: id), at: now, state: state, overdue: false)
    }

    static func main() {
        // A finished reminder stays on the list for a day; an open one always does.
        precondition(reminder(due: hours(-5)).isShown(now: now), "open ones always show")
        precondition(reminder(state: "done", completed: hours(-1)).isShown(now: now), "finished an hour ago")
        precondition(!reminder(state: "done", completed: hours(-30)).isShown(now: now), "finished yesterday")

        precondition(reminder(rule: Wire.Recurrence(freq: "daily", interval: 1, weekdays: nil)).repeatDescription == "Every day")
        precondition(reminder(rule: Wire.Recurrence(freq: "weekly", interval: 2, weekdays: nil)).repeatDescription == "Every 2 weeks")
        precondition(reminder().repeatDescription == nil)

        // A cue counts once it has fired, whether or not it was cleared; one still to come does not.
        precondition(cue("upcoming", "a").hasFired == false && cue("due", "a").hasFired && cue("acknowledged", "a").hasFired)
        precondition(cue("due", "a").id != cue("due", "b").id, "each occurrence is its own item")

        // The ring: routines (in units of their target, capped) and one-off tasks together are Tasks; reminders count once fired; empty kinds drop out.
        let segments = DayProgress.segments(routines: [routine(2, of: 3), routine(5, of: 1), routine(0, of: 2, scheduled: false)],
                                            tasksDone: 1, tasksTotal: 3, cues: [cue("due", "a"), cue("upcoming", "b"), cue("acknowledged", "c")])
        precondition(segments == [DaySegment(kind: .tasks, done: 1 + 3, total: 3 + 4), DaySegment(kind: .cues, done: 2, total: 3)],
                     "a routine over target counts only up to its target; one not scheduled today is left out")
        precondition(DayProgress.segments(routines: [], tasksDone: 0, tasksTotal: 0, cues: []).isEmpty, "an empty day has no ring")
        precondition(DayProgress.segments(routines: [], tasksDone: 0, tasksTotal: 2, cues: []).map(\.kind) == [.tasks], "only kinds with something in them")

        // The Reminders list's shelves: what is overdue, what is coming, what has no time, what is finished last.
        // A snooze replaces the due time, and a finished record older than a day drops off the list entirely.
        var snoozed = reminder(due: hours(-2)); snoozed.snoozedUntil = hours(1)
        var older = reminder(due: hours(-6)); older = older.with(id: "older")
        let shelves = ReminderSections.sections(
            [reminder(due: hours(2)), reminder(state: "done", completed: hours(-1)), reminder(),
             reminder(due: hours(-3)), snoozed, older, reminder(state: "done", completed: hours(-30))],
            now: now)
        precondition(shelves.map(\.group) == [.due, .upcoming, .undated, .done],
                     "empty shelves are left out and finished ones come last: \(shelves.map(\.group))")
        precondition(shelves[0].items.map(\.id) == ["older", "r"], "most overdue first")
        precondition(shelves[1].items.map(\.id) == ["r", "r"], "a snooze moves it to when it will actually be heard")
        precondition(shelves[1].items.first?.snoozedUntil == hours(1))
        precondition(shelves[2].items.count == 1 && ReminderSections.effectiveDate(shelves[2].items[0]) == nil, "no date at all")
        precondition(shelves[3].items.count == 1, "the one finished yesterday is gone")
        precondition(ReminderSections.group(reminder(due: now), now: now) == .due, "due exactly now counts as due")
        print("ReminderStateChecks passed")
    }
}

extension Wire.Reminder {
    func with(id: String) -> Wire.Reminder { var r = self; r.id = id; return r }
}

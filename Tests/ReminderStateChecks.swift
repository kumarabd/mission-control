import Foundation

// When a reminder shows as done, and for how long. Compiled with LifeWire.swift:
//   xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift Tests/ReminderStateChecks.swift -o /private/tmp/reminder-state-checks && /private/tmp/reminder-state-checks
@main
struct ReminderStateChecks {
    static let now = Date(timeIntervalSince1970: 1_791_900_000)
    static func hours(_ h: Double) -> Date { now.addingTimeInterval(h * 3600) }

    static func reminder(state: String = "pending", due: Date? = nil, snoozed: Date? = nil, rule: Wire.Recurrence? = nil,
                         completed: Date? = nil, lastCompleted: Date? = nil, updated: Date = now) -> Wire.Reminder {
        Wire.Reminder(id: "r", title: "Drink water", notes: "", dueAt: due, snoozedUntil: snoozed, timeZone: "UTC", recurrence: rule, source: "user",
                      sessionId: nil, turnSeq: nil, link: nil, state: state, completedAt: completed, lastCompletedAt: lastCompleted,
                      version: 1, deletedAt: nil, createdAt: now, updatedAt: updated)
    }

    static func main() {
        let daily = Wire.Recurrence(freq: "daily", interval: 1, weekdays: nil)

        precondition(!reminder(due: hours(2)).doneForNow(now: now), "an open one-off is not done")
        precondition(reminder(state: "done", due: hours(-2), completed: hours(-1)).doneForNow(now: now), "a finished one-off is done")

        // Repeating: due tomorrow 09:00 (24h ahead of "now" = today 09:00). Ticked off after today's occurrence = done for now.
        let tomorrow = hours(24)
        precondition(reminder(due: tomorrow, rule: daily, lastCompleted: hours(0.1)).doneForNow(now: now), "ticked off since the last occurrence")
        precondition(!reminder(due: tomorrow, rule: daily, lastCompleted: hours(-30)).doneForNow(now: now), "ticked off before the last occurrence")
        precondition(!reminder(due: tomorrow, rule: daily).doneForNow(now: now), "never ticked off")
        precondition(!reminder(snoozed: hours(1), rule: daily, lastCompleted: hours(0.1)).doneForNow(now: now), "a snoozed one is not done")

        // Weekly on Mon, Wed, Fri: the gap between occurrences is two days, not a week.
        let mwf = Wire.Recurrence(freq: "weekly", interval: 1, weekdays: [1, 3, 5])
        precondition(mwf.approximatePeriod == 2 * 86_400, "shortest gap between Mon/Wed/Fri")
        precondition(Wire.Recurrence(freq: "weekly", interval: 2, weekdays: nil).approximatePeriod == 14 * 86_400)

        // How long a finished one stays on the list.
        precondition(reminder(due: hours(-5)).isShown(now: now), "open ones always show")
        precondition(reminder(state: "done", completed: hours(-1)).isShown(now: now), "finished an hour ago")
        precondition(!reminder(state: "done", completed: hours(-30)).isShown(now: now), "finished yesterday")

        precondition(reminder(rule: daily).repeatDescription == "Every day")
        precondition(reminder(rule: Wire.Recurrence(freq: "weekly", interval: 2, weekdays: nil)).repeatDescription == "Every 2 weeks")
        precondition(reminder().repeatDescription == nil)
        print("ReminderStateChecks passed")
    }
}

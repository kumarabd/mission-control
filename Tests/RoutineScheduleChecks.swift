import Foundation

// When a routine next applies. Compiled on its own:
//   xcrun swiftc -parse-as-library MissionControl/Core/Domain/RoutineSchedule.swift Tests/RoutineScheduleChecks.swift -o /private/tmp/routine-schedule-checks && /private/tmp/routine-schedule-checks
@main
struct RoutineScheduleChecks {
    static let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static func main() {
        // A Sunday-only routine, checked on a Monday: next Sunday is six days away.
        precondition(RoutineSchedule.daysUntilNext(weekdays: [0], today: 1) == 6)
        precondition(RoutineSchedule.nextLabel(weekdays: [0], today: 1, names: names) == "Sunday")
        // Monday, Wednesday, Friday: from a Monday the next is Wednesday; from a Friday it is Monday; from a Saturday it is Monday.
        precondition(RoutineSchedule.nextLabel(weekdays: [1, 3, 5], today: 1, names: names) == "Wednesday")
        precondition(RoutineSchedule.nextLabel(weekdays: [1, 3, 5], today: 5, names: names) == "Monday")
        precondition(RoutineSchedule.nextLabel(weekdays: [1, 3, 5], today: 6, names: names) == "Monday")
        // The day after is "Tomorrow"; a routine that applies on a single weekday and it is that weekday is a week away.
        precondition(RoutineSchedule.nextLabel(weekdays: [2], today: 1, names: names) == "Tomorrow")
        precondition(RoutineSchedule.daysUntilNext(weekdays: [4], today: 4) == 7)
        // Every day (empty) is never "later".
        precondition(RoutineSchedule.daysUntilNext(weekdays: [], today: 3) == nil)
        // The weekday is read in the routine's own zone: 2026-10-13 04:41 UTC is still Monday in Los Angeles and already Tuesday in UTC.
        let moment = Date(timeIntervalSince1970: 1_791_866_460)
        precondition(RoutineSchedule.weekdayNow(in: "America/Los_Angeles", now: moment) == 1)
        precondition(RoutineSchedule.weekdayNow(in: "UTC", now: moment) == 2)
        print("RoutineScheduleChecks passed")
    }
}

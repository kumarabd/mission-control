import Foundation

// The overview text is built from the record alone. Compiled with the wire types:
//   xcrun swiftc -parse-as-library MissionControl/Core/Remote/LifeWire.swift MissionControl/Core/Domain/Overview.swift Tests/OverviewChecks.swift -o /private/tmp/overview-checks && /private/tmp/overview-checks
@main
struct OverviewChecks {
    static let now = Date(timeIntervalSince1970: 1_791_900_000)

    static func routine(target: Int, cues: [String]) -> Wire.Routine {
        Wire.Routine(id: "r", title: "Drink water", minutes: 2, shortTitle: "One glass", shortMinutes: 1, weekdays: [], targetPerDay: target, nudges: cues.map { Wire.Nudge(at: $0, message: nil) },
                     timeZone: "UTC", version: 1, deletedAt: nil, createdAt: now, updatedAt: now)
    }

    static func goal(why: String, steps: [(String, Bool)], routines: [String] = [], consistency: Wire.GoalConsistency? = nil) -> Wire.Goal {
        let list = steps.enumerated().map { i, s in Wire.Step(id: "s\(i)", goalId: "g", title: s.0, minutes: 10, position: i + 1, doneAt: s.1 ? now : nil, version: 1) }
        return Wire.Goal(id: "g", title: "Lose 5 kg", why: why, weeklyTarget: 6, archivedAt: nil, version: 1, steps: list,
                         progress: .init(done: steps.filter(\.1).count, total: steps.count), nextStep: list.first { $0.doneAt == nil },
                         routineIds: routines, consistency: consistency)
    }

    static func main() {
        precondition(Overview.list([]) == "" && Overview.list(["a"]) == "a" && Overview.list(["a", "b"]) == "a and b" && Overview.list(["a", "b", "c"]) == "a, b and c")

        let r = routine(target: 3, cues: ["09:00", "13:00", "17:00"])
        let history = Wire.RoutineHistory(routine: r, days: [], last7: .init(done: 5, scheduled: 7), last30: .init(done: 21, scheduled: 30), streak: 2, bestStreak: 9)
        let text = Overview.routine(r, count: 1, target: 3, history: history, clock: { "T\($0)" }, days: "Every day")
        precondition(text == "**3 times a day**, every day, with a nudge at T09:00, T13:00 and T17:00.\n\nDone on **5 of the last 7 days** and 21 of the last 30. Best run: 9 days.", text)
        precondition(Overview.routine(routine(target: 1, cues: []), count: 0, target: 1, history: nil, clock: { $0 }, days: "Mon, Wed") == "**once a day**, mon, wed.")
        // Every number in the text is in the data: nothing is a streak that is not one.
        let numbers = Set(text.split(whereSeparator: { !$0.isNumber }).map(String.init))
        precondition(numbers.isSubset(of: ["3", "09", "00", "13", "17", "5", "7", "21", "30", "9"]), "\(numbers)")
        precondition(!text.contains("streak") && !text.lowercased().contains("great"))

        // A goal reads its progress from its routines; one-off steps are reported as they stand.
        let kept = Wire.GoalConsistency(last7: .init(done: 9, scheduled: 14), last30: .init(done: 41, scheduled: 60))
        let g = goal(why: "Feel lighter.", steps: [("Baseline weigh-in", true), ("Plan meals", false)], routines: ["a", "b"], consistency: kept)
        precondition(Overview.goal(g) == "Feel lighter.\n\n**41 of 60 routine days** kept in the last 30 days, 9 of 14 this week.\n\n**1 of 2** one-off steps done.", Overview.goal(g))
        let fresh = Wire.GoalConsistency(last7: .init(done: 0, scheduled: 0), last30: .init(done: 0, scheduled: 0))
        precondition(Overview.goal(goal(why: "", steps: [], routines: ["a"], consistency: fresh)) == "Its routine has only just started.")
        precondition(Overview.goal(goal(why: "", steps: [])) == "No routines serve it yet. Ask your assistant to set some up.")
        print("OverviewChecks passed")
    }
}

import Foundation

@main
struct PlannerChecks {
    static func main() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day = cal.startOfDay(for: now)

        if case .reminder(let r) = Planner.capture("Remind me to call the bank tomorrow", now: now, cal: cal) { precondition(r.title == "call the bank tomorrow" && r.due != nil) } else { fatalError("reminder") }
        if case .memory(let m) = Planner.capture("Decided to skip the gym on Fridays because mornings are packed", now: now, cal: cal) { precondition(m.kind == .decision && m.reason == "mornings are packed") } else { fatalError("memory") }
        if case .journal = Planner.capture("Today I felt calm after the walk", now: now, cal: cal) {} else { fatalError("journal") }
        if case .task = Planner.capture("Buy printer ink", now: now, cal: cal) {} else { fatalError("task") }

        var store = Store()
        store.plan = [PlanItem(title: "Draft memo", minutes: 40, day: day, isPriority: true),
                      PlanItem(title: "Reply to Sam", minutes: 10, day: day),
                      PlanItem(title: "Standup", kind: .event, minutes: 15, day: day)]
        store.goals = [Goal(title: "Learn Spanish", why: "", steps: [Step(title: "Lesson 1", minutes: 20)], weeklyTarget: 3)]
        precondition(Planner.suggestNext(minutes: 20, store: store, today: now, cal: cal)?.title == "Lesson 1")   // priority is 40, too long
        precondition(Planner.suggestNext(minutes: 45, store: store, today: now, cal: cal)?.title == "Draft memo")
        precondition(Planner.suggestNext(minutes: 5, store: Store(), today: now, cal: cal) == nil)

        let change = Planner.replan(items: store.plan, minutesLeft: 30)
        precondition(change.keep.contains { $0.title == "Standup" } && change.keep.contains { $0.title == "Reply to Sam" })
        precondition(change.moveToTomorrow.map(\.title) == ["Draft memo"])

        var done = store.plan; done[1].doneAt = now
        let close = Planner.closeDay(items: done, reflection: nil)
        precondition(close.done == 1 && close.carried.map(\.title) == ["Draft memo"] && close.tomorrowNote.contains("Draft memo"))

        precondition(Planner.smallerStep(for: store.goals[0], obstacle: .noTime).minutes == 2)
        print("PlannerChecks passed")
    }
}

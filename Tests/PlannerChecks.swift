import Foundation

@main
struct PlannerChecks {
    static func main() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day = cal.startOfDay(for: now)

        // Dates are read by the system's detector against the real clock, so these check structure, not a fixed date.
        let local = Calendar.current, real = Date()
        func reminder(_ text: String) -> Reminder {
            guard case .reminder(let r) = Planner.capture(text, now: real, cal: local) else { fatalError("not a reminder: \(text)") }
            return r
        }
        let bank = reminder("Remind me to call the bank tomorrow")
        precondition(bank.title == "call the bank" && local.component(.hour, from: bank.due!) == 9 && local.isDate(bank.due!, inSameDayAs: local.date(byAdding: .day, value: 1, to: real)!), "a day with no time means 9am")
        let mum = reminder("remind me to call Mum tomorrow at 5pm")
        precondition(mum.title == "call Mum" && local.component(.hour, from: mum.due!) == 17 && local.component(.minute, from: mum.due!) == 0)
        let timed = reminder("call the dentist tomorrow at 10:30am")   // no "remind", but it has a time on it
        precondition(timed.title == "call the dentist" && local.component(.hour, from: timed.due!) == 10 && local.component(.minute, from: timed.due!) == 30)
        let soon = reminder("remind me to check the oven in 20 minutes")
        precondition(soon.title == "check the oven" && abs(soon.due!.timeIntervalSince(real) - 1200) < 120)
        for (text, seconds) in [("remind me to stretch in 2 hours", 7200.0), ("remind me to stretch in an hour", 3600), ("remind me to stretch in half an hour", 1800), ("remind me to stretch in 45 mins", 2700)] {
            let r = reminder(text)
            precondition(r.title == "stretch" && abs(r.due!.timeIntervalSince(real) - seconds) < 120, text)
        }
        let fixed = reminder("pay the invoice on March 3 2031 at 7:30pm")
        let parts = local.dateComponents([.year, .month, .day, .hour, .minute], from: fixed.due!)
        precondition(fixed.title == "pay the invoice" && parts.year == 2031 && parts.month == 3 && parts.day == 3 && parts.hour == 19 && parts.minute == 30)
        precondition(reminder("remind me to renew my passport").due == nil, "a reminder with no time stays undated, it is not given a made-up one")
        let noon = Planner.detectDate(in: "lunch at 12pm", now: real, cal: local)
        precondition(noon != nil && local.component(.hour, from: noon!.date) == 12)
        precondition(Planner.detectDate(in: "buy printer ink", now: real, cal: local) == nil)
        // A bare time that has already passed today is tomorrow.
        let earlier = local.date(bySettingHour: 0, minute: 1, second: 0, of: real)!
        if let past = Planner.detectDate(in: "at 12:30am", now: real, cal: local), real > earlier { precondition(past.date > real, "past times roll forward a day") }
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

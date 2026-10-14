#if DEBUG
import Foundation

/// Debug builds started with `-dev-engine` talk to this instead of the router: a small world of sample data that answers the Life
/// Engine's operations, so the screens can be run and looked at without a workspace. It never ships.
final class DevWorld: @unchecked Sendable {
    private let lock = NSLock()
    private var routines: [Wire.RoutineStatus]
    private var tasks: [Wire.PlanItem]
    private var agenda: [Wire.AgendaItem]
    private var undated: Wire.Reminder
    private let goal: Wire.Goal
    private let now = Date()

    init() {
        let tz = TimeZone.current.identifier, now = Date()
        func routine(_ id: String, _ title: String, target: Int, count: Int, cues: [String]) -> Wire.RoutineStatus {
            let r = Wire.Routine(id: id, title: title, minutes: 5, shortTitle: "A smaller version", shortMinutes: 1, weekdays: [], targetPerDay: target, cues: cues, timeZone: tz,
                                 version: 1, deletedAt: nil, createdAt: now.addingTimeInterval(-86_400 * 20), updatedAt: now)
            return Wire.RoutineStatus(routine: r, scheduled: true, target: target, count: count, done: count >= target, variant: nil, streak: 2, daysSinceLast: 0, gap: false,
                                      hint: count > 0 ? "\(count) of \(target) today so far." : "Today: \(title)")
        }
        routines = [routine("r1", "Drink water", target: 3, count: 1, cues: ["09:00", "13:00", "17:00", "20:00"]),
                    routine("r2", "Weekly weigh-in", target: 1, count: 0, cues: ["08:00"]),
                    routine("r3", "Stretch", target: 1, count: 1, cues: [])]
        let day = DevWorld.dayString(now)
        func task(_ id: String, _ title: String, minutes: Int, priority: Bool, at: Date?, done: Bool = false) -> Wire.PlanItem {
            Wire.PlanItem(id: id, day: day, title: title, kind: "task", minutes: minutes, startAt: at, isPriority: priority, goalId: nil, stepId: nil, doneAt: done ? now : nil, version: 1, deletedAt: nil)
        }
        tasks = [task("t1", "Book the dentist", minutes: 10, priority: true, at: nil),
                 task("t2", "Reply to Sam about the trip", minutes: 15, priority: false, at: nil),
                 task("t3", "Prepare the project review", minutes: 45, priority: false, at: now.addingTimeInterval(3 * 3600)),
                 task("t4", "Pay the electricity bill", minutes: 5, priority: false, at: nil, done: true)]
        func reminder(_ id: String, _ title: String, due: Date, repeats: Bool) -> Wire.Reminder {
            Wire.Reminder(id: id, title: title, notes: "", dueAt: due, snoozedUntil: nil, timeZone: tz, recurrence: repeats ? .init(freq: "daily", interval: 1, weekdays: nil) : nil,
                          source: "agent", sessionId: nil, turnSeq: nil, link: nil, state: "pending", completedAt: nil, lastCompletedAt: nil, version: 1, deletedAt: nil,
                          createdAt: now.addingTimeInterval(-86_400), updatedAt: now)
        }
        agenda = [Wire.AgendaItem(reminder: reminder("c1", "Take vitamins", due: now.addingTimeInterval(-3 * 3600), repeats: true), at: now.addingTimeInterval(-3 * 3600), state: "acknowledged", overdue: false),
                  Wire.AgendaItem(reminder: reminder("c2", "Call the bank", due: now.addingTimeInterval(-600), repeats: false), at: now.addingTimeInterval(-600), state: "due", overdue: false),
                  Wire.AgendaItem(reminder: reminder("c3", "Water the plants", due: now.addingTimeInterval(2 * 3600), repeats: true), at: now.addingTimeInterval(2 * 3600), state: "upcoming", overdue: false)]
        undated = Wire.Reminder(id: "u1", title: "Renew the library card", notes: "Bring ID", dueAt: nil, snoozedUntil: nil, timeZone: tz, recurrence: nil,
                                source: "user", sessionId: nil, turnSeq: nil, link: nil, state: "pending", completedAt: nil, lastCompletedAt: nil,
                                version: 1, deletedAt: nil, createdAt: now, updatedAt: now)
        let steps = [Wire.Step(id: "s1", goalId: "g1", title: "Weigh in and record a starting weight", minutes: 5, position: 1, doneAt: nil, version: 1)]
        goal = Wire.Goal(id: "g1", title: "Lose 5 kg", why: "Feel lighter and healthier.", weeklyTarget: 6, archivedAt: nil, version: 1, steps: steps,
                         progress: .init(done: 0, total: 1), nextStep: steps[0], routineIds: ["r1", "r2"],
                         consistency: .init(last7: .init(done: 9, scheduled: 14), last30: .init(done: 41, scheduled: 60)))
    }

    static func dayString(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }

    /// The Life Engine's answer to one operation.
    func respond(_ operation: String, body: [String: Any]) -> Data {
        lock.lock(); defer { lock.unlock() }
        func json<T: Encodable>(_ v: T) -> Data { (try? Wire.encoder.encode(v)) ?? Data("{}".utf8) }
        switch operation {
        case "settings_get", "settings_set": return json(Wire.Settings(id: "s", timeZone: TimeZone.current.identifier, workStart: "09:00", workEnd: "17:00", version: 1))
        case "routines_status": return json(Wire.RoutinesStatus(day: DevWorld.dayString(now), items: routines))
        case "routines_log":
            if let id = body["routine_id"] as? String, let i = routines.firstIndex(where: { $0.id == id }) {
                var s = routines[i]; s.count = max(0, s.count + (body["delta"] as? Int ?? 1)); s.done = s.count >= s.target
                s.hint = "\(s.count) of \(s.target) today so far."; routines[i] = s
                return json(s)
            }
            return Data("{}".utf8)
        case "plan_get":
            return json(Wire.PlanDay(day: DevWorld.dayString(now), items: tasks, proposals: [], summary: .init(planned: tasks.count, done: tasks.filter { $0.doneAt != nil }.count, minutesOpen: 60, minutesDone: 5, minutesEvents: 0)))
        case "plan_items_complete":
            if let id = body["id"] as? String, let i = tasks.firstIndex(where: { $0.id == id }) {
                tasks[i].doneAt = (body["done"] as? Bool ?? true) ? now : nil
                return json(tasks[i])
            }
            return Data("{}".utf8)
        case "next_action": return json(Wire.NextAction(suggestion: .init(title: goal.steps[0].title, minutes: 5, reason: "Next step toward Lose 5 kg", source: "goal_step", planItemId: nil, goalId: "g1", stepId: "s1")))
        case "reminders_agenda": return json(Wire.Agenda(day: DevWorld.dayString(now), items: agenda))
        case "reminders_list": return json(Wire.Page<Wire.Reminder>(items: agenda.map(\.reminder) + [undated], total: agenda.count + 1, nextOffset: nil))
        case "reminders_complete":
            if body["id"] as? String == undated.id { undated.state = "done"; undated.completedAt = Date(); undated.version += 1; return json(undated) }
            return Data("{}".utf8)
        case "reminders_ack":
            if let id = body["id"] as? String, let i = agenda.firstIndex(where: { $0.reminder.id == id }) { agenda[i].state = "acknowledged"; return json(agenda[i].reminder) }
            return Data("{}".utf8)
        case "goals_list": return json(Wire.Page<Wire.Goal>(items: [goal], total: 1, nextOffset: nil))
        default: return Data("{}".utf8)
        }
    }

    /// A Life Engine API whose transport is this world.
    func api() -> LifeAPI {
        LifeAPI(baseURL: "https://dev.local/life/api/v1", token: { "dev" }, transport: { [self] request in
            let op = request.url?.lastPathComponent ?? ""
            let body = (request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            return (respond(op, body: body), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
    }
}
#endif

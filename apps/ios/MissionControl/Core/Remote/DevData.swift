#if DEBUG
import Foundation

/// Debug builds started with `-dev-engine` talk to this instead of the router: a small world of sample data that answers the Life
/// Engine's operations, so the screens can be run and looked at without a workspace. It never ships.
final class DevWorld: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Wire.Item]
    private var goals: [Wire.Goal]
    private let now = Date()

    init() {
        let tz = TimeZone.current.identifier, now = Date()
        func item(_ id: String, _ kind: String, _ title: String, at: Date?, minutes: Int? = nil, priority: Bool = false, goal: String? = nil,
                  repeats: Bool = false, alert: Int? = nil, done: Bool = false) -> Wire.Item {
            Wire.Item(id: id, kind: kind, subject: "person", title: title, notes: "", goalId: goal, at: at, minutes: minutes, timeZone: tz,
                      recurrence: repeats ? .init(freq: "daily", interval: 1, weekdays: nil) : nil, alertBeforeMinutes: alert, isPriority: priority,
                      snoozedUntil: nil, doneAt: done ? now : nil, version: 1, deletedAt: nil, createdAt: now.addingTimeInterval(-86_400), updatedAt: now)
        }
        items = [item("t1", "task", "Book the dentist", at: nil, minutes: 10, priority: true),
                 item("t2", "task", "Reply to Sam about the trip", at: nil, minutes: 15, goal: "g1"),
                 item("t3", "task", "Prepare the project review", at: now.addingTimeInterval(3 * 3600), minutes: 45, alert: 15),
                 item("t4", "task", "Pay the electricity bill", at: nil, minutes: 5, done: true),
                 item("t5", "task", "Take vitamins", at: now.addingTimeInterval(-3 * 3600), repeats: true, alert: 0),
                 item("t6", "task", "File the expense report", at: now.addingTimeInterval(-2 * 86_400)),
                 item("t7", "task", "Do 3 sets of pull-ups", at: nil, minutes: 20, goal: "g2"),
                 item("t8", "task", "Read 20 pages", at: nil, minutes: 20, goal: "g3", repeats: true),
                 item("t9", "task", "Run 5 km", at: nil, minutes: 30, goal: "g4"),
                 item("e1", "event", "Team standup", at: now.addingTimeInterval(2 * 3600), minutes: 15, repeats: true),
                 item("e2", "event", "Flight to Lisbon", at: now.addingTimeInterval(3 * 86_400), minutes: 150, goal: "g1", alert: 180)]
        goals = [
            Wire.Goal(id: "g1", subject: "person", title: "Lisbon trip", notes: "Take the coolers", endsOn: DevWorld.dayString(now.addingTimeInterval(10 * 86_400)),
                      progress: .init(done: 2, total: 4), next: nil, version: 1, deletedAt: nil),
            Wire.Goal(id: "g2", subject: "person", title: "Get to 5 pull-ups by spring", notes: "Small sets, every other day", endsOn: DevWorld.dayString(now.addingTimeInterval(120 * 86_400)),
                      progress: .init(done: 2, total: 4), next: nil, version: 1, deletedAt: nil),
            Wire.Goal(id: "g3", subject: "person", title: "Read 12 books this year", notes: "One chapter at a time", endsOn: DevWorld.dayString(now.addingTimeInterval(200 * 86_400)),
                      progress: .init(done: 3, total: 12), next: nil, version: 1, deletedAt: nil),
            Wire.Goal(id: "g4", subject: "person", title: "Run a half marathon", notes: "Build the weekly long run", endsOn: DevWorld.dayString(now.addingTimeInterval(180 * 86_400)),
                      progress: .init(done: 1, total: 5), next: nil, version: 1, deletedAt: nil),
        ]
    }

    static func dayString(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }

    /// The Life Engine's answer to one operation.
    func respond(_ operation: String, body: [String: Any]) -> Data {
        lock.lock(); defer { lock.unlock() }
        func json<T: Encodable>(_ v: T) -> Data { (try? Wire.encoder.encode(v)) ?? Data("{}".utf8) }
        let cal = Calendar.current
        switch operation {
        case "settings_get", "settings_set": return json(Wire.Settings(id: "s", timeZone: TimeZone.current.identifier, workStart: "09:00", workEnd: "17:00", version: 1))
        case "day_get":
            let entries = items.filter { $0.at != nil }.compactMap { i -> Wire.DayEntry? in
                guard let at = i.at else { return nil }
                if cal.isDateInToday(at) || i.repeats {
                    let state = i.isEvent ? (at > now ? "upcoming" : "past") : (i.isDone ? "done" : "open")
                    return Wire.DayEntry(item: i, at: at, state: state, overdue: false)
                }
                if i.isTask, !i.isDone, at < cal.startOfDay(for: now) { return Wire.DayEntry(item: i, at: at, state: "open", overdue: true) }
                return nil
            }.sorted { $0.at < $1.at }
            return json(Wire.Day(day: DevWorld.dayString(now), entries: entries))
        case "tasks_list":
            let open = items.filter { $0.isTask && !$0.isDone }
            return json(Wire.Page<Wire.Item>(items: open, total: open.count, nextOffset: nil))
        case "calendar_events_list":
            let events = items.filter(\.isEvent)
            return json(Wire.Page<Wire.Item>(items: events, total: events.count, nextOffset: nil))
        case "tasks_complete":
            if let id = body["id"] as? String, let i = items.firstIndex(where: { $0.id == id }) {
                if !items[i].repeats { items[i].doneAt = (body["done"] as? Bool ?? true) ? now : nil }
                return json(items[i])
            }
            return Data("{}".utf8)
        case "views_state":
            // One sample view, for the goal, so the screen that draws a composed view can be run and looked at.
            guard body["subject_kind"] as? String == "goal" else {
                return Data("{\"subject_kind\":\"\(body["subject_kind"] as? String ?? "task")\",\"subject_id\":\"\(body["subject_id"] as? String ?? "")\",\"catalog_id\":\"view-kit.v1\",\"view\":null,\"measurements\":[]}".utf8)
            }
            return Data(DevWorld.sampleViewState(subjectID: body["subject_id"] as? String ?? "g1", now: now).utf8)
        case "goals_list": return json(Wire.Page<Wire.Goal>(items: goals, total: goals.count, nextOffset: nil))
        default: return Data("{}".utf8)
        }
    }

    static func sampleViewState(subjectID: String, now: Date) -> String {
        let f = ISO8601DateFormatter()
        func obs(_ i: Int, _ d: Int, _ v: Double) -> String {
            "{\"id\":\"m\(i)\",\"subject_kind\":\"goal\",\"subject_id\":\"\(subjectID)\",\"metric_id\":\"saved\",\"unit\":\"EUR\",\"value\":\(v),\"measured_at\":\"\(f.string(from: now.addingTimeInterval(Double(-d) * 86_400)))\",\"notes\":\"\",\"version\":1,\"deleted_at\":null,\"created_at\":\"\(f.string(from: now))\",\"updated_at\":\"\(f.string(from: now))\"}"
        }
        let view = """
        {"id":"v1","subject_kind":"goal","subject_id":"\(subjectID)","catalog_id":"view-kit.v1","version":1,
         "metrics":[{"id":"saved","label":"Saved for the trip","unit":"EUR","target":2000}],
         "pages":[{"id":"main","sections":[
           {"id":"standing","title":"Where you stand","intro":"What you have put aside against the 2,000 you need.","blocks":[
             {"id":"head","kind":"sentence","emphasis":"hero","text":"{saved} saved, {left} to go","slots":{
               "saved":{"calc":{"fn":"latest","metric":"saved"},"format":"money","unit":"EUR"},
               "left":{"calc":{"fn":"sub","args":[{"fn":"const","value":2000},{"fn":"latest","metric":"saved"}]},"format":"money","unit":"EUR"}}},
             {"id":"bar","kind":"bar","value":{"fn":"latest","metric":"saved"},"of":{"fn":"const","value":2000},"format":"money","unit":"EUR"},
             {"id":"trend","kind":"series","title":"Saved","metric":"saved","style":"line","window":{"days":30},"unit":"EUR"},
             {"id":"log","kind":"log","metric":"saved"}]},
           {"id":"plan","title":"The plan","blocks":[{"id":"todo","kind":"tasks","title":"Tasks"},{"id":"dates","kind":"events","title":"Coming up"}]}]}]}
        """
        let ms = [obs(1, 20, 300), obs(2, 12, 650), obs(3, 5, 1100)].joined(separator: ",")
        return "{\"subject_kind\":\"goal\",\"subject_id\":\"\(subjectID)\",\"catalog_id\":\"view-kit.v1\",\"view\":\(view),\"measurements\":[\(ms)]}"
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

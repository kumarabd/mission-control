import Foundation

// Decodes real responses recorded from the Life Engine (Tests/Fixtures/life) with the app's wire models, and checks how
// the client classifies the ways a call can fail. Run with the fixtures directory as the argument.
@main
struct LifeContractChecks {
    static func load<T: Decodable>(_ type: T.Type, _ name: String, in dir: String) -> T {
        let data = try! Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent(name + ".json"))
        do { return try Wire.decoder.decode(T.self, from: data) } catch { fatalError("\(name): \(error)") }
    }

    static func main() async {
        let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Tests/Fixtures/life"

        let r = load(Wire.Reminder.self, "reminder", in: dir)
        precondition(r.title == "Pay rent" && r.source == "agent" && r.sessionId == "agent:main:ios:user:u" && r.turnSeq == 7)
        precondition(r.link == Wire.Link(entity: "goal", id: "g1") && r.version == 1 && !r.isDone && r.recurrence == nil && r.deletedAt == nil)
        precondition(r.dueAt == ISO8601DateFormatter().date(from: "2030-01-15T09:00:00Z"), "a timestamp without fractions")
        precondition(r.createdAt.timeIntervalSince1970 > 1_700_000_000, "a timestamp with microseconds")

        let rep = load(Wire.Reminder.self, "reminder_repeating", in: dir)
        precondition(rep.recurrence == .init(freq: "weekly", interval: 1, weekdays: [1, 3, 5]) && rep.timeZone == "Europe/London")
        precondition(load(Wire.Reminder.self, "reminder_undated", in: dir).dueAt == nil)
        precondition(load(Wire.Reminder.self, "reminder_completed", in: dir).isDone)

        let page = load(Wire.Page<Wire.Reminder>.self, "reminders_page", in: dir)
        precondition(page.total == page.items.count && page.nextOffset == nil && page.items.count >= 3)

        let goal = load(Wire.Goal.self, "goal", in: dir)
        precondition(goal.steps.count == 2 && goal.steps[1].position == 2 && goal.nextStep?.title == "Pick a course" && goal.progress == .init(done: 0, total: 2) && goal.weeklyTarget == 4)
        precondition(load(Wire.Page<Wire.Goal>.self, "goals_page", in: dir).items.first?.progress.done == 1)

        let plan = load(Wire.PlanDay.self, "plan_day", in: dir)
        precondition(plan.items.count == 3 && plan.proposals.count == 1 && plan.proposals[0].changes.map(\.action) == ["move", "add"])
        precondition(plan.summary.planned == 2 && plan.items.contains { $0.isPriority && $0.goalId != nil && $0.startAt != nil })
        precondition(load(Wire.NextAction.self, "next_action", in: dir).suggestion?.source == "goal_step")
        precondition(load(Wire.NextAction.self, "next_action_none", in: dir).suggestion == nil)
        let replan = load(Wire.Replan.self, "replan", in: dir)
        precondition(replan.moveToTomorrow.count == 1 && replan.minutesKept > 0)

        precondition(load(Wire.Settings.self, "settings", in: dir).timeZone == "Europe/London")
        precondition(load(Wire.Capture.self, "capture", in: dir).state == "open")
        for name in ["error_conflict", "error_invalid", "error_not_found"] {
            precondition(!load(Wire.ErrorEnvelope.self, name, in: dir).error.message.isEmpty, name)
        }

        // How failures are classified decides what the app does next.
        func status(_ s: Int, _ body: String) -> LifeError? { LifeAPI.classify(status: s, body: Data(body.utf8)) }
        precondition(status(200, "{}") == nil)
        precondition(status(401, "invalid session token") == .unauthorized)
        precondition(status(404, #"{"error":"no_tenant"}"#) == .notProvisioned)
        precondition(status(404, #"{"error":{"code":"not_found","message":"Record not found"}}"#) == .engine(code: "not_found", message: "Record not found"))
        precondition(status(409, #"{"error":{"code":"conflict","message":"Stale version"}}"#) == .engine(code: "conflict", message: "Stale version"))
        precondition(status(503, #"{"error":{"code":"busy","message":"retry"}}"#) == .retry("server returned 503"))
        precondition(status(400, #"{"error":{"code":"busy","message":"retry"}}"#) == .retry("retry"))
        precondition(status(502, "bad gateway") == .retry("server returned 502"))
        precondition(status(500, "oops") == .server("server returned 500"))

        // An end-to-end call through a fake transport: auth header, path, body, decoding, and no token means no request.
        var seen: URLRequest?
        let fixture = try! Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent("reminder.json"))
        let api = LifeAPI(baseURL: "https://router.example/life/api/v1/", token: { "tok" }) { request in
            seen = request
            return (fixture, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        struct Get: Encodable { var id: String }
        let got: Wire.Reminder = try! await api.call("reminders_get", Get(id: r.id))
        precondition(got == r && seen?.url?.absoluteString == "https://router.example/life/api/v1/operations/reminders_get")
        precondition(seen?.value(forHTTPHeaderField: "Authorization") == "Bearer tok" && seen?.httpMethod == "POST")
        precondition(String(decoding: seen!.httpBody!, as: UTF8.self) == #"{"id":"\#(r.id)"}"#)

        let anonymous = LifeAPI(baseURL: "https://router.example/life/api/v1", token: { nil }) { _ in fatalError("must not send") }
        do { let _: Wire.Reminder = try await anonymous.call("reminders_get", Get(id: "x")); fatalError("should throw") } catch { precondition(error as? LifeError == .unauthorized) }
        let offline = LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "t" }) { _ in throw URLError(.notConnectedToInternet) }
        do { let _: Wire.Reminder = try await offline.call("reminders_get", Get(id: "x")); fatalError("should throw") } catch { precondition(error as? LifeError == .retry("network error")) }
        // The reminders service sends exactly what the engine's operations take, and nothing the engine would refuse.
        var sent: [(path: String, body: [String: Any])] = []
        let reminderJSON = fixture
        let service = RemindersService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            sent.append((request.url!.lastPathComponent, try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]))
            let body = request.url!.lastPathComponent == "reminders_list"
                ? Data(#"{"items":[],"total":0,"next_offset":null}"#.utf8) : reminderJSON
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        _ = try! await service.list()
        precondition(sent[0].path == "reminders_list" && sent[0].body["status"] as? String == "all")   // finished ones too: the app strikes them through for a day

        let due = ISO8601DateFormatter().date(from: "2030-01-15T09:00:00Z")!
        _ = try! await service.create(title: "Pay rent", due: due, recurrence: .init(freq: "daily", interval: nil, weekdays: nil), timeZone: "Europe/London", key: "k1")
        let created = sent[1].body
        precondition(sent[1].path == "reminders_create" && created["idempotency_key"] as? String == "k1" && created["title"] as? String == "Pay rent")
        precondition(created["due_at"] as? String == "2030-01-15T09:00:00Z" && created["time_zone"] as? String == "Europe/London" && created["source"] as? String == "user")
        precondition((created["recurrence"] as? [String: Any])?["freq"] as? String == "daily" && created["notes"] == nil, "optional fields are omitted, not sent as null")

        _ = try! await service.create(title: "Someday", due: nil)
        precondition(sent[2].body["due_at"] == nil && !(sent[2].body["idempotency_key"] as? String ?? "").isEmpty)

        _ = try! await service.complete(r)
        precondition(sent[3].path == "reminders_complete" && sent[3].body["id"] as? String == r.id && sent[3].body["expected_version"] as? Int == 1)
        _ = try! await service.snooze(r, until: due)
        precondition(sent[4].path == "reminders_snooze" && sent[4].body["until"] as? String == "2030-01-15T09:00:00Z")
        try! await service.delete(r)
        precondition(sent[5].path == "reminders_delete")
        precondition(Set(sent.dropFirst().map { $0.body["idempotency_key"] as? String ?? "" }).count == 5, "every intent has its own key")
        print("LifeContractChecks passed")
    }
}

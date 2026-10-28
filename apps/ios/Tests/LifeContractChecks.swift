import Foundation

// Decodes real responses recorded from the Life Engine (Tests/Fixtures/life) with the app's wire models, checks the requests
// the services send, and how the client classifies the ways a call can fail. Run with the fixtures directory as the argument.
@main
struct LifeContractChecks {
    static func load<T: Decodable>(_ type: T.Type, _ name: String, in dir: String) -> T {
        let data = try! Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent(name + ".json"))
        do { return try Wire.decoder.decode(T.self, from: data) } catch { fatalError("\(name): \(error)") }
    }
    static func fixture(_ name: String, in dir: String) -> Data { try! Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent(name + ".json")) }
    static let ok = { (request: URLRequest) in HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)! }

    static func main() async {
        let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Tests/Fixtures/life"

        // A task: a time that is a deadline or a cue, an alert, a goal, and no time zone drift.
        let task = load(Wire.Item.self, "task", in: dir)
        precondition(task.isTask && !task.isEvent && task.title == "Book flights" && task.subject == "person" && task.version == 1)
        precondition(task.alertBeforeMinutes == 15 && task.isPriority && task.minutes == 30 && task.recurrence == nil && !task.isDone)
        precondition(task.goalId != nil && task.at != nil && task.deletedAt == nil && task.alertDescription == "15 minutes before")
        precondition(task.createdAt.timeIntervalSince1970 > 1_700_000_000, "a timestamp with microseconds")

        // A repeating task is one record; it is done one occurrence at a time.
        let habit = load(Wire.Item.self, "task_repeating", in: dir)
        precondition(habit.repeats && habit.recurrence == .init(freq: "daily", interval: 1, weekdays: nil) && habit.timeZone == "Europe/London")
        precondition(habit.repeatDescription == "Every day" && habit.alertDescription == "At the time")
        precondition(load(Wire.Item.self, "task_snoozed", in: dir).snoozedUntil != nil)
        precondition(load(Wire.Item.self, "task_done", in: dir).isDone, "completing a one-off finishes it")

        let event = load(Wire.Item.self, "event", in: dir)
        precondition(event.isEvent && !event.isTask && event.title == "Standup" && event.minutes == 15 && event.alertBeforeMinutes == nil && event.alertDescription == nil)

        let tasks = load(Wire.Page<Wire.Item>.self, "tasks_page", in: dir)
        precondition(tasks.total == tasks.items.count && tasks.nextOffset == nil && tasks.items.allSatisfy(\.isTask) && !tasks.items.isEmpty)
        precondition(load(Wire.Page<Wire.Item>.self, "events_page", in: dir).items.allSatisfy(\.isEvent))

        // Goals: progress is read from the linked tasks, never kept; the next open task comes with it.
        let goal = load(Wire.Goal.self, "goal", in: dir)
        precondition(goal.title == "Lisbon trip" && goal.subject == "person" && goal.endsOn == "2027-06-10" && goal.notes == "take the coolers")
        let progressed = load(Wire.Goal.self, "goal_with_progress", in: dir)
        precondition(progressed.progress.total == 1 && progressed.next?.title == "Book flights" && progressed.endsOnText == "By Jun 10")
        precondition(load(Wire.Page<Wire.Goal>.self, "goals_page", in: dir).items.count == 1)

        // The day: one entry per occurrence, and what is still waiting from earlier days.
        let day = load(Wire.Day.self, "day", in: dir)
        precondition(!day.entries.isEmpty && day.entries.allSatisfy { !$0.state.isEmpty } && day.entries.contains { $0.item.repeats })
        precondition(day.entries.first { $0.item.isEvent }?.state == "upcoming" || day.entries.first { $0.item.isEvent }?.state == "past")

        precondition(load(Wire.Settings.self, "settings_get", in: dir).timeZone == "UTC")
        precondition(!load(Wire.ErrorEnvelope.self, "error_stale_version", in: dir).error.message.isEmpty)
        let history = load(Wire.TaskHistory.self, "task_history", in: dir)
        precondition(history.days.count == 14 && history.last7.scheduled >= 1 && history.last30.scheduled >= history.last7.scheduled && history.task.repeats)

        // How failures are classified decides what the app does next.
        func status(_ s: Int, _ body: String) -> LifeError? { LifeAPI.classify(status: s, body: Data(body.utf8)) }
        precondition(status(200, "{}") == nil)
        precondition(status(401, "invalid session token") == .unauthorized)
        precondition(status(404, #"{"error":"no_tenant"}"#) == .notProvisioned)
        precondition(status(404, #"{"error":{"code":"not_found","message":"Record not found"}}"#) == .engine(code: "not_found", message: "Record not found"))
        precondition(status(409, #"{"error":{"code":"conflict","message":"Stale version"}}"#) == .engine(code: "conflict", message: "Stale version"))
        precondition(status(503, #"{"error":{"code":"busy","message":"retry"}}"#) == .retry("server returned 503"))
        precondition(status(502, "bad gateway") == .retry("server returned 502"))
        precondition(status(500, "oops") == .server("server returned 500"))

        // An end-to-end call through a fake transport: auth header, path, body, decoding, and no token means no request.
        var seen: URLRequest?
        let taskJSON = fixture("task", in: dir)
        let api = LifeAPI(baseURL: "https://router.example/life/api/v1/", token: { "tok" }) { request in seen = request; return (taskJSON, ok(request)) }
        struct Get: Encodable { var id: String }
        let got: Wire.Item = try! await api.call("tasks_get", Get(id: task.id))
        precondition(got == task && seen?.url?.absoluteString == "https://router.example/life/api/v1/operations/tasks_get")
        precondition(seen?.value(forHTTPHeaderField: "Authorization") == "Bearer tok" && seen?.httpMethod == "POST")
        precondition(String(decoding: seen!.httpBody!, as: UTF8.self) == #"{"id":"\#(task.id)"}"#)
        let anonymous = LifeAPI(baseURL: "https://router.example/life/api/v1", token: { nil }) { _ in fatalError("must not send") }
        do { let _: Wire.Item = try await anonymous.call("tasks_get", Get(id: "x")); fatalError("should throw") } catch { precondition(error as? LifeError == .unauthorized) }
        let offline = LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "t" }) { _ in throw URLError(.notConnectedToInternet) }
        do { let _: Wire.Item = try await offline.call("tasks_get", Get(id: "x")); fatalError("should throw") } catch { precondition(error as? LifeError == .retry("network error")) }

        // The items service sends exactly what the engine's operations take, and nothing the engine would refuse.
        var sent: [(path: String, body: [String: Any])] = []
        let service = ItemsService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            let op = request.url!.lastPathComponent
            sent.append((op, try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]))
            let body = op.hasSuffix("_list") ? Data(#"{"items":[],"total":0,"next_offset":null}"#.utf8) : (op.hasPrefix("calendar_events") ? fixture("event", in: dir) : taskJSON)
            return (body, ok(request))
        })
        _ = try! await service.list(.task)
        precondition(sent[0].path == "tasks_list" && sent[0].body["status"] as? String == "open" && sent[0].body["goal_id"] == nil)
        _ = try! await service.list(.event, goalID: "g1")
        precondition(sent[1].path == "calendar_events_list" && sent[1].body["goal_id"] as? String == "g1")

        let at = ISO8601DateFormatter().date(from: "2030-01-15T09:00:00Z")!
        var draft = ItemsService.Draft()
        draft.title = "Pay rent"; draft.at = at; draft.timeZone = "Europe/London"; draft.alertBeforeMinutes = 15; draft.minutes = 10; draft.goalId = "g1"
        draft.recurrence = .init(freq: "daily", interval: nil, weekdays: nil)
        _ = try! await service.create(.task, draft, key: "k1")
        let created = sent[2].body
        precondition(sent[2].path == "tasks_create" && created["idempotency_key"] as? String == "k1" && created["title"] as? String == "Pay rent")
        precondition(created["at"] as? String == "2030-01-15T09:00:00Z" && created["time_zone"] as? String == "Europe/London" && created["alert_before_minutes"] as? Int == 15)
        precondition(created["minutes"] as? Int == 10 && created["goal_id"] as? String == "g1" && (created["recurrence"] as? [String: Any])?["freq"] as? String == "daily")
        precondition(created["id"] == nil && created["expected_version"] == nil && created["source"] == nil, "nothing the engine would refuse")

        _ = try! await service.create(.event, ItemsService.Draft(), key: "k2")
        precondition(sent[3].path == "calendar_events_create" && sent[3].body["at"] == nil && sent[3].body["recurrence"] == nil, "optional fields are omitted, not sent as null")

        draft.title = "Pay the rent"
        _ = try! await service.update(task, draft)
        precondition(sent[4].path == "tasks_update" && sent[4].body["id"] as? String == task.id && sent[4].body["expected_version"] as? Int == task.version && sent[4].body["title"] as? String == "Pay the rent")
        _ = try! await service.update(event, ItemsService.Draft(event))
        precondition(sent[5].path == "calendar_events_update" && sent[5].body["title"] as? String == event.title, "an update sends every field back")

        _ = try! await service.complete(task)
        precondition(sent[6].path == "tasks_complete" && sent[6].body["id"] as? String == task.id && sent[6].body["expected_version"] as? Int == task.version)
        precondition(sent[6].body["done"] == nil && sent[6].body["at"] == nil, "done is the default; no occurrence for a one-off")
        _ = try! await service.complete(habit, at: at, done: false)
        precondition(sent[7].body["at"] as? String == "2030-01-15T09:00:00Z" && sent[7].body["done"] as? Bool == false, "an occurrence is reopened by naming it")
        _ = try! await service.snooze(task, until: at)
        precondition(sent[8].path == "tasks_snooze" && sent[8].body["until"] as? String == "2030-01-15T09:00:00Z")
        _ = try! await service.snooze(event, until: at)
        precondition(sent[9].path == "calendar_events_snooze")
        try! await service.delete(task)
        precondition(sent[10].path == "tasks_delete" && sent[10].body["expected_version"] as? Int == task.version)
        precondition(Set(sent.compactMap { $0.body["idempotency_key"] as? String }).count == sent.filter { $0.body["idempotency_key"] != nil }.count, "every intent has its own key")

        // Goals are read, and archived; the day is read.
        var calls: [String] = []
        let goals = GoalsService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            calls.append(request.url!.lastPathComponent)
            return (request.url!.lastPathComponent == "goals_list" ? fixture("goals_page", in: dir) : fixture("goal", in: dir), ok(request))
        })
        let listed = try! await goals.list()
        precondition(calls == ["goals_list"] && listed.count == 1)
        try! await goals.archive(listed[0])
        precondition(calls == ["goals_list", "goals_archive"])
        let days = DayService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            calls.append(request.url!.lastPathComponent); return (fixture("day", in: dir), ok(request))
        })
        let today = try! await days.today()
        precondition(today.entries.count == day.entries.count && calls.last == "day_get")

        // Settings: the phone's time zone is sent only when it differs from the engine's.
        let settingsNow = load(Wire.Settings.self, "settings_get", in: dir)
        var settingsCalls: [(path: String, body: [String: Any])] = []
        let settingsService = SettingsService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            settingsCalls.append((request.url!.lastPathComponent, try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]))
            return (fixture("settings_get", in: dir), ok(request))
        })
        let changed = try! await settingsService.matchTimeZone(to: "Antarctica/Troll")
        precondition(changed && settingsCalls.map(\.path) == ["settings_get", "settings_set"])
        precondition(settingsCalls[1].body["time_zone"] as? String == "Antarctica/Troll" && settingsCalls[1].body["expected_version"] as? Int == settingsNow.version)
        settingsCalls.removeAll()
        let unchanged = try! await settingsService.matchTimeZone(to: settingsNow.timeZone)
        precondition(!unchanged && settingsCalls.map(\.path) == ["settings_get"], "nothing is written when the zones already match")
        print("LifeContractChecks passed")
    }
}

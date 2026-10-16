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

        // The day's cues: one entry per occurrence, with whether it has fired.
        let agenda = load(Wire.Agenda.self, "reminders_agenda", in: dir)
        precondition(!agenda.items.isEmpty && agenda.items[0].state == "due" && agenda.items[0].hasFired && !agenda.items[0].overdue)
        precondition(load(Wire.Reminder.self, "reminder_acked", in: dir).isDone, "clearing a one-off finishes it")

        // Routines: a daily target, several cues, a count against the target, and a history for the tracker.
        let routine = load(Wire.Routine.self, "routine", in: dir)
        precondition(routine.title == "Morning run" && routine.targetPerDay == 1 && routine.cues == ["07:30"] && routine.weekdays == [1, 2, 3, 4, 5])
        let counted = load(Wire.Routine.self, "routine_counted", in: dir)
        // An engine that has not shipped nudges still sends `cues`; they read as nudges without a note.
        let old = try! Wire.decoder.decode(Wire.Routine.self, from: """
            {"id":"o","title":"T","minutes":5,"short_title":"s","short_minutes":1,"weekdays":[],"target_per_day":1,"cues":["08:00"],"time_zone":"UTC","version":1,"deleted_at":null,"created_at":"2026-10-01T00:00:00Z","updated_at":"2026-10-01T00:00:00Z"}
            """.data(using: .utf8)!)
        precondition(old.cues == ["08:00"] && old.nudges.first?.message == nil)
        precondition(counted.targetPerDay == 3 && counted.cues == ["09:00", "13:00", "17:00"])
        let logged = load(Wire.RoutineStatus.self, "routine_log", in: dir)
        precondition(logged.target == 3 && logged.count == 1 && !logged.done && logged.hint == "1 of 3 today so far." && logged.id == counted.id)
        let routinesToday = load(Wire.RoutinesStatus.self, "routines_status", in: dir)
        precondition(!routinesToday.items.isEmpty && routinesToday.items[0].target >= 1 && routinesToday.items[0].count >= 0)
        let history = load(Wire.RoutineHistory.self, "routine_history", in: dir)
        precondition(history.days.count == 14)
        precondition(history.days.last?.count == 1 && history.days.last?.target == 3 && history.last7.scheduled == 7 && history.bestStreak >= 0)

        let linked = load(Wire.Goal.self, "goal_linked", in: dir)
        precondition(linked.routineIds == ["77777777-7777-4777-8777-777777777777"], "a goal lists the routines that serve it")
        precondition(load(Wire.Goal.self, "goal", in: dir).routineIds == [])
        let linkedKept = linked.consistency!
        precondition(linkedKept.last30.scheduled >= linkedKept.last30.done && linkedKept.last7.scheduled <= linkedKept.last30.scheduled)
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
        let agendaJSON = try! Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent("reminders_agenda.json"))
        let service = RemindersService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            sent.append((request.url!.lastPathComponent, try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]))
            let body = request.url!.lastPathComponent == "reminders_list"
                ? Data(#"{"items":[],"total":0,"next_offset":null}"#.utf8)
                : request.url!.lastPathComponent == "reminders_agenda" ? agendaJSON : reminderJSON
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
        let cues = try! await service.agenda()
        precondition(sent[4].path == "reminders_agenda" && cues.count == agenda.items.count)
        _ = try! await service.ack(agenda.items[0])
        precondition(sent[5].path == "reminders_ack" && sent[5].body["id"] as? String == agenda.items[0].reminder.id && sent[5].body["at"] as? String != nil && sent[5].body["expected_version"] == nil)
        _ = try! await service.snooze(r, until: due)
        precondition(sent[6].path == "reminders_snooze" && sent[6].body["until"] as? String == "2030-01-15T09:00:00Z")
        try! await service.delete(r)
        precondition(sent[7].path == "reminders_delete")
        precondition(Set(sent.dropFirst().map { $0.body["idempotency_key"] as? String ?? "" }).count == 7, "every intent has its own key")

        // The routines service sends what the engine's operations take and reads what they return.
        func fixtureData(_ name: String) -> Data { try! Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent(name + ".json")) }
        var routineCalls: [(path: String, body: [String: Any])] = []
        let routines = RoutinesService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            let op = request.url!.lastPathComponent
            routineCalls.append((op, try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]))
            let file = ["routines_status": "routines_status", "routines_log": "routine_log", "routines_history": "routine_history", "routines_create": "routine_counted", "routines_delete": "routine_counted", "nudges_set": "routine_counted", "nudges_remove": "routine_counted"][op]!
            return (fixtureData(file), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let items = try! await routines.status()
        precondition(routineCalls[0].path == "routines_status" && items.count == routinesToday.items.count)
        let after = try! await routines.log("r1", delta: -1, short: true)
        precondition(routineCalls[1].path == "routines_log" && routineCalls[1].body["routine_id"] as? String == "r1" && routineCalls[1].body["delta"] as? Int == -1)
        precondition(routineCalls[1].body["variant"] as? String == "short" && !(routineCalls[1].body["idempotency_key"] as? String ?? "").isEmpty && after.target == 3)
        let hist = try! await routines.history("r1", days: 14)
        precondition(routineCalls[2].path == "routines_history" && routineCalls[2].body["days"] as? Int == 14 && hist.days.count == 14)
        _ = try! await routines.create(title: "Drink water", targetPerDay: 3, nudgeTimes: ["09:00", "13:00", "17:00"], weekdays: [1, 2], shortTitle: "One glass",
                                       minutes: 2, shortMinutes: 1, timeZone: "Europe/London", key: "rk")
        let made = routineCalls[3].body
        precondition(routineCalls[3].path == "routines_create" && made["idempotency_key"] as? String == "rk" && made["target_per_day"] as? Int == 3)
        precondition((made["nudges"] as? [[String: Any]])?.compactMap { $0["at"] as? String } == ["09:00", "13:00", "17:00"] && made["short_title"] as? String == "One glass" && made["time_zone"] as? String == "Europe/London")
        precondition(made["weekdays"] as? [Int] == [1, 2] && made["minutes"] as? Int == 2 && made["short_minutes"] as? Int == 1)
        _ = try! await routines.setNudge(counted, at: "18:00", message: "after work")
        let setBody = routineCalls[4].body
        precondition(routineCalls[4].path == "nudges_set" && setBody["id"] as? String == counted.id && setBody["expected_version"] as? Int == counted.version
                     && setBody["at"] as? String == "18:00" && setBody["message"] as? String == "after work")
        _ = try! await routines.removeNudge(counted, at: "18:00")
        precondition(routineCalls[5].path == "nudges_remove" && routineCalls[5].body["at"] as? String == "18:00")
        try! await routines.delete(counted)
        precondition(routineCalls[6].path == "routines_delete" && routineCalls[6].body["expected_version"] as? Int == counted.version)
        // Goals are read, never written from the app: a goal is for review and changes through the assistant.
        var goalCalls: [String] = []
        let goalsService = GoalsService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            goalCalls.append(request.url!.lastPathComponent)
            return (fixtureData("goals_page"), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let goalsNow = try! await goalsService.list()
        precondition(goalCalls == ["goals_list"] && !goalsNow.isEmpty)
        precondition(goalsNow[0].consistency != nil && goalsNow[0].routineIds != nil, "a goal carries the routines that serve it and how well they were kept")

        // Today's tasks: the engine's plan, completed and moved with the version just read.
        var planCalls: [(path: String, body: [String: Any])] = []
        let planService = PlanService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            let op = request.url!.lastPathComponent
            planCalls.append((op, try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]))
            let file = ["plan_get": "plan_day", "next_action": "next_action", "plan_replan_preview": "replan", "day_close": "day_close"][op] ?? "plan_item"
            return (fixtureData(file), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let day = try! await planService.today()
        precondition(planCalls[0].path == "plan_get" && day.items.count == plan.items.count)
        let item = day.items.first { $0.doneAt == nil } ?? day.items[0]
        _ = try! await planService.complete(item, done: true)
        precondition(planCalls[1].path == "plan_items_complete" && planCalls[1].body["id"] as? String == item.id && planCalls[1].body["done"] as? Bool == true && planCalls[1].body["expected_version"] as? Int == item.version)
        _ = try! await planService.add(title: "Call the bank", minutes: 15, priority: true)
        precondition(planCalls[2].path == "plan_items_create" && planCalls[2].body["title"] as? String == "Call the bank" && planCalls[2].body["is_priority"] as? Bool == true && planCalls[2].body["kind"] as? String == "task")
        _ = try! await planService.setPriority(item, true)
        precondition(planCalls[3].path == "plan_items_update" && planCalls[3].body["title"] as? String == item.title && planCalls[3].body["minutes"] as? Int == item.minutes && planCalls[3].body["is_priority"] as? Bool == true, "an update sends every field back")
        try! await planService.move(item, to: "2030-01-16")
        precondition(planCalls[4].path == "plan_items_move" && planCalls[4].body["day"] as? String == "2030-01-16")
        let suggestion = try! await planService.nextAction(minutes: 20)
        precondition(planCalls[5].path == "next_action" && planCalls[5].body["minutes"] as? Int == 20 && suggestion?.source == "goal_step")
        let preview = try! await planService.replan(minutesLeft: 60)
        precondition(planCalls[6].path == "plan_replan_preview" && planCalls[6].body["minutes_left"] as? Int == 60 && preview.moveToTomorrow.count == 1)
        let closed = try! await planService.closeDay(reflection: "")
        precondition(planCalls[7].path == "day_close" && planCalls[7].body["reflection"] == nil, "an empty reflection is not sent")
        precondition(closed.summary.isEmpty == false && closed.nextDay > closed.day)
        try! await planService.delete(item)
        precondition(planCalls[8].path == "plan_items_delete" && planCalls[8].body["expected_version"] as? Int == item.version)
        precondition(PlanService.dayAfter("2026-10-13") == "2026-10-14" && PlanService.dayAfter("2026-12-31") == "2027-01-01" && PlanService.dayAfter(nil) == nil)

        // Settings: the phone's time zone is sent only when it differs from the engine's.
        let settingsNow = load(Wire.Settings.self, "capabilities_ok", in: dir)
        var settingsCalls: [(path: String, body: [String: Any])] = []
        let settingsService = SettingsService(api: LifeAPI(baseURL: "https://router.example/life/api/v1", token: { "tok" }) { request in
            settingsCalls.append((request.url!.lastPathComponent, try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]))
            return (fixtureData("capabilities_ok"), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let changed = try! await settingsService.matchTimeZone(to: "Antarctica/Troll")
        precondition(changed && settingsCalls.map(\.path) == ["settings_get", "settings_set"])
        precondition(settingsCalls[1].body["time_zone"] as? String == "Antarctica/Troll" && settingsCalls[1].body["expected_version"] as? Int == settingsNow.version)
        precondition(settingsCalls[1].body["work_start"] as? String == settingsNow.workStart && !(settingsCalls[1].body["idempotency_key"] as? String ?? "").isEmpty)
        settingsCalls.removeAll()
        let unchanged = try! await settingsService.matchTimeZone(to: settingsNow.timeZone)
        precondition(!unchanged && settingsCalls.map(\.path) == ["settings_get"], "nothing is written when the zones already match")
        print("LifeContractChecks passed")
    }
}

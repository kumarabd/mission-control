import Foundation

/// Today's tasks are the Life Engine's plan: the same items the assistant adds, moves and completes. Nothing here keeps a copy on the
/// phone. A task linked to a goal's step finishes that step when it is completed.
struct PlanService {
    var api: LifeAPI

    private struct DayIn: Encodable { var day: String? }
    private struct CreateIn: Encodable {
        var idempotencyKey: String; var title: String; var kind = "task"; var minutes: Int; var isPriority: Bool; var goalId: String?; var stepId: String?
    }
    private struct DoneIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var done: Bool }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }
    private struct UpdateIn: Encodable {
        var idempotencyKey: String; var id: String; var expectedVersion: Int
        var day: String; var title: String; var kind: String; var minutes: Int; var startAt: Date?; var isPriority: Bool; var goalId: String?; var stepId: String?
    }
    private struct MoveIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var day: String }
    private struct NextIn: Encodable { var minutes: Int }
    private struct ReplanIn: Encodable { var minutesLeft: Int }
    private struct CloseIn: Encodable { var idempotencyKey: String; var reflection: String? }

    /// Today's plan: tasks and events in order, and a summary.
    func today() async throws -> Wire.PlanDay { try await api.call("plan_get", DayIn(day: nil)) }

    func add(title: String, minutes: Int, priority: Bool) async throws -> Wire.PlanItem {
        try await api.call("plan_items_create", CreateIn(idempotencyKey: UUID().uuidString, title: title, minutes: minutes, isPriority: priority))
    }

    func complete(_ item: Wire.PlanItem, done: Bool) async throws -> Wire.PlanItem {
        try await api.call("plan_items_complete", DoneIn(idempotencyKey: UUID().uuidString, id: item.id, expectedVersion: item.version, done: done))
    }

    /// The update operation replaces every field, so the item's other fields are sent back unchanged.
    func setPriority(_ item: Wire.PlanItem, _ on: Bool) async throws -> Wire.PlanItem {
        try await api.call("plan_items_update", UpdateIn(idempotencyKey: UUID().uuidString, id: item.id, expectedVersion: item.version, day: item.day, title: item.title,
                                                         kind: item.kind, minutes: item.minutes, startAt: item.startAt, isPriority: on, goalId: item.goalId, stepId: item.stepId))
    }

    func delete(_ item: Wire.PlanItem) async throws {
        let _: Wire.PlanItem = try await api.call("plan_items_delete", EditIn(idempotencyKey: UUID().uuidString, id: item.id, expectedVersion: item.version))
    }

    func move(_ item: Wire.PlanItem, to day: String) async throws {
        let _: Wire.PlanItem = try await api.call("plan_items_move", MoveIn(idempotencyKey: UUID().uuidString, id: item.id, expectedVersion: item.version, day: day))
    }

    /// The one thing to do with this many minutes: today's priorities first, then the next step of a goal.
    func nextAction(minutes: Int) async throws -> Wire.Suggestion? {
        let result: Wire.NextAction = try await api.call("next_action", NextIn(minutes: minutes))
        return result.suggestion
    }

    /// Which open items still fit in the time left, and which would move to tomorrow. Read-only.
    func replan(minutesLeft: Int) async throws -> Wire.Replan { try await api.call("plan_replan_preview", ReplanIn(minutesLeft: minutesLeft)) }

    func closeDay(reflection: String?) async throws -> Wire.DayCloseResult {
        try await api.call("day_close", CloseIn(idempotencyKey: UUID().uuidString, reflection: reflection?.isEmpty == true ? nil : reflection))
    }

    /// "2026-10-13" -> "2026-10-14": a calendar day written the way the engine takes it.
    static func dayAfter(_ day: String?) -> String? {
        guard let day else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: day), let next = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: d) else { return nil }
        return f.string(from: next)
    }
}

import Foundation

/// Tasks and calendar events: the Life Engine's `tasks_*` and `calendar_events_*` operations, the same ones the assistant calls.
/// Nothing else in the app invents one, so what the screens show is what the assistant sees.
struct ItemsService {
    var api: LifeAPI

    enum Kind: String {
        case task, event
        var family: String { self == .task ? "tasks" : "calendar_events" }
    }

    /// What a person chooses on screen. A save replaces the item's fields wholesale, so an edit starts from `init(_ item:)`.
    struct Draft: Equatable {
        var title = ""
        var notes = ""
        var goalId: String?
        var at: Date?
        var minutes: Int?
        var timeZone = TimeZone.current.identifier
        var recurrence: Wire.Recurrence?
        var alertBeforeMinutes: Int?
        var isPriority = false

        init() {}
        init(_ item: Wire.Item) {
            title = item.title; notes = item.notes; goalId = item.goalId; at = item.at; minutes = item.minutes
            timeZone = item.timeZone; recurrence = item.recurrence; alertBeforeMinutes = item.alertBeforeMinutes; isPriority = item.isPriority
        }
    }

    /// The engine's create and update inputs are flat: the key (and for an update the id and version) beside the item's fields.
    private struct ItemIn: Encodable {
        var idempotencyKey: String; var id: String?; var expectedVersion: Int?
        var title: String; var notes: String; var goalId: String?; var at: Date?; var minutes: Int?
        var timeZone: String; var recurrence: Wire.Recurrence?; var alertBeforeMinutes: Int?; var isPriority: Bool
        init(_ d: Draft, key: String, id: String? = nil, version: Int? = nil) {
            idempotencyKey = key; self.id = id; expectedVersion = version
            title = d.title; notes = d.notes; goalId = d.goalId; at = d.at; minutes = d.minutes
            timeZone = d.timeZone; recurrence = d.recurrence; alertBeforeMinutes = d.alertBeforeMinutes; isPriority = d.isPriority
        }
    }
    private struct ListIn: Encodable { var status: String; var limit: Int; var goalId: String? }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }
    private struct CompleteIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var at: Date?; var done: Bool? }
    private struct SnoozeIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var until: Date }

    /// Open items soonest first, untimed last (done ones too with status "all"/"done"; events ignore the status).
    func list(_ kind: Kind, status: String = "open", limit: Int = 200, goalID: String? = nil) async throws -> [Wire.Item] {
        // Events have no status: the engine only takes one for tasks.
        let page: Wire.Page<Wire.Item> = try await api.call(kind.family + "_list", ListIn(status: status, limit: limit, goalId: goalID))
        return page.items
    }

    func create(_ kind: Kind, _ draft: Draft, key: String = UUID().uuidString) async throws -> Wire.Item {
        try await api.call(kind.family + "_create", ItemIn(draft, key: key))
    }

    func update(_ item: Wire.Item, _ draft: Draft) async throws -> Wire.Item {
        try await api.call((item.isTask ? "tasks" : "calendar_events") + "_update", ItemIn(draft, key: UUID().uuidString, id: item.id, version: item.version))
    }

    /// Done, or (with `done: false`) not done after all. A repeating task is done one occurrence at a time: pass the occurrence's time.
    func complete(_ item: Wire.Item, at: Date? = nil, done: Bool = true) async throws -> Wire.Item {
        try await api.call("tasks_complete", CompleteIn(idempotencyKey: UUID().uuidString, id: item.id, expectedVersion: item.version, at: at, done: done ? nil : false))
    }

    func snooze(_ item: Wire.Item, until: Date) async throws -> Wire.Item {
        try await api.call((item.isTask ? "tasks" : "calendar_events") + "_snooze", SnoozeIn(idempotencyKey: UUID().uuidString, id: item.id, expectedVersion: item.version, until: until))
    }

    func delete(_ item: Wire.Item) async throws {
        let _: Wire.Item = try await api.call((item.isTask ? "tasks" : "calendar_events") + "_delete", EditIn(idempotencyKey: UUID().uuidString, id: item.id, expectedVersion: item.version))
    }

    private struct HistoryIn: Encodable { var id: String; var days: Int }
    /// How a repeating task is going: its recent days, consistency and runs.
    func history(_ task: Wire.Item, days: Int = 30) async throws -> Wire.TaskHistory {
        try await api.call("tasks_history", HistoryIn(id: task.id, days: days))
    }
}

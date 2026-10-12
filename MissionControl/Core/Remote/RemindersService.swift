import Foundation

/// The one way a reminder comes to exist in the app: the Life Engine's `reminders_*` operations, the same ones the agent
/// calls as tools. Nothing here (and nothing else in the app) invents a reminder or a notification of its own; local
/// notifications are derived from what this service returns.
struct RemindersService {
    var api: LifeAPI

    private struct ListIn: Encodable { var status = "pending"; var limit = 200 }
    private struct CreateIn: Encodable {
        var idempotencyKey: String; var title: String; var notes: String?; var dueAt: Date?
        var timeZone: String; var recurrence: Wire.Recurrence?; var source = "user"
    }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }
    private struct SnoozeIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var until: Date }

    /// Pending reminders, soonest first (undated last).
    func pending() async throws -> [Wire.Reminder] {
        let page: Wire.Page<Wire.Reminder> = try await api.call("reminders_list", ListIn())
        return page.items
    }

    /// `key` identifies this intent: resending the same one (a retry after a lost response) never makes a second reminder.
    func create(title: String, notes: String? = nil, due: Date?, recurrence: Wire.Recurrence? = nil,
                timeZone: String = TimeZone.current.identifier, key: String = UUID().uuidString) async throws -> Wire.Reminder {
        try await api.call("reminders_create", CreateIn(idempotencyKey: key, title: title, notes: notes?.isEmpty == true ? nil : notes,
                                                        dueAt: due, timeZone: timeZone, recurrence: recurrence))
    }

    func complete(_ r: Wire.Reminder) async throws -> Wire.Reminder {
        try await api.call("reminders_complete", EditIn(idempotencyKey: UUID().uuidString, id: r.id, expectedVersion: r.version))
    }

    func snooze(_ r: Wire.Reminder, until: Date) async throws -> Wire.Reminder {
        try await api.call("reminders_snooze", SnoozeIn(idempotencyKey: UUID().uuidString, id: r.id, expectedVersion: r.version, until: until))
    }

    func delete(_ r: Wire.Reminder) async throws {
        let _: Wire.Reminder = try await api.call("reminders_delete", EditIn(idempotencyKey: UUID().uuidString, id: r.id, expectedVersion: r.version))
    }
}

import Foundation

/// Routines are the Life Engine's `routines_*` operations, the same ones the agent calls. A routine is done on a day when its
/// count reaches its target; nothing here is invented on the phone.
struct RoutinesService {
    var api: LifeAPI

    private struct Empty: Encodable {}
    private struct LogIn: Encodable { var idempotencyKey: String; var routineId: String; var delta: Int; var variant: String; var day: String? }
    private struct HistoryIn: Encodable { var routineId: String; var days: Int }
    private struct CreateIn: Encodable {
        var idempotencyKey: String; var title: String; var minutes: Int; var shortTitle: String; var shortMinutes: Int
        var weekdays: [Int]; var targetPerDay: Int; var nudges: [Wire.Nudge]; var timeZone: String
    }
    private struct NudgeIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var at: String; var message: String? }
    private struct NudgeOutIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var at: String }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }

    /// Every active routine with today's count.
    func status() async throws -> [Wire.RoutineStatus] {
        let result: Wire.RoutinesStatus = try await api.call("routines_status", Empty())
        return result.items
    }

    /// One more time (or `-1` to take one back). Returns the routine as it now stands, so the screen can update at once.
    /// `day` (yyyy-MM-dd) records or takes back one on a past day; omitted is today.
    func log(_ id: String, delta: Int = 1, short: Bool = false, day: String? = nil) async throws -> Wire.RoutineStatus {
        try await api.call("routines_log", LogIn(idempotencyKey: UUID().uuidString, routineId: id, delta: delta, variant: short ? "short" : "full", day: day))
    }

    func history(_ id: String, days: Int = 30) async throws -> Wire.RoutineHistory {
        try await api.call("routines_history", HistoryIn(routineId: id, days: days))
    }

    func create(title: String, targetPerDay: Int, nudgeTimes: [String], weekdays: [Int], shortTitle: String, minutes: Int, shortMinutes: Int,
                timeZone: String = TimeZone.current.identifier, key: String = UUID().uuidString) async throws -> Wire.Routine {
        try await api.call("routines_create", CreateIn(idempotencyKey: key, title: title, minutes: minutes,
                                                       shortTitle: shortTitle, shortMinutes: shortMinutes,
                                                       weekdays: weekdays, targetPerDay: targetPerDay,
                                                       nudges: nudgeTimes.map { Wire.Nudge(at: $0, message: nil) }, timeZone: timeZone))
    }

    /// Adds a nudge to a routine, or re-words the one already at that time.
    func setNudge(_ r: Wire.Routine, at: String, message: String) async throws -> Wire.Routine {
        try await api.call("nudges_set", NudgeIn(idempotencyKey: UUID().uuidString, id: r.id, expectedVersion: r.version, at: at, message: message))
    }

    func removeNudge(_ r: Wire.Routine, at: String) async throws -> Wire.Routine {
        try await api.call("nudges_remove", NudgeOutIn(idempotencyKey: UUID().uuidString, id: r.id, expectedVersion: r.version, at: at))
    }

    func delete(_ r: Wire.Routine) async throws {
        let _: Wire.Routine = try await api.call("routines_delete", EditIn(idempotencyKey: UUID().uuidString, id: r.id, expectedVersion: r.version))
    }
}

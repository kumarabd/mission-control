import Foundation

/// The person's time zone lives in the Life Engine, because every day-based answer (today's cues and plan, closing the day) uses
/// it. The phone knows where it is; this tells the engine, so "today" is today where you are.
struct SettingsService {
    var api: LifeAPI

    private struct Empty: Encodable {}
    private struct SetIn: Encodable { var idempotencyKey: String; var expectedVersion: Int; var timeZone: String; var workStart: String; var workEnd: String }

    func get() async throws -> Wire.Settings { try await api.call("settings_get", Empty()) }

    /// Sets the engine's time zone to the phone's when they differ. Returns whether it changed anything.
    @discardableResult
    func matchTimeZone(to zone: String = TimeZone.current.identifier) async throws -> Bool {
        let current = try await get()
        guard current.timeZone != zone else { return false }
        let _: Wire.Settings = try await api.call("settings_set", SetIn(idempotencyKey: UUID().uuidString, expectedVersion: current.version, timeZone: zone,
                                                                         workStart: current.workStart, workEnd: current.workEnd))
        return true
    }
}

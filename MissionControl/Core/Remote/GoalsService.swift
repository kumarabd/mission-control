import Foundation

/// Shared goal data and the approved native tracker contract.
struct GoalsService {
    var api: LifeAPI

    private struct ListIn: Encodable { var limit = 100 }
    private struct StepDoneIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int; var done: Bool }

    /// Active goals with their steps, progress and next step.
    func list() async throws -> [Wire.Goal] {
        let page: Wire.Page<Wire.Goal> = try await api.call("goals_list", ListIn())
        return page.items
    }

    /// Finishes a one-off milestone from Today or an approved tracker module.
    func completeStep(id: String, version: Int, key: String = UUID().uuidString) async throws {
        let _: Wire.Step = try await api.call("steps_complete", StepDoneIn(idempotencyKey: key, id: id, expectedVersion: version, done: true))
    }

    private struct TrackerIn: Encodable { var goalId: String; var catalogId: String }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }
    struct MeasurementIn: Encodable {
        var idempotencyKey: String
        var goalId: String?; var metricId: String?; var expectedTrackerRevision: Int?
        var id: String?; var expectedVersion: Int?
        var value: Double; var measuredAt: Date?; var notes: String
    }
    func tracker(goalID: String, catalog: String) async throws -> Wire.TrackerState {
        try await api.call("goals_tracker_get", TrackerIn(goalId: goalID, catalogId: catalog))
    }
    func apply(_ proposal: Wire.TrackerProposal, key: String) async throws {
        let _: Wire.Goal = try await api.call("goals_tracker_apply", EditIn(idempotencyKey: key, id: proposal.id, expectedVersion: proposal.version))
    }
    func discard(_ proposal: Wire.TrackerProposal, key: String) async throws {
        let _: Wire.TrackerProposal = try await api.call("goals_tracker_discard", EditIn(idempotencyKey: key, id: proposal.id, expectedVersion: proposal.version))
    }
    func saveMeasurement(_ input: MeasurementIn) async throws {
        let _: Wire.GoalMeasurement = try await api.call(input.id == nil ? "goal_measurements_record" : "goal_measurements_update", input)
    }
    func deleteMeasurement(_ measurement: Wire.GoalMeasurement, key: String) async throws {
        let _: Wire.GoalMeasurement = try await api.call("goal_measurements_delete", EditIn(idempotencyKey: key, id: measurement.id, expectedVersion: measurement.version))
    }
}

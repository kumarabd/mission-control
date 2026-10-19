import Foundation

/// Shared goal data and the native tracker contract: a goal's view, its recorded observations, and its data providers.
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

    private struct ViewIn: Encodable { var goalId: String; var catalogId: String }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }
    struct MeasurementIn: Encodable {
        var idempotencyKey: String
        var goalId: String?; var metricId: String?
        var id: String?; var expectedVersion: Int?
        var value: Double; var measuredAt: Date?; var notes: String
    }
    /// A goal's view for one client catalogue, with the observations recorded against its metrics.
    func viewState(goalID: String, catalog: String) async throws -> Wire.ViewState {
        try await api.call("views_state", ViewIn(goalId: goalID, catalogId: catalog))
    }
    /// Deletes a goal and what exists only because of it (its steps, view, measurements, reminders, notes and journal
    /// entries about it, and the routines no other goal uses). Returns how many of each kind went.
    func deleteGoal(_ goal: Wire.Goal, key: String = UUID().uuidString) async throws -> [String: Int] {
        struct Out: Decodable { var removed: [String: Int] }
        let out: Out = try await api.call("goals_delete", EditIn(idempotencyKey: key, id: goal.id, expectedVersion: goal.version))
        return out.removed
    }
    func saveMeasurement(_ input: MeasurementIn) async throws {
        let _: Wire.GoalMeasurement = try await api.call(input.id == nil ? "goal_measurements_record" : "goal_measurements_update", input)
    }
    func deleteMeasurement(_ measurement: Wire.GoalMeasurement, key: String) async throws {
        let _: Wire.GoalMeasurement = try await api.call("goal_measurements_delete", EditIn(idempotencyKey: key, id: measurement.id, expectedVersion: measurement.version))
    }
}

/// Reads a data provider's series through the router: `<router>/<provider>/api/v1/operations/series_get`.
struct ProviderService {
    var routerBaseURL: String
    var token: () async -> String?
    /// Tests substitute the network; nil is the real one.
    var transport: LifeAPI.Transport?

    private struct SeriesIn: Encodable { var series: String; var from: String; var to: String; var granularity: String }

    func series(provider: String, series: String, from: String, to: String, granularity: String = "day") async throws -> Wire.SeriesData {
        guard TrackerClient.isProviderID(provider) else {
            throw LifeError.engine(code: "invalid_input", message: "This tracker names a data source this app cannot reach.")
        }
        var api = LifeAPI(baseURL: routerBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/\(provider)/api/v1", token: token)
        if let transport { api.transport = transport }
        return try await api.call("series_get", SeriesIn(series: series, from: from, to: to, granularity: granularity))
    }
}

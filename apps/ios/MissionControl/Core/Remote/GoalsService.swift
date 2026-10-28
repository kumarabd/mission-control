import Foundation

/// Goals: the Life Engine's `goals_*` operations. A goal is made in conversation with the assistant; the app reads them,
/// and archives one the person is done with.
struct GoalsService {
    var api: LifeAPI

    private struct ListIn: Encodable { var limit = 200 }
    private struct EditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }

    func list() async throws -> [Wire.Goal] {
        let page: Wire.Page<Wire.Goal> = try await api.call("goals_list", ListIn())
        return page.items
    }

    func archive(_ goal: Wire.Goal) async throws {
        let _: Wire.Goal = try await api.call("goals_archive", EditIn(idempotencyKey: UUID().uuidString, id: goal.id, expectedVersion: goal.version))
    }
}

/// A day: the tasks and events that fall on it, one entry per occurrence, plus the open tasks still waiting from earlier days.
struct DayService {
    var api: LifeAPI

    private struct Empty: Encodable {}

    func today() async throws -> Wire.Day { try await api.call("day_get", Empty()) }
}

// MARK: Views. A view is its own construct, of a goal, a task or an event; the same calls serve all three.

extension GoalsService {
    private struct ViewIn: Encodable { var subjectKind: String; var subjectId: String; var catalogId: String }
    private struct MeasureEditIn: Encodable { var idempotencyKey: String; var id: String; var expectedVersion: Int }
    struct MeasurementIn: Encodable {
        var idempotencyKey: String
        var subjectKind: String?; var subjectId: String?; var metricId: String?
        var id: String?; var expectedVersion: Int?
        var value: Double; var measuredAt: Date?; var notes: String
    }
    /// A subject's view for one client catalogue, with the observations recorded against its metrics.
    func viewState(kind: String, id: String, catalog: String) async throws -> Wire.ViewState {
        try await api.call("views_state", ViewIn(subjectKind: kind, subjectId: id, catalogId: catalog))
    }
    func saveMeasurement(_ input: MeasurementIn) async throws {
        let _: Wire.Measurement = try await api.call(input.id == nil ? "measurements_record" : "measurements_update", input)
    }
    func deleteMeasurement(_ measurement: Wire.Measurement, key: String) async throws {
        let _: Wire.Measurement = try await api.call("measurements_delete", MeasureEditIn(idempotencyKey: key, id: measurement.id, expectedVersion: measurement.version))
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

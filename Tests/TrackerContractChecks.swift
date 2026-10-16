import Foundation

@main struct TrackerChecks {
    static func main() async throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        func decode<T: Decodable>(_ name: String, _ type: T.Type) throws -> T {
            try Wire.decoder.decode(type, from: Data(contentsOf: dir.appendingPathComponent(name + ".json")))
        }
        let catalog = TrackerClient.catalog(isPad: false)
        let goal = try decode("goal_tracker", Wire.Goal.self)
        let legacy = try decode("goal", Wire.Goal.self)
        let state = try decode("tracker_state", Wire.TrackerState.self)
        let proposal = try decode("tracker_proposal", Wire.TrackerProposal.self)
        let measurement = try decode("goal_measurement", Wire.GoalMeasurement.self)
        precondition(goal.trackerRevision == 1 && goal.tracker?.views.count == 2)
        precondition(legacy.tracker == nil && legacy.trackerRevision == nil)
        precondition(state.goalId == goal.id && state.observations(for: "distance").last == measurement)
        precondition(state.proposals.first == proposal && state.supportedView(catalog: catalog) != nil)
        precondition(state.supportedView(catalog: TrackerClient.catalog(isPad: true)) == nil)
        var unknown = state
        unknown.view?.sections[0].type = "remote_code"
        precondition(unknown.supportedView(catalog: catalog) == nil)
        unknown = state; unknown.view?.sections[0].metricId = "missing"
        precondition(unknown.supportedView(catalog: catalog) == nil)
        precondition(TrackerClient.number("2.5", locale: Locale(identifier: "en_US")) == 2.5)
        precondition(TrackerClient.number("2,5", locale: Locale(identifier: "fr_FR")) == 2.5)
        precondition(TrackerClient.number("2 kg") == nil && TrackerClient.number("NaN") == nil && TrackerClient.number("") == nil)
        precondition(state.metricDefinitions[0].accepts(0) && !state.metricDefinitions[0].accepts(-1))
        let fixedTime = Date(timeIntervalSince1970: 1_800_000_000)
        let api = LifeAPI(baseURL: "https://test.invalid/life/api/v1", token: { "test" }, transport: { request in
            let path = request.url!.lastPathComponent
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            precondition(body["idempotency_key"] as? String == "same-intent")
            switch path {
            case "goal_measurements_record":
                precondition(body["goal_id"] as? String == goal.id && body["metric_id"] as? String == "distance")
                precondition(body["expected_tracker_revision"] as? Int == 1 && body["id"] == nil)
                precondition(body["measured_at"] != nil && body["value"] as? Double == 2.5)
            case "goal_measurements_update":
                precondition(body["id"] as? String == measurement.id && body["expected_version"] as? Int == measurement.version)
                precondition(body["goal_id"] == nil && body["metric_id"] == nil && body["expected_tracker_revision"] == nil)
                precondition(body["measured_at"] == nil)
            case "goal_measurements_delete":
                precondition(body["id"] as? String == measurement.id && body["expected_version"] as? Int == measurement.version)
                precondition(body["value"] == nil)
            case "goals_tracker_apply", "goals_tracker_discard":
                precondition(body["id"] as? String == proposal.id && body["expected_version"] as? Int == proposal.version)
            default: preconditionFailure(path)
            }
            let fixture = path == "goals_tracker_apply" ? "goal_tracker" : (path == "goals_tracker_discard" ? "tracker_proposal" : "goal_measurement")
            return (try Data(contentsOf: dir.appendingPathComponent(fixture + ".json")), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let service = GoalsService(api: api)
        let input = GoalsService.MeasurementIn(idempotencyKey: "same-intent", goalId: goal.id, metricId: "distance", expectedTrackerRevision: 1, value: 2.5, measuredAt: fixedTime, notes: "Recorded")
        try await service.saveMeasurement(input)
        try await service.saveMeasurement(input)
        try await service.saveMeasurement(.init(idempotencyKey: "same-intent", id: measurement.id, expectedVersion: measurement.version, value: 2.5, measuredAt: nil, notes: "Correction"))
        try await service.deleteMeasurement(measurement, key: "same-intent")
        try await service.apply(proposal, key: "same-intent")
        try await service.discard(proposal, key: "same-intent")
        print("Tracker contract, rendering guards and request checks passed")
    }
}

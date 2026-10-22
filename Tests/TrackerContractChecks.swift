import Foundation

@main struct TrackerChecks {
    static func main() async throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        func decode<T: Decodable>(_ name: String, _ type: T.Type) throws -> T {
            try Wire.decoder.decode(type, from: Data(contentsOf: dir.appendingPathComponent(name + ".json")))
        }
        let catalog = TrackerClient.catalog
        let goal = try decode("goal", Wire.Goal.self)
        let view = try decode("view", Wire.SubjectView.self)
        let state = try decode("view_state", Wire.ViewState.self)
        let measurement = try decode("measurement", Wire.Measurement.self)

        // The contract: a view is a manifest of blocks of a subject (a goal, a task or an event), never inlining the records it shows.
        precondition(!goal.id.isEmpty && !goal.title.isEmpty && goal.progress.total >= 0)
        precondition(state.subjectKind == "goal" && state.subjectId == view.subjectId && state.view == view && view.subjectKind == "goal")
        precondition(state.observations(for: "distance").last == measurement && measurement.subjectKind == "goal")
        precondition(view.metrics.first { $0.id == "distance" }?.source == nil && view.metrics.first { $0.id == "distance" }?.taskId == nil)
        precondition(state.view(catalog: catalog) != nil)
        precondition(state.view(catalog: "another-kit.v1") == nil)
        precondition(view.blocks.allSatisfy { view.supports($0) })
        precondition(view.blocks.contains { $0.kind == "tasks" } && view.blocks.contains { $0.kind == "log" })

        // Rendering guards: an unknown or unmatched block is unsupported on its own, never the whole view.
        var odd = view
        odd.pages[0].sections[0].blocks[0].kind = "remote_code"
        precondition(!odd.supports(odd.pages[0].sections[0].blocks[0]) && odd.supports(odd.pages[0].sections[0].blocks[1]))
        odd = view
        let log = odd.blocks.firstIndex { $0.kind == "log" }!
        odd.pages[0].sections[0].blocks[log].metric = "missing"
        precondition(!odd.supports(odd.pages[0].sections[0].blocks[log]))
        var linkView = view
        linkView.pages[0].sections[0].blocks[0] = Wire.ViewBlock(id: "src", kind: "link", url: "https://example.com")
        precondition(linkView.supports(linkView.pages[0].sections[0].blocks[0]))
        for bad in ["javascript:alert(1)", "data:text/html,x", "file:///etc/passwd", "not a url", ""] {
            linkView.pages[0].sections[0].blocks[0].url = bad
            precondition(!linkView.supports(linkView.pages[0].sections[0].blocks[0]), bad)
        }
        var empty = state; empty.view?.pages = []
        precondition(empty.view(catalog: catalog) == nil)

        precondition(TrackerClient.link("https://example.com/a?b=1")?.host == "example.com" && TrackerClient.link("http://example.com") != nil)
        precondition(TrackerClient.link("ftp://example.com") == nil && TrackerClient.link(nil) == nil)
        precondition(TrackerClient.isProviderID("finance") && TrackerClient.isProviderID("body_data"))
        for bad in ["../life", "finance/../life", "Finance", "a b", "", String(repeating: "x", count: 65), "1finance"] { precondition(!TrackerClient.isProviderID(bad), bad) }
        precondition(TrackerClient.providerLabel("finance") == "Finance" && TrackerClient.providerLabel("body_data") == "Body data")
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_792_000_000) // 2026-10-14T18:13:20Z
        let range = TrackerClient.seriesRange(days: 90, now: now, calendar: utc)
        precondition(range.to == "2026-10-14" && range.from == "2026-07-16", "\(range)")
        precondition(TrackerClient.day("2026-10-14", calendar: utc).map { utc.component(.hour, from: $0) } == 12 && TrackerClient.day("nonsense") == nil)

        precondition(TrackerClient.number("2.5", locale: Locale(identifier: "en_US")) == 2.5)
        precondition(TrackerClient.number("2,5", locale: Locale(identifier: "fr_FR")) == 2.5)
        precondition(TrackerClient.number("2 kg") == nil && TrackerClient.number("NaN") == nil && TrackerClient.number("") == nil)
        let distance = state.metricDefinitions.first { $0.id == "distance" }!
        precondition(distance.accepts(0))

        // Requests.
        let fixedTime = Date(timeIntervalSince1970: 1_800_000_000)
        let api = LifeAPI(baseURL: "https://test.invalid/life/api/v1", token: { "test" }, transport: { request in
            let path = request.url!.lastPathComponent
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            switch path {
            case "views_state":
                precondition(body["subject_kind"] as? String == "goal" && body["subject_id"] as? String == view.subjectId && body["catalog_id"] as? String == catalog && body.count == 3)
            case "measurements_record":
                precondition(body["idempotency_key"] as? String == "same-intent")
                precondition(body["subject_kind"] as? String == "goal" && body["subject_id"] as? String == view.subjectId && body["metric_id"] as? String == "distance")
                precondition(body["id"] == nil)
                precondition(body["measured_at"] != nil && body["value"] as? Double == 2.5)
            case "measurements_update":
                precondition(body["idempotency_key"] as? String == "same-intent")
                precondition(body["id"] as? String == measurement.id && body["expected_version"] as? Int == measurement.version)
                precondition(body["subject_kind"] == nil && body["subject_id"] == nil && body["metric_id"] == nil)
                precondition(body["measured_at"] == nil)
            case "measurements_delete":
                precondition(body["idempotency_key"] as? String == "same-intent")
                precondition(body["id"] as? String == measurement.id && body["expected_version"] as? Int == measurement.version)
                precondition(body["value"] == nil)
            default: preconditionFailure(path)
            }
            let fixture = path == "views_state" ? "view_state" : "measurement"
            return (try Data(contentsOf: dir.appendingPathComponent(fixture + ".json")), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let service = GoalsService(api: api)
        let opened = try await service.viewState(kind: "goal", id: view.subjectId, catalog: catalog)
        precondition(opened == state)
        let input = GoalsService.MeasurementIn(idempotencyKey: "same-intent", subjectKind: "goal", subjectId: view.subjectId, metricId: "distance", value: 2.5, measuredAt: fixedTime, notes: "Recorded")
        try await service.saveMeasurement(input)
        try await service.saveMeasurement(input)
        try await service.saveMeasurement(.init(idempotencyKey: "same-intent", id: measurement.id, expectedVersion: measurement.version, value: 2.5, measuredAt: nil, notes: "Correction"))
        try await service.deleteMeasurement(measurement, key: "same-intent")

        // A provider is reached at its own router prefix, and a malformed id never becomes a URL.
        var seen: [URL] = []
        let provider = ProviderService(routerBaseURL: "https://router.invalid/", token: { "test" }, transport: { request in
            seen.append(request.url!)
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            precondition(body["series"] as? String == "spend_total_usd" && body["from"] as? String == "2026-07-16" && body["to"] as? String == "2026-10-14" && body["granularity"] as? String == "day")
            let answer = #"{"provider":"finance","series":"spend_total_usd","unit":"USD","granularity":"day","points":[{"t":"2026-10-04","value":100},{"t":"2026-10-05","value":-20}]}"#
            return (Data(answer.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let data = try await provider.series(provider: "finance", series: "spend_total_usd", from: range.from, to: range.to)
        precondition(seen.map(\.absoluteString) == ["https://router.invalid/finance/api/v1/operations/series_get"])
        precondition(data.unit == "USD" && data.points == [.init(t: "2026-10-04", value: 100), .init(t: "2026-10-05", value: -20)])
        do {
            _ = try await provider.series(provider: "../life", series: "x", from: "2026-01-01", to: "2026-01-02")
            preconditionFailure("a malformed provider id must be refused")
        } catch LifeError.engine(let code, _) { precondition(code == "invalid_input") }
        precondition(seen.count == 1, "a refused provider id must not reach the network")
        let gone = ProviderService(routerBaseURL: "https://router.invalid", token: { "test" }, transport: { request in
            (Data(#"{"error":{"code":"not_found","message":"That series does not exist; read series_catalog"}}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        })
        do { _ = try await gone.series(provider: "finance", series: "spend_cat_deadbeef_usd", from: "2026-01-01", to: "2026-01-02"); preconditionFailure("not_found expected") }
        catch LifeError.engine(let code, _) { precondition(code == "not_found") }
        print("Tracker contract, rendering guards, provider reads and request checks passed")
    }
}

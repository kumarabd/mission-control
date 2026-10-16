import Foundation

@main
struct ModelsChecks {
    @MainActor static func main() async throws {
        // tiers() decodes the real envelope: snake_case "llm_tiers" around camelCase tier objects, plus mode and
        // the per-tier custom flag. Plain JSONDecoder(), so the inner keys match the property names as they are.
        let listJSON = Data("""
        {"mode": "custom", "llm_tiers": {
          "fast": {"provider": "openai", "model": "gpt-4o-mini", "baseURL": "https://api.example.com/v1", "hasKey": true, "custom": true},
          "anthropic-tier": {"provider": "anthropic", "model": "claude-sonnet-4-5", "baseURL": "", "hasKey": false, "custom": false}}}
        """.utf8)
        let listAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/llm" && request.url?.query == nil && request.httpMethod == "GET")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            return (listJSON, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let models = try await listAPI.tiers()
        precondition(models.mode == "custom", "a server that sends a mode gets the control; this one is custom")
        precondition(models.tiers.count == 2)
        precondition(models.tiers["fast"]?.provider == "openai" && models.tiers["fast"]?.model == "gpt-4o-mini")
        precondition(models.tiers["fast"]?.baseURL == "https://api.example.com/v1")
        precondition(models.tiers["fast"]?.hasKey == true && models.tiers["fast"]?.custom == true)
        precondition(models.tiers["anthropic-tier"]?.custom == false && models.tiers["anthropic-tier"]?.hasKey == false)

        // A deployment older than the platform/own split omits "mode" and "custom" entirely. It must not throw, its
        // tiers mean "the workspace's own", and mode stays nil — which is what tells the screen to hide the
        // platform/My own control rather than offer a revert that server would refuse.
        let legacyJSON = Data("""
        {"llm_tiers": {"medium": {"provider": "openai", "model": "gpt-4o-mini", "baseURL": "https://api.example.com/v1", "hasKey": false}}}
        """.utf8)
        let legacyAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            (legacyJSON, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let legacy = try await legacyAPI.tiers()
        precondition(legacy.mode == nil, "no mode means no mode control")
        precondition(legacy.tiers["medium"]?.custom == true && legacy.tiers["medium"]?.hasKey == false)

        // update(tiers:) encodes the real {"llm_tiers": {tier: {provider, model, apiKey, baseURL}}} body and
        // returns the run to poll.
        var tiersBody: [String: Any] = [:]
        let acceptedJSON = Data(#"{"status": "accepted", "run_id": "run-42"}"#.utf8)
        let updateAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/llm" && request.httpMethod == "PUT")
            precondition(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            tiersBody = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
            return (acceptedJSON, HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!)
        })
        let runID = try await updateAPI.update(tiers: [
            "medium": ModelsAPI.TierInput(provider: "anthropic", model: "claude-sonnet-4-5", apiKey: "sk-typed", baseURL: ""),
        ])
        precondition(runID == "run-42")
        let sentTiers = tiersBody["llm_tiers"] as? [String: Any]
        let sentMedium = sentTiers?["medium"] as? [String: Any]
        precondition(tiersBody.keys.count == 1 && sentTiers?.keys.count == 1)
        precondition(sentMedium?["provider"] as? String == "anthropic")
        precondition(sentMedium?["model"] as? String == "claude-sonnet-4-5")
        precondition(sentMedium?["apiKey"] as? String == "sk-typed")
        precondition(sentMedium?["baseURL"] as? String == "") // anthropic may leave it empty

        // usePlatform() is the revert: a mode change, not a tier edit — and an older answer without a run id is
        // nil rather than an error.
        var platformBody: [String: Any] = [:]
        let platformAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/llm" && request.httpMethod == "PUT")
            platformBody = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
            return (Data(#"{"status": "accepted"}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!)
        })
        let platformRunID = try await platformAPI.usePlatform()
        precondition(platformRunID == nil)
        precondition(platformBody["mode"] as? String == "platform" && platformBody["llm_tiers"] == nil)

        // The router's plain-string {"error": "..."} is what reaches the screen — a 409 reads as its own
        // sentence, not as a status code.
        let conflictAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            (Data(#"{"error": "a model change is already in progress"}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!)
        })
        do {
            _ = try await conflictAPI.usePlatform()
            preconditionFailure("expected an error")
        } catch let error as ModelsError {
            guard case .server(let status, let message) = error else { preconditionFailure("expected .server") }
            precondition(status == 409 && message == "a model change is already in progress")
        }

        // So does a validation 400, classified as .server with that exact message rather than Life's
        // {"error":{"code","message"}} envelope.
        let invalidAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            (Data(#"{"error": "LLM tier \"fast\" needs a model and base URL"}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        })
        do {
            _ = try await invalidAPI.update(tiers: [:])
            preconditionFailure("expected an error")
        } catch let error as ModelsError {
            guard case .server(let status, let message) = error else { preconditionFailure("expected .server") }
            precondition(status == 400 && message == #"LLM tier "fast" needs a model and base URL"#)
        }

        // The 404 "no model update found" is a state — nothing has run — not a failure.
        let nothingAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/llm/update")
            return (Data(#"{"error": "no model update found"}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        })
        let nothing = try await nothingAPI.updateStatus(runID: nil)
        precondition(nothing == nil)

        // With a run id the status is read for that run; without one the latest run is still reported (the path
        // that existed before run ids did).
        let statusJSON = Data("""
        {"status": "running", "run_id": "run-42", "steps": [{"step": "HelmUpdateLLM", "status": "running", "message": "upgrading"}]}
        """.utf8)
        let statusAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/llm/update" && request.httpMethod == "GET")
            precondition(request.url?.query == "run_id=run-42")
            return (statusJSON, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let status = try await statusAPI.updateStatus(runID: "run-42")
        precondition(status?.status == "running" && status?.runID == "run-42")
        precondition(status?.steps.count == 1 && status?.steps.first?.step == "HelmUpdateLLM")

        let latestAPI = ModelsAPI(baseURL: "https://test.invalid", token: { "test-token" }, transport: { request in
            precondition(request.url?.path == "/llm/update" && request.url?.query == nil)
            return (Data(#"{"status": "completed", "run_id": "run-41", "steps": []}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let latest = try await latestAPI.updateStatus(runID: nil)
        precondition(latest?.status == "completed" && latest?.runID == "run-41" && latest?.steps.isEmpty == true)

        // A missing token fails fast with .unauthorized and never reaches the network.
        let noTokenAPI = ModelsAPI(baseURL: "https://test.invalid", token: { nil }, transport: { _ in
            preconditionFailure("should not reach the network with no token")
        })
        do {
            _ = try await noTokenAPI.tiers()
            preconditionFailure("expected an error")
        } catch let error as ModelsError {
            precondition(error == .unauthorized)
        }

        print("ModelsChecks passed")
    }
}

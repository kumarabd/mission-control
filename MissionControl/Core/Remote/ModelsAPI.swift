import Foundation

/// What a call to the router's `/llm` family did not produce a result for. The router's handlers answer failures
/// as `{"error": "<string>"}` (`writeJSONError`), not the Life Engine's `{"error":{"code","message"}}` envelope —
/// so this does not reuse `LifeError`/`LifeAPI.classify`.
enum ModelsError: Error, Equatable {
    case unauthorized
    case server(status: Int, message: String)
}

/// A typed client for the router's top-level model endpoints — `GET /llm`, `PUT /llm`, `GET /llm/update`
/// (`router/internal/core/llm.go`). Mirrors `agent-web/src/lib/onboarding.ts`'s `getLLM`/`updateLLM`/
/// `getLLMUpdateStatus`. The router root is this client's whole base URL: no prefix, unlike `/connections`
/// or `/gateway`.
///
/// Deliberately does NOT reuse `Wire.decoder`: the envelope is snake_case (`llm_tiers`) while the tier objects
/// inside it are camelCase (`baseURL`, `hasKey`, `custom`), so `.convertFromSnakeCase` would rewrite keys the
/// property names already match. Plain `JSONDecoder()`, explicit keys only on the envelope.
struct ModelsAPI {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)

    var baseURL: String
    var token: () async throws -> String?
    var transport: Transport = ModelsAPI.urlSession

    /// `mode` and `custom` are absent on deployments older than the platform/own split, and `mode` stays optional
    /// rather than defaulting: a server that sends no mode cannot accept one either (its PUT ignores the field and
    /// then refuses a tiers-less body), so the screen hides the choice instead of offering a control that would fail.
    /// A tier with no `custom` meant "the workspace's own" before the split, which is what `true` says now.
    struct Models: Decodable, Equatable {
        var mode: String?
        var tiers: [String: TierView]

        enum CodingKeys: String, CodingKey { case mode, tiers = "llm_tiers" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mode = try? c.decode(String.self, forKey: .mode)
            tiers = (try? c.decode([String: TierView].self, forKey: .tiers)) ?? [:]
        }
    }

    /// One tier as the server reports it: never the key itself, only whether one is stored.
    struct TierView: Decodable, Equatable {
        var provider: String
        var model: String
        var baseURL: String
        var hasKey: Bool
        var custom: Bool

        enum CodingKeys: String, CodingKey { case provider, model, baseURL, hasKey, custom }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            provider = (try? c.decode(String.self, forKey: .provider)) ?? ""
            model = (try? c.decode(String.self, forKey: .model)) ?? ""
            baseURL = (try? c.decode(String.self, forKey: .baseURL)) ?? ""
            hasKey = (try? c.decode(Bool.self, forKey: .hasKey)) ?? false
            custom = (try? c.decode(Bool.self, forKey: .custom)) ?? true
        }
    }

    /// What one tier is being set to. A blank `apiKey` keeps whatever the server already has stored.
    struct TierInput: Encodable, Equatable {
        var provider: String
        var model: String
        var apiKey: String
        var baseURL: String
    }

    /// The redeploy's progress. `steps` is the workflow's own log, newest last; only `status` and `error` drive
    /// the screen.
    struct UpdateStatus: Decodable, Equatable {
        var status: String
        var runID: String?
        var error: String?
        var steps: [Step]

        struct Step: Decodable, Equatable {
            var step: String
            var status: String
            var message: String?

            enum CodingKeys: String, CodingKey { case step, status, message }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                step = (try? c.decode(String.self, forKey: .step)) ?? ""
                status = (try? c.decode(String.self, forKey: .status)) ?? ""
                message = try? c.decode(String.self, forKey: .message)
            }
        }

        enum CodingKeys: String, CodingKey { case status, error, steps, runID = "run_id" }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            status = (try? c.decode(String.self, forKey: .status)) ?? ""
            runID = try? c.decode(String.self, forKey: .runID)
            error = try? c.decode(String.self, forKey: .error)
            steps = (try? c.decode([Step].self, forKey: .steps)) ?? []
        }
    }

    private struct Accepted: Decodable { var runID: String?; enum CodingKeys: String, CodingKey { case runID = "run_id" } }

    func tiers() async throws -> Models {
        try JSONDecoder().decode(Models.self, from: try await request("GET", "/llm"))
    }

    /// Starts the redeploy and returns the run to poll. Older deployments answer without a run id.
    func update(tiers: [String: TierInput]) async throws -> String? {
        struct Body: Encodable { var llmTiers: [String: TierInput]; enum CodingKeys: String, CodingKey { case llmTiers = "llm_tiers" } }
        return try await start("PUT", "/llm", body: try JSONEncoder().encode(Body(llmTiers: tiers)))
    }

    /// Reverts every tier to Mission Control's own models — a mode change, not a tier edit.
    func usePlatform() async throws -> String? {
        struct Body: Encodable { var mode: String }
        return try await start("PUT", "/llm", body: try JSONEncoder().encode(Body(mode: "platform")))
    }

    /// `nil` is the 404 "no model update found": nothing has run, which is a state, not a failure. Without a
    /// `runID` this reports the latest run, so a caller that never saw one still gets an answer.
    func updateStatus(runID: String? = nil) async throws -> UpdateStatus? {
        let query = runID.map { "?run_id=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" } ?? ""
        do {
            return try JSONDecoder().decode(UpdateStatus.self, from: try await request("GET", "/llm/update" + query))
        } catch ModelsError.server(let status, _) where status == 404 {
            return nil
        }
    }

    private func start(_ method: String, _ path: String, body: Data) async throws -> String? {
        let data = try await request(method, path, body: body)
        return (try? JSONDecoder().decode(Accepted.self, from: data))?.runID
    }

    private func request(_ method: String, _ path: String, body: Data? = nil) async throws -> Data {
        guard let bearer = try await token() else { throw ModelsError.unauthorized }
        guard let url = URL(string: baseURL + path) else { throw ModelsError.server(status: 0, message: "bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport(req)
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 { throw ModelsError.unauthorized }
            throw ModelsError.server(status: response.statusCode, message: Self.errorMessage(data) ?? String(decoding: data, as: UTF8.self))
        }
        return data
    }

    /// Same reading as `LiveOnboardingAPI.errorMessage` (`MissionControl/Core/Onboarding/OnboardingModel.swift`):
    /// the router's `{"error": "<string>"}`, tolerating the object form too. Duplicated rather than shared
    /// because those types are `private` to onboarding and this client compiles on its own.
    static func errorMessage(_ data: Data) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return ((o["error"] as? [String: Any])?["message"] ?? o["message"] ?? o["error"]) as? String
    }

    private static func urlSession(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

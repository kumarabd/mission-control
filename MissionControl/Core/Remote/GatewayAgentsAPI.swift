import Foundation

/// What a call to the Gateway's agent registry did not produce a result for. The Go handlers
/// (`gateway/internal/agents/api.go`) answer failures as a plain-text body via `http.Error`, not the Life Engine's
/// `{"error":{"code","message"}}` envelope — so this does not reuse `LifeError`/`LifeAPI.classify`.
enum GatewayAgentsError: Error, Equatable {
    case unauthorized
    case server(status: Int, message: String)
}

/// A typed client for the Gateway's agent registry CRUD — `POST/GET /agents`, `PATCH /agents/{agent_id}`
/// (`gateway/internal/agents`). Mirrors `LifeAPI`'s shape.
///
/// Deliberately does NOT reuse `Wire.decoder`/`Wire.encoder`: `.convertFromSnakeCase` transforms the JSON
/// document's own keys ("agent_id" -> "agentId") before any lookup happens, regardless of whether the target
/// type has explicit `CodingKeys` — so an explicit `case agentID = "agent_id"` never matches (the document,
/// post-conversion, no longer has a literal "agent_id" key to find). Confirmed by actually running
/// `GatewayAgentsChecks`, not assumed from reading `.convertFromSnakeCase`'s docs. Using literal key matching
/// here (the default, no key strategy set) plus explicit `CodingKeys` is simpler than renaming every property
/// to whatever the strategy happens to produce (`avatarUrl`, not the idiomatic `avatarURL`).
struct GatewayAgentsAPI {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)

    var baseURL: String
    var token: () async throws -> String?
    var transport: Transport = GatewayAgentsAPI.urlSession

    /// RFC 3339, with or without fractional seconds — same two-formatter fallback as `Wire.decoder`/
    /// `Wire.encoder` (duplicated, not shared: those are `private` to `Wire`, and this type intentionally
    /// doesn't share its key-decoding behavior, only wants the same date format).
    private static let withFractionFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plainFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = withFractionFormatter.date(from: s) ?? plainFormatter.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not an RFC 3339 timestamp: \(s)"))
        }
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(plainFormatter.string(from: date))
        }
        return e
    }()

    struct Agent: Codable, Identifiable, Equatable {
        var agentID: String
        var displayName: String
        var avatarURL: String?
        var description: String
        var persona: String
        var status: String
        var createdAt: Date
        var id: String { agentID }

        enum CodingKeys: String, CodingKey {
            case agentID = "agent_id"
            case displayName = "display_name"
            case avatarURL = "avatar_url"
            case description, persona, status
            case createdAt = "created_at"
        }
    }

    private struct AgentsListResponse: Decodable { var agents: [Agent] }

    func listAgents() async throws -> [Agent] {
        let data = try await request("GET", "/agents")
        return try Self.decoder.decode(AgentsListResponse.self, from: data).agents
    }

    func createAgent(displayName: String, persona: String, description: String, avatarURL: String?) async throws -> Agent {
        struct Body: Encodable {
            var displayName: String; var persona: String; var description: String; var avatarURL: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name", persona, description, avatarURL = "avatar_url" }
        }
        let body = Body(displayName: displayName, persona: persona, description: description, avatarURL: avatarURL)
        let data = try await request("POST", "/agents", body: try Self.encoder.encode(body))
        return try Self.decoder.decode(Agent.self, from: data)
    }

    /// Partial update — a nil parameter leaves that field unchanged (the server's own PATCH semantics).
    func updateAgent(
        _ id: String, displayName: String? = nil, persona: String? = nil, description: String? = nil,
        avatarURL: String? = nil, status: String? = nil
    ) async throws -> Agent {
        struct Body: Encodable {
            var displayName: String?; var persona: String?; var description: String?
            var avatarURL: String?; var status: String?
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name", persona, description, avatarURL = "avatar_url", status
            }
        }
        let body = Body(displayName: displayName, persona: persona, description: description, avatarURL: avatarURL, status: status)
        let data = try await request("PATCH", "/agents/\(id)", body: try Self.encoder.encode(body))
        return try Self.decoder.decode(Agent.self, from: data)
    }

    private func request(_ method: String, _ path: String, body: Data? = nil) async throws -> Data {
        guard let bearer = try await token() else { throw GatewayAgentsError.unauthorized }
        guard let url = URL(string: baseURL + path) else { throw GatewayAgentsError.server(status: 0, message: "bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport(req)
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 { throw GatewayAgentsError.unauthorized }
            throw GatewayAgentsError.server(status: response.statusCode, message: String(decoding: data, as: UTF8.self))
        }
        return data
    }

    private static func urlSession(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

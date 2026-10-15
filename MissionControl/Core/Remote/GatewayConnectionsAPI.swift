import Foundation

/// Client for the router's `/connections` prefix (`workflows/internal/router/core/proxy.go`) — a pure proxy onto
/// each tenant's own mcp-hub instance (`mcp-hub/src/mcp_hub/server.py`). Mirrors `agent-web/src/lib/gateway.ts`'s
/// `connectionsRequest` family: GET /api/catalog, POST/DELETE /api/connections, POST /{name}/authorize.
///
/// Deliberately separate from `GatewayAgentsAPI`'s base URL — connections moved off the Gateway entirely and
/// live at the router's own top-level `/connections` prefix, not something Gateway itself serves.
enum GatewayConnectionsError: Error, Equatable {
    case unauthorized
    case server(status: Int, message: String)
}

struct GatewayConnectionsAPI {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)

    var baseURL: String
    var token: () async throws -> String?
    var transport: Transport = GatewayConnectionsAPI.urlSession

    /// Matches `mcp-hub`'s own `GET /api/catalog` shape 1:1 — there is no intermediate desired/actual-state
    /// distinction. Connecting/disconnecting is immediate: mcp-hub either has the backend registered or it
    /// doesn't, so `state`/`toolCount` are only meaningful once `connected` is true.
    struct CatalogItem: Codable, Identifiable, Equatable {
        var name: String
        var displayName: String
        var description: String
        var authKind: String // "none" | "header" | "oauth"
        var oauthGrantType: String? // "authorization_code" | "client_credentials", only when authKind == "oauth"
        var origin: String? // "in-house" | "third-party"
        var shared: Bool?
        var tags: [String]?
        var connected: Bool
        var state: String? // "indexing" | "ready" | "needs_authorization" | "failed"
        var toolCount: Int?
        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name, description, origin, shared, tags, connected, state
            case displayName = "display_name"
            case authKind = "auth_kind"
            case oauthGrantType = "oauth_grant_type"
            case toolCount = "tool_count"
        }
    }

    struct ConnectSecrets {
        var token: String?
        var oauthClientID: String?
        var oauthClientSecret: String?
        var oauthScopes: String?
    }

    private struct CatalogResponse: Decodable { var items: [CatalogItem] }
    private struct AuthorizeResponse: Decodable { var authorizationURL: String; enum CodingKeys: String, CodingKey { case authorizationURL = "authorization_url" } }

    func listCatalog() async throws -> [CatalogItem] {
        let data = try await request("GET", "/api/catalog")
        return try JSONDecoder().decode(CatalogResponse.self, from: data).items
    }

    /// Re-connecting without re-supplying a secret keeps whatever is already stored (mcp-hub's own
    /// merge-on-update behavior) — callers don't need to re-enter a token/client_secret just to retry.
    func connect(name: String, secrets: ConnectSecrets? = nil) async throws -> CatalogItem {
        struct OAuthBody: Encodable { var clientID: String; var clientSecret: String; var scopes: String?
            enum CodingKeys: String, CodingKey { case clientID = "client_id", clientSecret = "client_secret", scopes } }
        struct Body: Encodable { var name: String; var token: String?; var oauth: OAuthBody? }
        let oauth: OAuthBody? = {
            guard let id = secrets?.oauthClientID, let secret = secrets?.oauthClientSecret, !id.isEmpty, !secret.isEmpty else { return nil }
            return OAuthBody(clientID: id, clientSecret: secret, scopes: secrets?.oauthScopes?.isEmpty == false ? secrets?.oauthScopes : nil)
        }()
        let body = Body(name: name, token: (secrets?.token?.isEmpty == false) ? secrets?.token : nil, oauth: oauth)
        let data = try await request("POST", "/api/connections", body: try JSONEncoder().encode(body))
        return try JSONDecoder().decode(CatalogItem.self, from: data)
    }

    func disconnect(name: String) async throws {
        _ = try await request("DELETE", "/api/connections/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)")
    }

    /// `authorization_code` OAuth backends: open the returned URL in `ASWebAuthenticationSession`, then refresh
    /// the catalog once it completes — the connection updates server-side via the callback, not a client POST.
    func authorize(name: String) async throws -> URL {
        let data = try await request("POST", "/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/authorize")
        let decoded = try JSONDecoder().decode(AuthorizeResponse.self, from: data)
        guard let url = URL(string: decoded.authorizationURL), url.scheme == "https" else {
            throw GatewayConnectionsError.server(status: 0, message: "invalid authorization URL")
        }
        return url
    }

    private func request(_ method: String, _ path: String, body: Data? = nil) async throws -> Data {
        guard let bearer = try await token() else { throw GatewayConnectionsError.unauthorized }
        guard let url = URL(string: baseURL + path) else { throw GatewayConnectionsError.server(status: 0, message: "bad URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport(req)
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 { throw GatewayConnectionsError.unauthorized }
            throw GatewayConnectionsError.server(status: response.statusCode, message: String(decoding: data, as: UTF8.self))
        }
        return data
    }

    private static func urlSession(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

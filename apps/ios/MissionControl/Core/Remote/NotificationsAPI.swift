import Foundation

/// What a call to the Gateway's notification inbox did not produce a result for. The Go handlers
/// (`gateway/internal/notify/api.go`) answer failures as a plain-text body via `http.Error`, not the Life Engine's
/// `{"error":{"code","message"}}` envelope — so this does not reuse `LifeError`/`LifeAPI.classify`.
enum NotificationsError: Error, Equatable {
    case unauthorized
    case server(status: Int, message: String)
}

/// A typed client for the Gateway's notification inbox — `GET /notifications`, `POST /notifications/{id}/read`,
/// `POST /notifications/read-all` (`gateway/internal/notify`). Mirrors `GatewayAgentsAPI`'s shape: literal
/// `CodingKeys` (not `Wire.decoder`, whose key strategy would defeat them), its own RFC 3339 decoder, its own error
/// type.
///
/// This is the history of what the assistant actually sent: one row per `life_notify`, including the ones a routine
/// nudge produced. The engine keeps no record of nudges that were considered and stayed silent, so nothing here can
/// show those.
struct NotificationsAPI {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)

    var baseURL: String                              // Config.routerBaseURL + "/gateway"
    var token: () async throws -> String?
    var transport: Transport = NotificationsAPI.urlSession

    struct Item: Identifiable, Equatable, Decodable {
        var id: String
        var source: String
        var kind: String
        var title: String
        var body: String
        var priority: String
        var link: Wire.Link?
        var sessionID: String?
        var createdAt: Date
        var readAt: Date?

        var isUnread: Bool { readAt == nil }

        enum CodingKeys: String, CodingKey {
            case id, source, kind, title, body, priority, link
            case sessionID = "session_id", createdAt = "created_at", readAt = "read_at"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            title = try c.decode(String.self, forKey: .title)
            source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
            kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
            body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
            priority = try c.decodeIfPresent(String.self, forKey: .priority) ?? "normal"
            sessionID = try c.decodeIfPresent(String.self, forKey: .sessionID)
            createdAt = try c.decode(Date.self, forKey: .createdAt)
            readAt = try c.decodeIfPresent(Date.self, forKey: .readAt)
            // A row whose link is malformed opens nothing, but must not fail the whole page: the store hands back
            // whatever JSON was written at notify time.
            link = (try? c.decodeIfPresent(Wire.Link.self, forKey: .link)) ?? nil
        }
    }

    struct Page: Decodable {
        var items: [Item]
        var unread: Int
        var nextBefore: String?

        enum CodingKeys: String, CodingKey { case items, unread, nextBefore = "next_before" }
    }

    /// One page of the inbox, newest first. `before` is a previous page's `next_before` passed back **verbatim** —
    /// the server compares it against the stored `created_at`, so reformatting it through a `Date` round-trip would
    /// change its precision and skip or repeat the boundary row.
    func page(before: String? = nil, limit: Int = 50) async throws -> Page {
        var components = URLComponents(string: baseURL + "/notifications")
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before { items.append(URLQueryItem(name: "before", value: before)) }
        components?.queryItems = items
        guard let url = components?.url else { throw NotificationsError.server(status: 0, message: "bad URL") }
        return try Self.decoder.decode(Page.self, from: try await request("GET", url))
    }

    /// `POST /notifications/{id}/read` answers 204 with no body, so the response is deliberately not decoded.
    func markRead(_ id: String) async throws {
        _ = try await request("POST", url("/notifications/\(id)/read"))
    }

    /// `POST /notifications/read-all` answers `{"marked": n}`.
    @discardableResult
    func markAllRead() async throws -> Int {
        struct Marked: Decodable { var marked: Int }
        let data = try await request("POST", url("/notifications/read-all"))
        return (try? Self.decoder.decode(Marked.self, from: data))?.marked ?? 0
    }

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw NotificationsError.server(status: 0, message: "bad URL") }
        return url
    }

    private func request(_ method: String, _ url: URL, body: Data? = nil) async throws -> Data {
        guard let bearer = try await token() else { throw NotificationsError.unauthorized }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport(req)
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 { throw NotificationsError.unauthorized }
            throw NotificationsError.server(status: response.statusCode, message: String(decoding: data, as: UTF8.self))
        }
        return data
    }

    private static let withFractionFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plainFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    /// RFC 3339, with or without fractional seconds — Postgres hands back microseconds, so both forms arrive.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = withFractionFormatter.date(from: s) ?? plainFormatter.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not an RFC 3339 timestamp: \(s)"))
        }
        return d
    }()

    private static func urlSession(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

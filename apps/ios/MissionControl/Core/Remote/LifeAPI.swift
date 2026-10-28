import Foundation

/// Why a call to the Life Engine did not produce a result. The caller decides what each means for the person; the
/// distinctions here are the ones that change what it should do.
enum LifeError: Error, Equatable {
    /// The session is missing or expired (401/403): sign in again.
    case unauthorized
    /// The router has no workspace for this person, or not yet one with this engine (404 `no_tenant`). Not an engine answer.
    case notProvisioned
    /// The engine understood and refused: `invalid_input`, `not_found`, `conflict`, `duplicate`, `too_large`.
    case engine(code: String, message: String)
    /// Offline, busy or restarting (network failure, 408/429/502/503/504, engine `busy`): the same request is safe to resend.
    case retry(String)
    /// The engine failed (500) or answered something unreadable.
    case server(String)
}

/// A typed client for `POST <router>/life/api/v1/operations/<name>`. Every write carries an idempotency key, so a retry
/// of the same intent never doubles it; edits carry the version the caller last read, so a stale edit is refused.
struct LifeAPI {
    typealias Transport = (URLRequest) async throws -> (Data, HTTPURLResponse)

    var baseURL: String
    var token: () async -> String?
    var transport: Transport = LifeAPI.urlSession

    func call<In: Encodable, Out: Decodable>(_ operation: String, _ input: In, timeout: TimeInterval = 30) async throws -> Out {
        guard let bearer = await token() else { throw LifeError.unauthorized }
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/operations/" + operation),
              let body = try? Wire.encoder.encode(input) else { throw LifeError.server("bad request") }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport(request) } catch { throw LifeError.retry("network error") }
        guard let error = Self.classify(status: response.statusCode, body: data) else {
            do { return try Wire.decoder.decode(Out.self, from: data) } catch { throw LifeError.server("unreadable response") }
        }
        throw error
    }

    /// Nil means success. Engine errors are `{"error":{"code","message"}}`; the router's own are `{"error":"..."}`, and
    /// `no_tenant` is the router saying the workspace (or this engine in it) does not exist, never the engine.
    static func classify(status: Int, body: Data) -> LifeError? {
        if (200...299).contains(status) { return nil }
        let text = String(decoding: body, as: UTF8.self)
        switch status {
        case 401, 403: return .unauthorized
        case 404 where text.contains("no_tenant"): return .notProvisioned
        case 408, 429, 502, 503, 504: return .retry("server returned \(status)")
        default:
            if let e = try? Wire.decoder.decode(Wire.ErrorEnvelope.self, from: body) {
                return e.error.code == "busy" ? .retry(e.error.message) : .engine(code: e.error.code, message: e.error.message)
            }
            return status >= 500 ? .server("server returned \(status)") : .engine(code: "unknown", message: "The server returned \(status).")
        }
    }

    private static func urlSession(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

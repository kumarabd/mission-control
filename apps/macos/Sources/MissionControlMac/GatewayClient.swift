import Foundation

@MainActor
final class GatewayClient {
    typealias TokenProvider = @MainActor () async throws -> String?

    /// Every callback carries the originating session so a late frame can never
    /// be rendered into whichever conversation happens to be selected now.
    var onFrame: ((String, GatewayFrame) -> Void)?
    var onConnectionState: ((String?, ConnectionState) -> Void)?

    private let baseURL: URL
    private let tokenProvider: TokenProvider
    private let decoder: JSONDecoder
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var desiredConnection: ConnectionRequest?
    private var reconnectAttempt = 0

    private struct ConnectionRequest: Equatable {
        let id = UUID()
        let sessionID: String
        let parentSessionID: String?
        let afterTurnSequence: Int?
    }

    init(baseURL: URL, tokenProvider: @escaping TokenProvider) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func connect(sessionID: String, parentSessionID: String?, afterTurnSequence: Int?) {
        replaceConnection(with: .init(
            sessionID: sessionID,
            parentSessionID: parentSessionID,
            afterTurnSequence: afterTurnSequence
        ))
    }

    /// A new conversation must never be a resume of the socket that was just
    /// displaying another conversation. It gets its own transport and auth
    /// frame with no cursor or parent.
    func connectFreshSession(sessionID: String) {
        replaceConnection(with: .init(
            sessionID: sessionID,
            parentSessionID: nil,
            afterTurnSequence: nil
        ))
    }

    private func replaceConnection(with request: ConnectionRequest) {
        desiredConnection = request
        closeTransport()
        onConnectionState?(request.sessionID, .connecting)
        openDesiredConnection()
    }

    func disconnect() {
        desiredConnection = nil
        closeTransport()
        onConnectionState?(nil, .offline(nil))
    }

    func listSessions() async throws -> [SessionSummary] {
        struct Response: Decodable { let sessions: [SessionSummary]? }
        let response: Response = try await request(path: "/macos/sessions", method: "GET")
        return response.sessions ?? []
    }

    func poll(sessionID: String, since: Int) async throws -> PollResponse {
        var components = URLComponents(
            url: endpoint("/macos/poll"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            .init(name: "session_id", value: sessionID),
            .init(name: "since_turn_seq", value: String(since)),
        ]
        return try await request(url: components.url!, method: "GET")
    }

    func sendMessage(_ text: String, clientMessageID: String, sessionID: String, parentSessionID: String?) async throws {
        var frame: [String: Any] = [
            "type": "message",
            "client_msg_id": clientMessageID,
            "text": text,
            "mode": "text",
            "session_id": sessionID,
        ]
        if let parentSessionID { frame["parent_session_id"] = parentSessionID }
        if try await sendSocketFrame(frame, for: sessionID) { return }

        var body: [String: Any] = [
            "content": text,
            "client_message_id": clientMessageID,
            "session_id": sessionID,
        ]
        if let parentSessionID { body["parent_session_id"] = parentSessionID }
        let _: StatusResponse = try await request(path: "/macos/send", method: "POST", body: body)
    }

    func answer(requestID: String, optionID: String?, freeText: String?, sessionID: String) async throws {
        var socketFrame: [String: Any] = [
            "type": "answer",
            "request_id": requestID,
            "session_id": sessionID,
        ]
        if let optionID { socketFrame["selected_option_id"] = optionID }
        if let freeText { socketFrame["free_text"] = freeText }
        if try await sendSocketFrame(socketFrame, for: sessionID) { return }

        var body = socketFrame
        body.removeValue(forKey: "type")
        let _: StatusResponse = try await request(path: "/macos/respond", method: "POST", body: body)
    }

    func cancel(sessionID: String) async throws {
        if try await sendSocketFrame(["type": "cancel", "session_id": sessionID], for: sessionID) { return }
        let _: StatusResponse = try await request(
            path: "/macos/cancel",
            method: "POST",
            body: ["session_id": sessionID]
        )
    }

    private func openDesiredConnection() {
        guard receiveTask == nil, let desiredConnection else { return }
        receiveTask = Task { [weak self] in
            await self?.runConnection(desiredConnection)
        }
    }

    private func runConnection(_ request: ConnectionRequest) async {
        defer {
            // A previous, cancelled task must not clear the live task created
            // for a newly selected conversation.
            if isDesired(request) { receiveTask = nil }
        }
        do {
            guard isDesired(request), let token = try await tokenProvider(), !token.isEmpty else {
                if isDesired(request) { onConnectionState?(request.sessionID, .offline("Sign in required")) }
                return
            }
            guard isDesired(request) else { return }

            let task = URLSession.shared.webSocketTask(with: websocketEndpoint(token: token))
            guard isDesired(request) else {
                task.cancel(with: .goingAway, reason: nil)
                return
            }
            socket = task
            task.resume()

            var auth: [String: Any] = [
                "type": "auth",
                "token": token,
                "session_id": request.sessionID,
                "capabilities": ["tool_calls"],
                "device_id": Host.current().localizedName ?? "macOS",
            ]
            if let parent = request.parentSessionID { auth["parent_session_id"] = parent }
            if let afterTurnSequence = request.afterTurnSequence {
                auth["after_turn_seq"] = afterTurnSequence
            }
            try await send(auth, on: task)
            startPinging(task, for: request)

            while !Task.isCancelled, isDesired(request), socket === task {
                let message = try await task.receive()
                guard case .string(let string) = message,
                      let data = string.data(using: .utf8) else { continue }
                let frame = try decoder.decode(GatewayFrame.self, from: data)
                if frame.type == "resumed" {
                    reconnectAttempt = 0
                    onConnectionState?(request.sessionID, .live)
                }
                onFrame?(request.sessionID, frame)
            }
        } catch is CancellationError {
            return
        } catch {
            guard isDesired(request) else { return }
            onConnectionState?(request.sessionID, .reconnecting)
            scheduleReconnect(for: request)
        }
    }

    private func isDesired(_ request: ConnectionRequest) -> Bool {
        desiredConnection?.id == request.id
    }

    private func scheduleReconnect(for request: ConnectionRequest) {
        guard reconnectTask == nil, isDesired(request) else { return }
        reconnectAttempt += 1
        let delay = min(pow(2, Double(min(reconnectAttempt, 3))), 8)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.isDesired(request) else { return }
            self.reconnectTask = nil
            self.openDesiredConnection()
        }
    }

    private func startPinging(_ task: URLSessionWebSocketTask, for request: ConnectionRequest) {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, self?.socket === task, self?.isDesired(request) == true else { return }
                task.sendPing { error in
                    guard error != nil else { return }
                    Task { @MainActor in
                        guard self?.isDesired(request) == true else { return }
                        self?.scheduleReconnect(for: request)
                    }
                }
            }
        }
    }

    private func closeTransport() {
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        pingTask?.cancel()
        pingTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func sendSocketFrame(_ frame: [String: Any], for sessionID: String) async throws -> Bool {
        // If the selected session changed while an action was queued, use the
        // HTTP endpoint below rather than writing it to the old socket.
        guard desiredConnection?.sessionID == sessionID,
              let socket,
              socket.state == .running else { return false }
        do {
            try await send(frame, on: socket)
            return true
        } catch {
            return false
        }
    }

    private func send(_ frame: [String: Any], on socket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: frame)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Response {
        try await request(url: endpoint(path), method: method, body: body)
    }

    private func request<Response: Decodable>(
        url: URL,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Response {
        guard let token = try await tokenProvider(), !token.isEmpty else {
            throw GatewayError.notAuthenticated
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw GatewayError.requestFailed(detail?.isEmpty == false ? detail! : "Gateway request failed")
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func endpoint(_ path: String) -> URL {
        baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private func websocketEndpoint(token: String) -> URL {
        var components = URLComponents(url: endpoint("/macos/ws"), resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.queryItems = [.init(name: "token", value: token)]
        return components.url!
    }
}

private struct StatusResponse: Decodable {
    let status: String
}

enum GatewayError: LocalizedError {
    case notAuthenticated
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in to connect to Mission Control."
        case .requestFailed(let detail): detail
        }
    }
}

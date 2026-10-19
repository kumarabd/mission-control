import Foundation
import Security
import UIKit

/// Exchanges authenticated text turns with the remote intelligence gateway.
/// Microphone capture, speech recognition, and speech synthesis stay on-device.
@MainActor
final class MobileGateway {
    enum Event {
        case turnStarted(Int)
        case delta(turnSequence: Int, text: String, replace: Bool, progress: Bool)
        /// The text streamed for this turn so far was narration between tool calls: take it back.
        case retract(turnSequence: Int)
        case message(turnSequence: Int, sequence: Int, role: String, content: String, clientMessageID: String?)
        case status(turnSequence: Int, text: String)
        case askUser(GatewayQuestion)
        case turnEnded(Int, status: String)
        /// A page of older messages the gateway sent in answer to `requestHistory`, oldest first.
        case history(beforeTurn: Int, oldestTurn: Int, hasMore: Bool, messages: [HistoryMessage])
        case synchronizing
        case historyLoaded
        case error(String)
    }

    struct HistoryMessage: Decodable {
        let turnSequence: Int; let sequence: Int; let role: String; let content: String
        enum CodingKeys: String, CodingKey { case role, content; case turnSequence = "turn_seq"; case sequence = "seq" }
    }

    struct GatewayQuestion {
        struct Option: Decodable { let id: String; let label: String }
        let requestID: String
        let kind: String
        let prompt: String
        let options: [Option]
        let allowsFreeText: Bool
    }

    var onEvent: ((Event) -> Void)?

    /// The voice assistant resumes from the last turn it finished. That saved position is one number for the whole app, so a
    /// client that only wants the turn it just started (capture) turns it off: a stale number from an older session would
    /// make the gateway skip every turn at or below it, and the reply would never arrive.
    private let usesResumeCursor: Bool
    /// Ask the gateway for only what is for the person: their own messages, the assistant's replies and questions. Not
    /// the narration between tool calls, nor what a turn the agent started itself says. Both the text chat and the voice
    /// assistant ask for this: in voice, narration would be read aloud.
    private let humanOnly: Bool
    /// False asks for no token streaming, so a reply arrives once, as its saved message. The first step's text streams
    /// before anyone knows it was narration, and speech cannot be taken back, so the voice assistant turns streaming off
    /// (it speaks a reply when it is saved, a little later than it would have started streaming). The text chat streams
    /// and takes narration back with a retract instead.
    private let streams: Bool

    init(usesResumeCursor: Bool = true, humanOnly: Bool = false, streams: Bool = true) {
        self.usesResumeCursor = usesResumeCursor
        self.humanOnly = humanOnly
        self.streams = streams
    }

    private let authentication: any AgentGatewayAuthenticating = ClerkGatewayAuthentication()
    private let gatewayURL = URL(string: "https://harness-router.nighthawklabs.org/gateway/ios/ws")!
    private let deviceID = GatewayDeviceIdentity.value
    // Versioned per platform so the old shared-mobile cursor cannot skip the
    // first turns when this client enters its new iOS-only history.
    // v2 clears the stale resume position retained across the gateway
    // migration. This is deliberately scoped to gateway delivery state;
    // it does not reset sign-in, tasks, or any other on-device data.
    private let cursorKey = "gateway.ios.completedTurnCursor.v2"
    /// Which agent (gateway/internal/agents registry) this device's conversation addresses. Set from
    /// Settings > Agents; empty means the default agent (`core.DefaultAgentID`, resolved server-side).
    private let selectedAgentKey = "gateway.ios.selectedAgentID"
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var backoff: TimeInterval = 1
    private var intentionallyDisconnected = false
    private var appIsActive = false
    private var interactionIsActive = false
    private var transportGeneration = 0
    private var interactionGeneration = 0
    private var isLive = false
    private var pendingFrames = [[String: Any]]()

    /// The dashboard being visible is not enough to keep an agent coordinator
    /// alive. A foreground app opens the socket only for a person-initiated
    /// assistant interaction, then releases it when that interaction finishes.
    func setAppActive(_ isActive: Bool) {
        appIsActive = isActive
        if isActive {
            connectIfNeeded()
        } else {
            closeTransport()
        }
    }

    func beginInteraction() {
        interactionIsActive = true
        intentionallyDisconnected = false
        connectIfNeeded()
    }

    func endInteraction() {
        interactionIsActive = false
        interactionGeneration &+= 1
        pendingFrames.removeAll()
        closeTransport()
    }

    private var shouldMaintainConnection: Bool { appIsActive && interactionIsActive }

    private func connectIfNeeded() {
        guard shouldMaintainConnection else { return }
        intentionallyDisconnected = false
        guard receiveTask == nil else { return }
        transportGeneration &+= 1
        let generation = transportGeneration
        receiveTask = Task { [weak self] in await self?.openAndReceive(generation: generation) }
    }

    private func closeTransport() {
        transportGeneration &+= 1
        intentionallyDisconnected = true
        isLive = false
        receiveTask?.cancel(); receiveTask = nil
        pingTask?.cancel(); pingTask = nil
        reconnectTask?.cancel(); reconnectTask = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
    }

    func sendMessage(_ text: String, mode: String = "voice") -> String {
        let clientMessageID = UUID().uuidString
        // The message goes as typed: no clock stamp, no client-capabilities preamble. The agent's own context about
        // the person and their device belongs on the engine/harness side, not glued to their words — it was showing
        // up in the transcript, and it was being stored as part of what they said.
        enqueue([
            "type": "message",
            "client_msg_id": clientMessageID,
            "text": text,
            "mode": mode,
            "device_id": deviceID,
        ])
        return clientMessageID
    }

    /// Stops whatever the assistant is doing for this session, so a question nobody will answer does not hold the turn open.
    func cancelTurn() { enqueue(["type": "cancel"]) }

    /// Asks for the turns just before `turn`: the user and assistant messages of up to `limit` of them, oldest first.
    func requestHistory(before turn: Int, limit: Int = 5) {
        enqueue(["type": "history", "before_turn_seq": turn, "limit": limit])
    }

    func answer(requestID: String, optionID: String? = nil, freeText: String? = nil) {
        var frame: [String: Any] = ["type": "answer", "request_id": requestID]
        if let optionID { frame["selected_option_id"] = optionID }
        if let freeText { frame["free_text"] = freeText }
        enqueue(frame)
    }

    private func openAndReceive(generation: Int) async {
        defer { if transportGeneration == generation { receiveTask = nil } }
        do {
            isLive = false
            onEvent?(.synchronizing)
            let token = try await authentication.sessionToken()
            guard !Task.isCancelled, shouldMaintainConnection, transportGeneration == generation else { return }
            guard let token, !token.isEmpty else {
                onEvent?(.error("Sign in to connect the assistant.")); return
            }
            let task = URLSession.shared.webSocketTask(with: websocketEndpoint(token: token))
            socket = task; task.resume()
            var auth: [String: Any] = ["type": "auth", "token": token, "device_id": deviceID]
            if usesResumeCursor, let cursor = UserDefaults.standard.object(forKey: cursorKey) as? Int { auth["after_turn_seq"] = cursor }
            if let agentID = UserDefaults.standard.string(forKey: selectedAgentKey), !agentID.isEmpty { auth["agent_id"] = agentID }
            if humanOnly { auth["human_only"] = true }
            if !streams { auth["stream"] = false }
            try await send(auth, on: task)
            guard !Task.isCancelled, socket === task, transportGeneration == generation else { return }
            startPing(for: task)
            while !Task.isCancelled, socket === task {
                let incoming = try await task.receive()
                guard !Task.isCancelled, shouldMaintainConnection, socket === task,
                      transportGeneration == generation else { return }
                guard case let .string(text) = incoming, let data = text.data(using: .utf8) else { continue }
                handle(try JSONDecoder().decode(ServerFrame.self, from: data))
            }
        } catch is CancellationError {
            return
        } catch {
            if transportGeneration == generation, !intentionallyDisconnected { scheduleReconnect() }
        }
    }

    private func enqueue(_ frame: [String: Any]) {
        guard interactionIsActive else { return }
        if isLive, let socket {
            let generation = transportGeneration
            Task { [weak self] in
                guard let self, shouldMaintainConnection, generation == transportGeneration,
                      self.socket === socket else { return }
                do { try await send(frame, on: socket) }
                catch {
                    guard generation == transportGeneration, interactionIsActive else { return }
                    pendingFrames.append(frame)
                    scheduleReconnect()
                }
            }
        } else {
            pendingFrames.append(frame)
            connectIfNeeded()
        }
    }

    private func websocketEndpoint(token: String) -> URL {
        var components = URLComponents(url: gatewayURL, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.queryItems = [.init(name: "token", value: token)]
        return components.url!
    }

    private func flushPendingFrames() {
        guard let socket else { return }
        let frames = pendingFrames; pendingFrames.removeAll()
        let epoch = interactionGeneration
        let generation = transportGeneration
        Task { [weak self] in
            guard let self else { return }
            var sent = 0
            do {
                for frame in frames {
                    guard interactionIsActive, interactionGeneration == epoch else { return }
                    guard generation == transportGeneration, self.socket === socket else {
                        pendingFrames.insert(contentsOf: frames.dropFirst(sent), at: 0)
                        return
                    }
                    try await send(frame, on: socket)
                    sent += 1
                }
            } catch {
                guard interactionIsActive, interactionGeneration == epoch else { return }
                pendingFrames.insert(contentsOf: frames.dropFirst(sent), at: 0)
                if generation == transportGeneration { scheduleReconnect() }
            }
        }
    }

    private func send(_ frame: [String: Any], on socket: URLSessionWebSocketTask) async throws {
        guard !Task.isCancelled, shouldMaintainConnection, self.socket === socket else { throw CancellationError() }
        let data = try JSONSerialization.data(withJSONObject: frame)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func handle(_ frame: ServerFrame) {
        switch frame.type {
        case "turn_start":
            if let turn = frame.turnSequence { onEvent?(.turnStarted(turn)) }
        case "delta":
            if let turn = frame.turnSequence {
                if frame.retract == true { onEvent?(.retract(turnSequence: turn)) }
                else {
                    onEvent?(.delta(turnSequence: turn, text: frame.text ?? "", replace: frame.replace ?? false,
                                    progress: frame.progress == true))
                }
            }
        case "message":
            if let turn = frame.turnSequence, let sequence = frame.sequence, let role = frame.role, let content = frame.content {
                onEvent?(.message(turnSequence: turn, sequence: sequence, role: role, content: content, clientMessageID: frame.clientMessageID))
            }
        case "status":
            if let turn = frame.turnSequence { onEvent?(.status(turnSequence: turn, text: frame.text ?? "")) }
        case "history":
            if let before = frame.beforeTurnSeq, let oldest = frame.oldestTurnSeq {
                onEvent?(.history(beforeTurn: before, oldestTurn: oldest, hasMore: frame.hasMore ?? false, messages: frame.messages ?? []))
            }
        case "ask_user":
            if let requestID = frame.requestID, let prompt = frame.prompt {
                onEvent?(.askUser(.init(requestID: requestID, kind: frame.kind ?? "question", prompt: prompt,
                                        options: frame.options ?? [], allowsFreeText: frame.allowsFreeText ?? false)))
            }
        case "turn_end":
            if let turn = frame.turnSequence {
                if usesResumeCursor { UserDefaults.standard.set(max(turn, UserDefaults.standard.integer(forKey: cursorKey)), forKey: cursorKey) }
                onEvent?(.turnEnded(turn, status: frame.status ?? "completed"))
            }
        case "resumed":
            isLive = true; backoff = 1; onEvent?(.historyLoaded); flushPendingFrames()
        case "error":
            onEvent?(.error(frame.message ?? "The assistant connection failed."))
            if frame.message == "invalid token" { scheduleReconnect() }
        default: break
        }
    }

    private func startPing(for task: URLSessionWebSocketTask) {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                task.sendPing { error in
                    guard error != nil else { return }
                    Task { @MainActor in
                        guard let self, self.socket === task else { return }
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard shouldMaintainConnection, !intentionallyDisconnected, reconnectTask == nil else { return }
        transportGeneration &+= 1
        receiveTask?.cancel(); receiveTask = nil
        isLive = false; pingTask?.cancel(); pingTask = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
        let delay = min(30, backoff) + .random(in: 0...1); backoff = min(30, backoff * 2)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.reconnectTask = nil; self?.connectIfNeeded()
        }
    }
}

private struct ServerFrame: Decodable {
    let type: String; let turnSequence: Int?; let sequence: Int?; let role: String?; let content: String?
    let clientMessageID: String?; let text: String?; let replace: Bool?; let progress: Bool?; let requestID: String?; let kind: String?
    let prompt: String?; let options: [MobileGateway.GatewayQuestion.Option]?; let allowsFreeText: Bool?
    let status: String?; let message: String?
    let beforeTurnSeq: Int?; let oldestTurnSeq: Int?; let hasMore: Bool?; let messages: [MobileGateway.HistoryMessage]?
    let retract: Bool?
    enum CodingKeys: String, CodingKey {
        case type, role, content, text, replace, progress, kind, prompt, options, status, message, messages, retract
        case beforeTurnSeq = "before_turn_seq"; case oldestTurnSeq = "oldest_turn_seq"; case hasMore = "has_more"
        case turnSequence = "turn_seq"; case sequence = "seq"; case clientMessageID = "client_msg_id"
        case requestID = "request_id"; case allowsFreeText = "allow_free_text"
    }
}

enum GatewayDeviceIdentity {
    private static let service = "com.kumarabd.MissionControl"; private static let account = "gateway-device-id"
    static var value: String {
        if let data = read(), let value = String(data: data, encoding: .utf8) { return value }
        let value = UUID().uuidString; save(Data(value.utf8)); return value
    }
    private static func read() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true]
        var result: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }
    private static func save(_ data: Data) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecValueData as String: data]
        SecItemAdd(query as CFDictionary, nil)
    }
}

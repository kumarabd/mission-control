import Foundation

/// Capture goes to the agent as plain text. The agent decides what it is and writes it through the Life Engine tools,
/// the same operations the app calls itself, so nothing is interpreted on the phone.
@MainActor
final class AgentCapture {
    enum Failure: LocalizedError {
        case timedOut
        case gateway(String)
        var errorDescription: String? {
            switch self {
            case .timedOut: "The assistant didn't answer in time. Check your connection and try again."
            case .gateway(let m): m
            }
        }
    }

    private let gateway = MobileGateway()

    /// Sends one turn and returns the agent's reply once the turn ends.
    func send(_ text: String) async throws -> String {
        gateway.setAppActive(true)
        gateway.beginInteraction()
        defer { gateway.endInteraction() }
        var turn: Int?
        var reply = ""
        var id = ""
        return try await withThrowingTaskGroup(of: String.self) { group in
            let stream = AsyncStream<MobileGateway.Event> { c in gateway.onEvent = { c.yield($0) } }
            group.addTask { @MainActor in
                for await event in stream {
                    switch event {
                    case .message(let t, _, let role, let content, let cid):
                        if cid == id { turn = t }
                        else if role == "assistant", t == turn { reply += (reply.isEmpty ? "" : "\n") + content }
                    case .askUser(let q): return q.prompt
                    case .turnEnded(let t, _) where t == turn: return reply
                    case .error(let m): throw Failure.gateway(m)
                    default: break
                    }
                }
                throw Failure.timedOut
            }
            group.addTask { try await Task.sleep(for: .seconds(90)); throw Failure.timedOut }
            id = gateway.sendMessage(Self.stamped(text), mode: "text")
            defer { group.cancelAll() }
            return try await group.next() ?? ""
        }
    }

    /// Relative words ("in 20 minutes", "tomorrow") only mean something against the user's clock.
    static func stamped(_ text: String) -> String {
        let now = Date().formatted(date: .complete, time: .standard)
        return "[Now: \(now), time zone \(TimeZone.current.identifier)]\n\(text)"
    }
}

import Foundation

/// Capture goes to the agent as plain text. The agent decides what it is and writes it through the Life Engine tools,
/// the same operations the app uses, so nothing is interpreted on the phone.
///
/// The agent may need more ("what times?"), so this holds one conversation open: `send` returns either the reply or a
/// question, and `answer` carries on the same turn.
@MainActor
final class AgentCapture {
    struct Question {
        let requestID: String
        let prompt: String
        let options: [MobileGateway.GatewayQuestion.Option]
        let allowsFreeText: Bool
    }

    enum Outcome {
        case reply(String)
        case question(Question)
    }

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
    // Events wait here until `outcome` asks for them, one at a time.
    private var queue: [MobileGateway.Event] = []
    private var waiter: CheckedContinuation<MobileGateway.Event, Never>?
    private var timer: Task<Void, Never>?
    private var turn: Int?
    private var reply = ""
    private var sentID = ""
    private var open = false

    init() {
        gateway.onEvent = { [weak self] in self?.deliver($0) }
    }

    private func deliver(_ event: MobileGateway.Event) {
        if let waiter { self.waiter = nil; waiter.resume(returning: event) } else { queue.append(event) }
    }

    private func next() async -> MobileGateway.Event {
        if !queue.isEmpty { return queue.removeFirst() }
        return await withCheckedContinuation { waiter = $0 }
    }

    /// Sends one turn and waits for the reply, or for a question the agent needs answered first.
    func send(_ text: String) async throws -> Outcome {
        if !open {
            gateway.setAppActive(true)
            gateway.beginInteraction()
            open = true
        }
        queue.removeAll() // whatever replayed while connecting is history, not an answer
        turn = nil
        reply = ""
        sentID = gateway.sendMessage(Self.stamped(text), mode: "text")
        return try await outcome()
    }

    /// Answers the agent's question (a listed option, or free text) and waits for the same turn to carry on.
    func answer(_ question: Question, optionID: String? = nil, text: String? = nil) async throws -> Outcome {
        reply = ""
        gateway.answer(requestID: question.requestID, optionID: optionID, freeText: text)
        return try await outcome()
    }

    /// Stops the turn, so an unanswered question does not hold the assistant for half an hour.
    func cancel() { gateway.cancelTurn() }

    func close() {
        timer?.cancel()
        guard open else { return }
        open = false
        gateway.endInteraction()
    }

    private func outcome() async throws -> Outcome {
        timer?.cancel()
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(120))
            if !Task.isCancelled { self?.deliver(.error(Failure.timedOut.errorDescription ?? "Timed out.")) }
        }
        defer { timer?.cancel() }
        while true {
            let event = await next()
            switch event {
            case .message(let t, _, let role, let content, let cid):
                if cid == sentID { turn = t }
                else if role == "assistant", t == turn { reply += (reply.isEmpty ? "" : "\n") + content }
            // Only after our own message is echoed: before that, a question could be left over from an earlier turn.
            case .askUser(let q) where turn != nil:
                return .question(Question(requestID: q.requestID, prompt: q.prompt, options: q.options, allowsFreeText: q.allowsFreeText))
            case .turnEnded(let t, _) where t == turn: return .reply(reply)
            case .error(let m): throw Failure.gateway(m)
            default: break
            }
        }
    }

    /// Relative words ("in 20 minutes", "tomorrow") only mean something against the user's clock.
    static func stamped(_ text: String) -> String {
        let now = Date().formatted(date: .complete, time: .standard)
        return "[Now: \(now), time zone \(TimeZone.current.identifier)]\n\(text)"
    }
}

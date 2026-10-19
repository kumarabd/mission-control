import Foundation
import Observation

/// The app's one conversation with the assistant, over the gateway's iOS socket. Nothing is interpreted on the phone:
/// the assistant decides what a message is and writes it through the Life Engine, the same operations the app uses.
///
/// iOS is deliberately a single session (`gateway/internal/mobile/mobile.go` allows no others), so there is no list of
/// conversations — there is one thread. On connect the gateway replays the last 20 turns, which is why the transcript
/// is built to be idempotent rather than cached.
@MainActor @Observable
final class ChatModel {
    struct Question {
        let requestID: String
        let prompt: String
        let options: [MobileGateway.GatewayQuestion.Option]
        let allowsFreeText: Bool
    }

    /// The resume cursor is shared with the voice path and a stale value makes the gateway skip turns, so this always
    /// takes the replayed tail instead.
    private let gateway = MobileGateway(usesResumeCursor: false)

    private(set) var transcript = ChatTranscript()
    private(set) var question: Question?
    /// True once the gateway has finished replaying, so the screen can say it is waiting rather than empty.
    private(set) var connected = false
    /// Bumped when a turn finishes, for the screens that then re-read the workspace.
    private(set) var completedTurns = 0
    /// A draft another screen asked Chat to open with; `draftToken` changes so the view can notice.
    private(set) var pendingDraft: String?
    private(set) var draftToken = 0

    private var open = false
    /// A turn must have started before a question can belong to it: a leftover question from an earlier turn must not
    /// attach itself to a conversation that has just opened.
    private var sawTurn = false

    init() {
        gateway.onEvent = { [weak self] event in self?.handle(event) }
    }

    // MARK: The socket's lifetime

    func beginInteraction() {
        guard !open else { return }
        open = true
        gateway.setAppActive(true)
        gateway.beginInteraction()
    }

    func endInteraction() {
        guard open else { return }
        open = false
        gateway.endInteraction()
    }

    // MARK: Sending

    func send(_ text: String) {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return }
        beginInteraction()
        question = nil
        transcript.apply(.sent(clientID: gateway.sendMessage(trimmed, mode: "text"), text: trimmed))
    }

    func answer(_ question: Question, optionID: String? = nil, text: String? = nil) {
        self.question = nil
        gateway.answer(requestID: question.requestID, optionID: optionID, freeText: text)
        let shown = text ?? question.options.first { $0.id == optionID }?.label
        if let shown { transcript.apply(.answered(text: shown)) }
        transcript.apply(.started(turn: -1))   // an answer carries on the same turn; keep it marked as running
    }

    func cancelTurn() {
        gateway.cancelTurn()
        transcript.apply(.failed("Stopped."))
    }

    /// Another screen starting the conversation (a new goal, a memory to correct).
    func request(draft: String) {
        pendingDraft = draft
        draftToken += 1
    }

    func consumeDraft() -> String? {
        defer { pendingDraft = nil }
        return pendingDraft
    }

    // MARK: Events

    private func handle(_ event: MobileGateway.Event) {
        switch event {
        case .turnStarted(let turn):
            sawTurn = true
            transcript.apply(.started(turn: turn))
        case .message(let turn, let seq, let role, let content, let clientMessageID):
            transcript.apply(.message(turn: turn, seq: seq, role: role, content: content, clientMessageID: clientMessageID))
        case .delta(let turn, let text, let replace, let progress):
            transcript.apply(.delta(turn: turn, text: text, replace: replace, progress: progress))
        case .status(let turn, let text):
            transcript.apply(.status(turn: turn, text: text))
        case .askUser(let q) where sawTurn:
            question = Question(requestID: q.requestID, prompt: q.prompt, options: q.options, allowsFreeText: q.allowsFreeText)
            transcript.apply(.asked)
        case .askUser:
            break    // a question with no turn behind it is a leftover, not something to answer
        case .turnEnded(let turn, let status):
            transcript.apply(.ended(turn: turn, status: status))
            question = nil
            completedTurns += 1
        case .historyLoaded:
            connected = true
        case .synchronizing:
            connected = false
        case .error(let message):
            transcript.apply(.failed(message))
        }
    }

}

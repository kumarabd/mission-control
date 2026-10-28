import Foundation
import Observation
import os

/// The app's one conversation with the assistant, over the gateway's iOS socket. Nothing is interpreted on the phone:
/// the assistant decides what a message is and writes it through the Life Engine, the same operations the app uses.
///
/// It behaves like a messaging app. The connection stays open while the app is in the foreground, on any tab, so a reply
/// that lands while you are elsewhere is waiting (and counted) when you come back. Every message you send is shown at
/// once as sending, becomes sent when the gateway echoes it, and is marked failed, with a way to send it again, if it
/// never does. The recent messages are kept on the phone, so the chat opens with them before the gateway has answered.
/// A message sent while the assistant is replying interrupts the reply: the assistant stops and answers the new one.
@MainActor @Observable
final class ChatModel {
    struct Question {
        let requestID: String
        let prompt: String
        let options: [MobileGateway.GatewayQuestion.Option]
        let allowsFreeText: Bool
    }

    /// Where the connection stands. `live` is after the gateway has finished replaying what the phone missed.
    enum Link: Equatable { case connecting, live, offline }

    /// The resume cursor is shared with the voice path and a stale value makes the gateway skip turns, so this always
    /// takes the replayed tail instead.
    private let gateway = MobileGateway(usesResumeCursor: false, humanOnly: true)
    private let owner: String
    /// The agent this conversation is with. Each agent has its own thread on the gateway and its own saved window here.
    private(set) var agentID: String
    /// Where the pick is kept; the gateway reads it when it connects, and Settings > Agents writes it. Empty is the default agent.
    private static let selectionKey = "gateway.ios.selectedAgentID"
    private static func selectedAgent() -> String {
        let id = UserDefaults.standard.string(forKey: selectionKey) ?? ""
        return id.isEmpty ? ChatStore.defaultAgent : id
    }
    private static let log = Logger(subsystem: "com.kumarabd.MissionControl", category: "chat")

    private(set) var transcript = ChatTranscript()
    private(set) var question: Question?
    /// The skill tasks still running, oldest first; a task leaves when its frame says it ended.
    private(set) var tasks: [MobileGateway.TaskProgress] = []
    private(set) var link: Link = .connecting
    /// True a moment after the connection is lost, so a blink between two sockets does not flash a banner.
    private(set) var showsOffline = false
    /// Replies that arrived while the Chat tab was not showing.
    private(set) var unread = 0
    /// Bumped when a turn finishes, for the screens that then re-read the workspace.
    private(set) var completedTurns = 0
    /// A draft another screen asked Chat to open with; `draftToken` changes so the view can notice.
    private(set) var pendingDraft: String?
    private(set) var draftToken = 0
    /// Bumped when the Chat tab is tapped while already showing, so the thread returns to its newest message.
    private(set) var latestToken = 0
    func showLatest() { latestToken += 1 }

    /// Whether the Chat tab is showing. Showing it reads everything.
    var isVisible = false { didSet { if isVisible { unread = 0 } } }
    var connected: Bool { link == .live }

    private var open = false
    private var inForeground = false
    private var voiceHasIt = false
    private var saveTask: Task<Void, Never>?
    private var offlineTask: Task<Void, Never>?

    init(owner: String) {
        self.owner = owner
        agentID = Self.selectedAgent()
        gateway.onEvent = { [weak self] event in self?.handle(event) }
        restoreSaved()
    }

    private func restoreSaved() {
        do { transcript.restore(try ChatStore.load(owner: owner, agent: agentID)) }
        catch {
            // The saved copy is only a cache of what the gateway holds: say it could not be read, drop it, carry on.
            Self.log.error("saved chat unreadable: \(error.localizedDescription, privacy: .public)")
            ChatStore.remove(owner: owner, agent: agentID)
            transcript.apply(.failed("The saved messages could not be read; showing what the assistant has."))
        }
    }

    // MARK: Which agent

    /// Turns to another agent: its thread replaces this one (the saved window at once, the gateway's replay once connected).
    func switchAgent(to id: String) {
        guard id != agentID else { return }
        saveTask?.cancel()
        do { try ChatStore.save(transcript.saved, owner: owner, agent: agentID) }
        catch { Self.log.error("could not save the chat: \(error.localizedDescription, privacy: .public)") }
        UserDefaults.standard.set(id == ChatStore.defaultAgent ? "" : id, forKey: Self.selectionKey)
        agentID = id
        transcript = ChatTranscript()
        question = nil
        unread = 0
        restoreSaved()
        // The gateway reads the pick when it connects, so a live connection is closed and opened again.
        let wasOpen = open
        endInteraction()
        if wasOpen { reconcile() }
    }

    /// Settings > Agents can change the pick while Chat is not showing; Chat calls this when it appears.
    func syncAgentSelection() {
        let id = Self.selectedAgent()
        if id != agentID { switchAgent(to: id) }
    }

    // MARK: The socket's lifetime

    /// The app is in the foreground: keep the conversation connected. In the background it is released.
    func setForeground(_ active: Bool) {
        inForeground = active
        reconcile()
    }

    /// Talking replaces typing: while the voice assistant has the conversation, the text connection steps aside so the
    /// two never answer the same turn.
    func setVoice(_ on: Bool) {
        voiceHasIt = on
        reconcile()
    }

    private func reconcile() {
        if inForeground && !voiceHasIt { beginInteraction() } else { endInteraction() }
    }

    private func beginInteraction() {
        guard !open else { return }
        open = true
        gateway.setAppActive(true)
        gateway.beginInteraction()
    }

    private func endInteraction() {
        guard open else { return }
        open = false
        gateway.endInteraction()
        setLink(.connecting)
    }

    // MARK: Sending

    func send(_ text: String) {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return }
        beginInteraction()
        let id = gateway.sendMessage(trimmed, mode: "text")
        apply(.sent(clientID: id, text: trimmed))
    }

    /// Sends a failed message again, in the same place and with the same id, so the gateway cannot take it twice.
    func retry(_ item: ChatTranscript.Item) {
        guard item.delivery == .failed, item.id.hasPrefix("u:"), item.turn == 0 else { return }
        let id = String(item.id.dropFirst(2))
        beginInteraction()
        apply(.resending(clientID: id))
        _ = gateway.sendMessage(item.text, mode: "text", clientMessageID: id)
    }

    func answer(_ question: Question, optionID: String? = nil, text: String? = nil) {
        self.question = nil
        gateway.answer(requestID: question.requestID, optionID: optionID, freeText: text)
        let shown = text ?? question.options.first { $0.id == optionID }?.label
        if let shown { apply(.answered(text: shown)) }
        apply(.started(turn: -1))   // an answer carries on the same turn; keep it marked as running
    }

    /// Asks the gateway for older messages, when there are any and none are already on the way.
    func loadEarlier() {
        guard let before = transcript.beginLoadEarlier() else { return }
        earlierRequestedAt = Date()
        gateway.requestHistory(before: before)
    }
    private var earlierRequestedAt: Date?
    /// A page that arrives faster than this still shows the loading row for this long, so the person sees that
    /// something was fetched rather than the thread changing on its own.
    private static let minimumLoadingShown: TimeInterval = 0.4

    func cancelTurn() {
        gateway.cancelTurn()
        apply(.failed("Stopped."))
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

    private func apply(_ event: ChatTranscript.Event) {
        let before = Set(transcript.items.map(\.id))
        transcript.apply(event)
        if case .message(_, _, "assistant", _, _, _) = event, !isVisible, link == .live,
           transcript.items.contains(where: { $0.role == .assistant && !before.contains($0.id) }) {
            unread += 1
        }
        scheduleSave()
    }

    /// The recent window is written a moment after it last changed, so a burst of streamed text is one write.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            do { try ChatStore.save(transcript.saved, owner: owner, agent: agentID) }
            catch { Self.log.error("could not save the chat: \(error.localizedDescription, privacy: .public)") }
        }
    }

    private func setLink(_ next: Link) {
        link = next
        offlineTask?.cancel()
        if next == .live { showsOffline = false; return }
        guard next == .offline else { return }
        offlineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self, link == .offline else { return }
            showsOffline = true
        }
    }

    private func handle(_ event: MobileGateway.Event) {
        switch event {
        case .turnStarted(let turn):
            apply(.started(turn: turn))
        case .accepted(let clientMessageID):
            // Taken durably. Its echo can lag behind a long-running turn, so stop treating it as unsent now.
            apply(.delivered(clientID: clientMessageID))
        case .message(let turn, let seq, let role, let content, let clientMessageID, let at):
            apply(.message(turn: turn, seq: seq, role: role, content: content, clientMessageID: clientMessageID, at: at))
        case .delta(let turn, let text, let replace, let progress):
            apply(.delta(turn: turn, text: text, replace: replace, progress: progress))
        case .retract(let turn):
            apply(.retract(turn: turn))
        case .status(let turn, let text):
            apply(.status(turn: turn, text: text))
        case .askUser(let q):
            // The gateway sends only a question whose turn is still running, and sends it again after a turn_end
            // clears it: an engine task's question belongs to the task, not to the chat turn that was running.
            question = Question(requestID: q.requestID, prompt: q.prompt, options: q.options, allowsFreeText: q.allowsFreeText)
            apply(.asked)
        case .taskProgress(let progress):
            tasks.removeAll { $0.taskID == progress.taskID }
            if progress.isRunning { tasks.append(progress) }
        case .turnEnded(let turn, let status):
            apply(.ended(turn: turn, status: status))
            question = nil
            completedTurns += 1
        case .history(_, let oldest, let hasMore, let messages):
            let page = ChatTranscript.Event.earlier(
                messages: messages.map { .init(turn: $0.turnSequence, seq: $0.sequence, role: $0.role, content: $0.content, at: $0.at) },
                oldestTurn: oldest, hasMore: hasMore)
            let wait = Self.minimumLoadingShown - Date().timeIntervalSince(earlierRequestedAt ?? .distantPast)
            if wait > 0 {
                Task { try? await Task.sleep(for: .seconds(wait)); apply(page) }
            } else {
                apply(page)
            }
        case .historyLoaded(let through):
            // The conversation kept on the phone can be gone from the gateway (its history was wiped and turns number
            // from 1 again). Its floor would then swallow the whole replay — every new turn looks already passed — so
            // start over from the gateway's own history; the kept window is only a cache of what it holds.
            if transcript.isStale(serverThrough: through) {
                transcript = ChatTranscript()
                scheduleSave()
                gateway.restart()
                return
            }
            setLink(.live)
        case .synchronizing:
            if link != .offline { setLink(.connecting) }
        case .offline:
            setLink(.offline)
        case .error(let message):
            // While older messages are being fetched, an error is that request's: it belongs at the top of the thread.
            if transcript.loadingEarlier { apply(.earlierFailed("Couldn\u{2019}t load earlier messages.")) }
            else { apply(.failed(message)) }
        }
    }
}

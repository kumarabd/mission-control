import Foundation
import Observation
import ClerkKit

@Observable
@MainActor
final class ChatStore {
    static let defaultAgent = "main"
    static let agentDefaultsKey = "gateway.macos.selectedAgentID"

    var sessions: [SessionSummary] = [.main()]
    var selectedSessionID = "main"
    var messages: [ConversationMessage] = []
    var pendingQuestion: GatewayQuestion?
    var connectionState: ConnectionState = .connecting
    var assistantState: AssistantState = .ready
    var draft = ""
    var errorMessage: String?
    /// Counts finished turns so a view can re-read what the turn changed.
    private(set) var completedTurns = 0
    /// Increments when another surface asks for the composer to be filled.
    private(set) var draftToken = 0
    /// Skill tasks the assistant is still working through, oldest first.
    private(set) var tasks: [TaskProgress] = []
    /// Replies that finished while Chat was not the visible surface.
    private(set) var unread = 0
    var isVisible = false { didSet { if isVisible { unread = 0 } } }
    var selectedAgentID = UserDefaults.standard.string(forKey: ChatStore.agentDefaultsKey) ?? ""

    var question: GatewayQuestion? { pendingQuestion }

    private var throughTurnSequence = 0
    private var client: GatewayClient?
    private var pollingTask: Task<Void, Never>?
    private var started = false

    var selectedSession: SessionSummary {
        sessions.first(where: { $0.sessionID == selectedSessionID }) ?? .main()
    }

    var isRunning: Bool {
        assistantState != .ready || selectedSession.isRunning
    }

    func start() {
        guard !started else { return }
        started = true
        let client = GatewayClient(baseURL: AppConfiguration.gatewayBaseURL) {
            try await Clerk.shared.auth.getToken()
        }
        client.onFrame = { [weak self] sessionID, frame in
            self?.apply(frame, for: sessionID)
        }
        client.onConnectionState = { [weak self] sessionID, state in
            guard let self, sessionID == nil || sessionID == self.selectedSessionID else { return }
            self.connectionState = state
            self.updatePolling()
        }
        self.client = client

        Task {
            await refreshSessions()
            connectSelectedSession()
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        client?.disconnect()
        started = false
    }

    func refreshSessions() async {
        guard let client else { return }
        do {
            var fetched = try await client.listSessions()
            if !fetched.contains(where: { $0.sessionID == "main" }) {
                fetched.insert(.main(), at: 0)
            }
            for local in sessions where !fetched.contains(where: { $0.id == local.id }) {
                fetched.append(local)
            }
            sessions = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSession(_ sessionID: String) {
        guard sessionID != selectedSessionID else { return }
        selectedSessionID = sessionID
        messages = []
        pendingQuestion = nil
        tasks = []
        assistantState = .ready
        throughTurnSequence = 0
        connectSelectedSession()
    }

    func newSession() {
        let id = UUID().uuidString.lowercased()
        let session = SessionSummary.newConversation(sessionID: id)
        sessions.append(session)
        selectedSessionID = id
        messages = []
        pendingQuestion = nil
        tasks = []
        assistantState = .ready
        throughTurnSequence = 0
        // Deliberately bypass normal selection/resume: a new conversation
        // closes the active socket and authenticates a new session with no
        // after_turn_seq cursor.
        client?.connectFreshSession(sessionID: id, agentID: selectedAgentID)
    }

    /// Branch the current conversation. The fork starts empty and names the
    /// parent; the gateway creates the child when the first message is sent.
    func forkSession() {
        let parent = selectedSession
        let id = UUID().uuidString.lowercased()
        let session = SessionSummary.forked(from: parent, sessionID: id)
        sessions.append(session)
        selectedSessionID = id
        messages = []
        pendingQuestion = nil
        tasks = []
        assistantState = .ready
        throughTurnSequence = 0
        client?.connect(sessionID: id, parentSessionID: parent.sessionID,
                        afterTurnSequence: nil, agentID: selectedAgentID)
    }

    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client else { return }
        draft = ""
        let clientMessageID = UUID().uuidString
        let optimistic = ConversationMessage(
            id: "pending:\(clientMessageID)",
            turnSequence: Int.max,
            sequence: messages.count,
            role: .user,
            text: text
        )
        messages.append(optimistic)
        assistantState = .thinking
        updateSelectedSession(running: true, preview: text)

        let sessionID = selectedSessionID
        let parentSessionID = selectedSession.parentSessionID
        Task {
            do {
                try await client.sendMessage(
                    text,
                    clientMessageID: clientMessageID,
                    sessionID: sessionID,
                    parentSessionID: parentSessionID
                )
                await refreshSessions()
            } catch {
                guard sessionID == selectedSessionID else { return }
                errorMessage = error.localizedDescription
                assistantState = .ready
                updateSelectedSession(running: false)
            }
        }
    }

    func cancel() {
        guard let client else { return }
        let sessionID = selectedSessionID
        Task {
            do { try await client.cancel(sessionID: sessionID) }
            catch where sessionID == selectedSessionID { errorMessage = error.localizedDescription }
            catch { }
        }
    }

    func answer(optionID: String? = nil, freeText: String? = nil) {
        guard let pendingQuestion, let client else { return }
        self.pendingQuestion = nil
        assistantState = .thinking
        let sessionID = selectedSessionID
        Task {
            do {
                try await client.answer(
                    requestID: pendingQuestion.requestID,
                    optionID: optionID,
                    freeText: freeText,
                    sessionID: sessionID
                )
            } catch {
                guard sessionID == selectedSessionID else { return }
                self.pendingQuestion = pendingQuestion
                errorMessage = error.localizedDescription
                assistantState = .ready
            }
        }
    }

    private func connectSelectedSession() {
        guard let client else { return }
        client.connect(
            sessionID: selectedSessionID,
            parentSessionID: selectedSession.parentSessionID,
            afterTurnSequence: throughTurnSequence,
            agentID: selectedAgentID
        )
    }

    /// Another surface starts the conversation: put its text in the composer.
    func request(draft text: String) {
        draft = text
        draftToken += 1
    }

    /// Send without waiting for a person to press return.
    func send(_ text: String) {
        draft = text
        sendDraft()
    }

    /// The default agent is stored as the absence of a preference, the same
    /// way the other clients resolve it.
    func setAgent(_ id: String) {
        let value = id == Self.defaultAgent ? "" : id
        selectedAgentID = value
        UserDefaults.standard.set(value, forKey: Self.agentDefaultsKey)
        if started { connectSelectedSession() }
    }

    private func apply(_ frame: GatewayFrame, for sessionID: String) {
        guard sessionID == selectedSessionID else { return }
        switch frame.type {
        case "turn_start":
            assistantState = .thinking
            updateSelectedSession(running: true)
        case "message":
            applyMessage(frame)
        case "delta":
            applyDelta(frame)
        case "tool_call":
            applyTool(frame)
        case "task_progress":
            guard let taskID = frame.taskID, let skill = frame.skill,
                  let step = frame.step, let total = frame.total, let state = frame.state else { return }
            tasks.removeAll { $0.taskID == taskID }
            if state == "running" {
                tasks.append(TaskProgress(taskID: taskID, skill: skill, step: step, total: total,
                                          title: frame.title ?? "", state: state))
            }
        case "ask_user":
            guard let requestID = frame.requestID, let prompt = frame.prompt else { return }
            pendingQuestion = .init(
                requestID: requestID,
                kind: frame.kind ?? "question",
                prompt: prompt,
                options: frame.options ?? [],
                allowsFreeText: frame.allowsFreeText ?? false
            )
            assistantState = .ready
            updateSelectedSession(running: false)
        case "turn_end":
            if let turn = frame.turnSequence {
                throughTurnSequence = max(throughTurnSequence, turn)
                for index in messages.indices where messages[index].turnSequence == turn {
                    messages[index].isComplete = true
                    messages[index].failed = frame.status != "completed"
                }
            }
            assistantState = .ready
            completedTurns += 1
            if !isVisible { unread += 1 }
            updateSelectedSession(running: false)
            Task { await refreshSessions() }
        case "resumed":
            if let turn = frame.throughTurnSequence {
                throughTurnSequence = max(throughTurnSequence, turn)
            }
        case "error":
            errorMessage = frame.message ?? "The gateway returned an error."
        default:
            break
        }
    }

    private func applyMessage(_ frame: GatewayFrame) {
        guard let turn = frame.turnSequence,
              let sequence = frame.sequence,
              let roleValue = frame.role,
              let role = ConversationMessage.Role(rawValue: roleValue) else { return }
        let id = "turn:\(turn):message:\(sequence)"
        if role == .user, let clientMessageID = frame.clientMessageID {
            messages.removeAll { $0.id == "pending:\(clientMessageID)" }
        }

        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].text = frame.content ?? ""
            return
        }

        var message = ConversationMessage(
            id: id,
            turnSequence: turn,
            sequence: sequence,
            role: role,
            text: frame.content ?? ""
        )
        if role == .assistant,
           let streamIndex = messages.firstIndex(where: { $0.id == "turn:\(turn):stream" }) {
            let stream = messages.remove(at: streamIndex)
            message.progressText = stream.progressText
            message.tools = stream.tools
            if message.text.isEmpty { message.text = stream.text }
        }
        upsert(message)
    }

    private func applyDelta(_ frame: GatewayFrame) {
        guard let turn = frame.turnSequence else { return }
        let id = "turn:\(turn):stream"
        var message = messages.first(where: { $0.id == id }) ?? .init(
            id: id,
            turnSequence: turn,
            sequence: Int.max - 1,
            role: .assistant,
            text: ""
        )
        if frame.progress == true {
            assistantState = .thinking
            message.progressText = frame.replace == true
                ? (frame.text ?? "")
                : message.progressText + (frame.text ?? "")
        } else {
            assistantState = .responding
            message.text = frame.replace == true ? (frame.text ?? "") : message.text + (frame.text ?? "")
        }
        upsert(message)
    }

    private func applyTool(_ frame: GatewayFrame) {
        guard let turn = frame.turnSequence,
              let messageSequence = frame.messageSequence,
              let toolID = frame.toolCallID,
              let toolName = frame.toolName else { return }
        let id = "turn:\(turn):message:\(messageSequence)"
        var message = messages.first(where: { $0.id == id }) ?? .init(
            id: id,
            turnSequence: turn,
            sequence: messageSequence,
            role: .assistant,
            text: ""
        )
        let tool = ToolActivity(
            id: toolID,
            name: toolName,
            status: frame.status ?? "running",
            arguments: frame.arguments,
            result: frame.result,
            partialOutput: frame.partialOutput ?? "",
            reason: frame.reason ?? "",
            startedAt: frame.startedAt,
            completedAt: frame.completedAt
        )
        if let index = message.tools.firstIndex(where: { $0.id == toolID }) {
            message.tools[index] = tool
        } else {
            message.tools.append(tool)
        }
        upsert(message)
        assistantState = .thinking
    }

    private func upsert(_ message: ConversationMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
        messages.sort {
            if $0.turnSequence != $1.turnSequence { return $0.turnSequence < $1.turnSequence }
            return $0.sequence < $1.sequence
        }
    }

    private func updateSelectedSession(running: Bool, preview: String? = nil) {
        guard let index = sessions.firstIndex(where: { $0.sessionID == selectedSessionID }) else { return }
        sessions[index].isRunning = running
        if let preview { sessions[index].preview = preview }
    }

    private func updatePolling() {
        pollingTask?.cancel()
        pollingTask = nil
        guard case .live = connectionState else {
            pollingTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.pollOnce()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
            return
        }
    }

    private func pollOnce() async {
        guard let client else { return }
        let sessionID = selectedSessionID
        let since = throughTurnSequence
        do {
            let response = try await client.poll(sessionID: sessionID, since: since)
            guard sessionID == selectedSessionID else { return }
            for turn in response.turns ?? [] {
                if !turn.userContent.isEmpty {
                    upsert(.init(
                        id: "turn:\(turn.turnSequence):poll:user",
                        turnSequence: turn.turnSequence,
                        sequence: 0,
                        role: .user,
                        text: turn.userContent,
                        isComplete: true
                    ))
                }
                if !turn.content.isEmpty {
                    upsert(.init(
                        id: "turn:\(turn.turnSequence):poll:assistant",
                        turnSequence: turn.turnSequence,
                        sequence: 1,
                        role: .assistant,
                        text: turn.content,
                        isComplete: true,
                        failed: turn.status != "completed"
                    ))
                }
                throughTurnSequence = max(throughTurnSequence, turn.turnSequence)
            }
            if let question = response.pendingInput {
                pendingQuestion = .init(
                    requestID: question.requestID,
                    kind: question.kind,
                    prompt: question.prompt,
                    options: question.options,
                    allowsFreeText: question.allowsFreeText
                )
            }
        } catch {
            // Realtime owns connection messaging. Polling remains a quiet,
            // durable recovery path and retries on its next interval.
        }
    }
}

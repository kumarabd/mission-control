import SwiftUI

/// The conversation with the assistant: what you asked for, and what it did about it. One thread — the gateway's iOS
/// session is a single one by design — replayed when the tab opens, so the phone shows the same conversation it had
/// before. Nothing is interpreted here; whatever the assistant creates is written through the Life Engine and appears
/// in Today, Goals and Reminders when the turn ends.
struct ChatView: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var voice = AssistantVoiceCoordinator()
    @State private var draft = ""
    @State private var receipts: [WorkspaceUpdate] = []
    @State private var selectedUpdate: WorkspaceUpdate?
    /// The message at the top before older ones were loaded, so the thread stays where it was instead of jumping.
    @State private var keepAtTop: String?
    @FocusState private var focused: Bool

    private var voiceOn: Bool { voice.state != .idle && voice.state != .unavailable }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.m) {
                        if chat.transcript.items.isEmpty && !chat.transcript.isRunning && !voiceOn { greeting }
                        if chat.transcript.hasMoreEarlier && !chat.transcript.items.isEmpty {
                            // Reaching the top asks for the next page of older messages, and says so while it waits.
                            earlierRow.onAppear { loadEarlier() }
                        }
                        ForEach(chat.transcript.displayed) { item in bubble(item).id(item.id) }
                        if voiceOn, !voice.conversationText.displayedUserText.isEmpty {
                            bubble(.init(id: "voice:you", role: .you, text: voice.conversationText.displayedUserText, turn: 0, streaming: false))
                        }
                        if voiceOn, !voice.conversationText.assistantText.isEmpty {
                            bubble(.init(id: "voice:assistant", role: .assistant, text: voice.conversationText.assistantText, turn: 0, streaming: false))
                        }
                        if chat.transcript.isWorking { working }
                        if !receipts.isEmpty { receiptsBlock }
                        if let question = chat.question { askBlock(question) }
                        if voice.state == .unavailable, !voice.message.isEmpty {
                            Text(voice.message).font(.mission(.callout)).foregroundStyle(Tok.critical)
                        }
                        if let failure = chat.transcript.failure {
                            Text(failure).font(.mission(.callout)).foregroundStyle(Tok.critical)
                        }
                    }
                    .padding(.horizontal, Space.l).padding(.vertical, Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chat.transcript.items.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: chat.transcript.items.last?.text) { _, _ in scrollToEnd(proxy) }
                .onChange(of: chat.question?.requestID) { _, _ in scrollToEnd(proxy) }
                .onChange(of: chat.transcript.earlier.count) { old, new in
                    guard new > old, let id = keepAtTop else { return }
                    keepAtTop = nil
                    proxy.scrollTo(id, anchor: .top)
                }
            }
            .screenBackground()
            .navigationTitle("Chat")
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AppMark() }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
            }
            .sheet(item: $selectedUpdate) { item in
                switch item.kind {
                case .goal: NavigationStack { GoalDetail(goalID: item.entityID).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedUpdate = nil } } } }
                case .routine: NavigationStack { RoutineDetailView(id: item.entityID).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedUpdate = nil } } } }
                case .reminder: ReminderDetailSheet(id: item.entityID)
                case .task: PlanItemDetailSheet(id: item.entityID)
                }
            }
            .onAppear {
                chat.beginInteraction()
                voice.updateGatewayAppActivity(scenePhase == .active)
                consumeDraft()
            }
            .onDisappear {
                chat.endInteraction()
                voice.updateGatewayAppActivity(false)
            }
            .onChange(of: scenePhase) { _, phase in if phase != .inactive { voice.updateGatewayAppActivity(phase == .active) } }
            .onChange(of: chat.draftToken) { _, _ in consumeDraft() }
            .onChange(of: chat.completedTurns) { _, _ in Task { await refresh() } }
            .onChange(of: voice.state) { old, new in
                // Back to listening after the assistant answered: whatever it created is ready to show.
                if new == .listening, old == .processing || old == .speaking { Task { await refresh() } }
            }
        }
    }

    // MARK: The thread

    private var greeting: some View {
        Text("Ask for anything: \u{201C}remind me to call Sam tomorrow at 5pm\u{201D}, \u{201C}I want to drink more water\u{201D}, \u{201C}what should I do with 20 minutes?\u{201D} Type, or tap the microphone and talk.")
            .font(.mission(.footnote)).foregroundStyle(Tok.muted)
    }

    private func bubble(_ item: ChatTranscript.Item) -> some View {
        HStack(spacing: 0) {
            if item.role == .you { Spacer(minLength: 48) }
            Group {
                if item.role == .assistant { MarkdownView(text: item.text) }
                else { Text(item.text).font(.mission(.body)).foregroundStyle(Tok.text) }
            }
            .textSelection(.enabled)
            .padding(Space.m)
            .background(item.role == .you ? Tok.accent.opacity(0.14) : Tok.surface, in: MissionTheme.cardShape)
            .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
            if item.role == .assistant { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel((item.role == .you ? "You: " : "Assistant: ") + item.text)
    }

    private var working: some View {
        HStack(spacing: Space.s) {
            ProgressView()
            Text(chat.transcript.progress.isEmpty ? "Thinking\u{2026}" : chat.transcript.progress)
                .font(.mission(.footnote)).foregroundStyle(Tok.muted)
        }
        .accessibilityElement(children: .combine)
    }

    /// A question the assistant needs answered, with its suggested answers as buttons.
    private func askBlock(_ q: ChatModel.Question) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            MarkdownView(text: q.prompt)
            ForEach(q.options, id: \.id) { option in
                Button(option.label) { chat.answer(q, optionID: option.id) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var receiptsBlock: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Workspace updates").font(.mission(.headline, .medium))
            ForEach(receipts) { item in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(item.title).font(.mission(.body))
                    Text(item.detail).font(.mission(.caption)).foregroundStyle(Tok.muted)
                    HStack {
                        Button("View") { selectedUpdate = item }
                        Button("Change") { draft = "Change my \(item.kind.rawValue) \u{201C}\(item.title)\u{201D}: "; focused = true }
                    }.frame(minHeight: 44)
                }
            }
        }
        .padding(Space.m)
        .background(Tok.raised, in: MissionTheme.cardShape)
    }

    // MARK: Bottom bar: type, or talk

    @ViewBuilder private var bottomBar: some View {
        if voiceOn {
            HStack(spacing: Space.m) {
                Text(voiceStatus).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                Spacer()
                Button(role: .destructive) { endVoice() } label: { Label("End voice", systemImage: "stop.circle.fill") }
                    .buttonStyle(.borderedProminent).tint(Tok.critical).frame(minHeight: 44)
            }
            .padding(Space.m)
            .background(Tok.surface)
            .overlay(alignment: .top) { Rectangle().fill(Tok.hairline).frame(height: 1) }
        } else {
            HStack(alignment: .bottom, spacing: Space.s) {
                TextField(chat.question == nil ? "What do you want to remember or do?" : "Your answer", text: $draft, axis: .vertical)
                    .font(.mission(.body)).lineLimit(1...5).focused($focused)
                    .padding(Space.m).background(Tok.surface, in: MissionTheme.cardShape)
                    .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
                Button { startVoice() } label: {
                    Image(systemName: "mic.fill").font(.mission(.headline, .semibold)).foregroundStyle(Tok.accent)
                        .frame(width: 44, height: 44).background(Tok.accent.opacity(0.14), in: Circle())
                }
                .disabled(chat.transcript.isWorking).accessibilityLabel("Talk instead")
                if chat.transcript.isWorking {
                    Button { chat.cancelTurn() } label: {
                        Image(systemName: "stop.fill").font(.mission(.headline, .semibold)).foregroundStyle(Tok.onAccent)
                            .frame(width: 44, height: 44).background(Tok.accent.opacity(0.6), in: Circle())
                    }
                    .accessibilityLabel("Stop")
                } else {
                    Button { send() } label: {
                        Image(systemName: "arrow.up").font(.mission(.headline, .semibold)).foregroundStyle(Tok.onAccent)
                            .frame(width: 44, height: 44).background(Tok.accent.opacity(canSend ? 1 : 0.35), in: Circle())
                    }
                    .disabled(!canSend).accessibilityLabel("Send")
                }
            }
            .padding(Space.m)
            .background(Tok.surface)
            .overlay(alignment: .top) { Rectangle().fill(Tok.hairline).frame(height: 1) }
        }
    }

    private var canSend: Bool {
        !draft.trimmed.isEmpty && !chat.transcript.isWorking
            && (chat.question == nil || chat.question!.allowsFreeText || chat.question!.options.isEmpty)
    }

    private var voiceStatus: String {
        switch voice.state {
        case .preparing: "Getting ready\u{2026}"
        case .listening: "Listening\u{2026}"
        case .processing: "Thinking\u{2026}"
        case .speaking: "Speaking\u{2026}"
        case .idle, .unavailable: ""
        }
    }

    // MARK: Actions

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        draft = ""
        receipts = []
        if let question = chat.question { chat.answer(question, text: text) } else { chat.send(text) }
    }

    private func consumeDraft() {
        if let draft = chat.consumeDraft(), !draft.isEmpty { self.draft = draft; focused = true }
    }

    private var earlierRow: some View {
        HStack(spacing: Space.s) {
            if chat.transcript.loadingEarlier {
                ProgressView()
                Text("Loading earlier messages\u{2026}").font(.mission(.footnote)).foregroundStyle(Tok.muted)
            } else if let failure = chat.transcript.earlierFailure {
                Text(failure).font(.mission(.footnote)).foregroundStyle(Tok.muted)
                Button("Try again") { loadEarlier() }.font(.mission(.footnote)).frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    private func loadEarlier() {
        keepAtTop = chat.transcript.displayed.first?.id
        chat.loadEarlier()
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        guard let last = chat.transcript.items.last?.id else { return }
        if reduceMotion { proxy.scrollTo(last, anchor: .bottom) }
        else { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last, anchor: .bottom) } }
    }

    private func refresh() async {
        let before = life.workspaceUpdates
        await life.refreshWorkspace()
        receipts = life.workspaceUpdates.filter { item in before.first(where: { $0.id == item.id }) != item }
    }

    /// Talking replaces typing: the text connection steps aside so the two never answer the same turn.
    private func startVoice() {
        if chat.transcript.isRunning || chat.question != nil { chat.cancelTurn() }
        chat.endInteraction()
        receipts = []
        voice.updateGatewayAppActivity(scenePhase == .active)
        voice.toggle()
    }

    /// Hands back to the text thread, which replays the tail so the spoken turns land in the conversation.
    private func endVoice() {
        voice.toggle()
        chat.beginInteraction()
        Task { await refresh() }
    }
}

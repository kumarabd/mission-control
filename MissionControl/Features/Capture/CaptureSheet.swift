import SwiftUI

/// Remember this: say it or type it, and it goes straight to the assistant. The sheet is a conversation that shows only the
/// latest request and the latest response, so there is no history to scroll; when the assistant asks something, answer in place.
///
/// Nothing is interpreted on the phone. The assistant decides what it is and saves it through the Life Engine, the same
/// operations the app uses; whatever it creates shows up in Today and Progress when the turn ends. Voice is the Classic tab's
/// voice assistant (on-device speech recognition, spoken replies, hands-free), pointed at the same conversation.
struct CaptureSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var voice = AssistantVoiceCoordinator()
    @State private var request = ""
    @State private var response = ""
    @State private var question: AgentCapture.Question?
    @State private var draft = ""
    @State private var error: String?
    @State private var sending = false
    @State private var agent = AgentCapture()
    @FocusState private var focused: Bool

    /// `draft` pre-fills the box, for a screen that starts the conversation (a new goal, a goal you keep putting off).
    init(draft: String = "") { _draft = State(initialValue: draft) }

    private var voiceOn: Bool { voice.state != .idle && voice.state != .unavailable }
    private var you: String { voiceOn ? voice.conversationText.displayedUserText : request }
    private var assistant: String { voiceOn ? voice.conversationText.assistantText : response }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                exchange
                Divider().overlay(Tok.hairline)
                bottomBar
            }
            .screenBackground()
            .navigationTitle("Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(you.isEmpty && assistant.isEmpty ? "Cancel" : "Done") { leave() } } }
            .onAppear { focused = true; voice.updateGatewayAppActivity(scenePhase == .active) }
            .onChange(of: scenePhase) { _, phase in if phase != .inactive { voice.updateGatewayAppActivity(phase == .active) } }
            .onChange(of: voice.state) { old, new in
                // Back to listening after the assistant answered: whatever it created is ready to show.
                if new == .listening, old == .processing || old == .speaking { Task { await refresh() } }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(sending || question != nil || voiceOn)
    }

    // MARK: The latest exchange

    private var exchange: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if you.isEmpty && assistant.isEmpty && !sending && !voiceOn {
                    Text("Try \u{201C}remind me to call Sam tomorrow at 5pm\u{201D} or \u{201C}I want to drink more water\u{201D}. Type, or tap the microphone and talk.")
                        .font(.mission(.footnote)).foregroundStyle(Tok.muted)
                }
                if !you.isEmpty { line("YOU", you, emphasised: false) }
                if voiceOn { Label(voiceStatus, systemImage: voiceSymbol).font(.missionMono(.caption, .medium)).foregroundStyle(Tok.accent) }
                if sending { HStack { ProgressView(); Text("Thinking\u{2026}").font(.mission(.footnote)).foregroundStyle(Tok.muted) } }
                if voiceOn, !voice.progressNarration.isEmpty, assistant.isEmpty {
                    Text(voice.progressNarration).font(.mission(.footnote)).foregroundStyle(Tok.muted)
                }
                if !assistant.isEmpty { line("ASSISTANT", assistant, emphasised: true) }
                if let question { askBlock(question) }
                if voice.state == .unavailable, !voice.message.isEmpty { Text(voice.message).font(.mission(.callout)).foregroundStyle(Tok.critical) }
                if let error { Text(error).font(.mission(.callout)).foregroundStyle(Tok.critical) }
            }
            .padding(Space.l).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func line(_ label: String, _ text: String, emphasised: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            if emphasised { MarkdownView(text: text) } else { Text(text).font(.mission(.body)).foregroundStyle(Tok.text).textSelection(.enabled) }
        }
        .accessibilityElement(children: .combine)
    }

    /// A question the assistant needs answered, with its suggested answers as buttons.
    private func askBlock(_ q: AgentCapture.Question) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            MarkdownView(text: q.prompt)
            ForEach(q.options, id: \.id) { option in
                Button(option.label) { answer(q, optionID: option.id, shown: option.label) }
                    .buttonStyle(SecondaryButtonStyle()).disabled(sending)
            }
        }
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
        } else {
            HStack(alignment: .bottom, spacing: Space.s) {
                TextField(question == nil ? "What do you want to remember or do?" : "Your answer", text: $draft, axis: .vertical)
                    .font(.mission(.body)).lineLimit(1...5).focused($focused)
                    .padding(Space.m).background(Tok.surface, in: MissionTheme.cardShape)
                    .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
                Button { startVoice() } label: {
                    Image(systemName: "mic.fill").font(.mission(.headline, .semibold)).foregroundStyle(Tok.accent)
                        .frame(width: 44, height: 44).background(Tok.accent.opacity(0.14), in: Circle())
                }
                .disabled(sending).accessibilityLabel("Talk instead")
                Button { send() } label: {
                    Image(systemName: "arrow.up").font(.mission(.headline, .semibold)).foregroundStyle(Tok.onAccent)
                        .frame(width: 44, height: 44).background(Tok.accent.opacity(canSend ? 1 : 0.35), in: Circle())
                }
                .disabled(!canSend).accessibilityLabel("Send")
            }
            .padding(Space.m)
        }
    }

    private var canSend: Bool { !draft.trimmed.isEmpty && !sending && (question == nil || question!.allowsFreeText || question!.options.isEmpty) }

    private var voiceStatus: String {
        switch voice.state {
        case .preparing: "Getting ready\u{2026}"
        case .listening: "Listening\u{2026}"
        case .processing: "Thinking\u{2026}"
        case .speaking: "Speaking\u{2026}"
        case .idle, .unavailable: ""
        }
    }
    private var voiceSymbol: String {
        switch voice.state {
        case .speaking: "speaker.wave.2.fill"
        case .processing: "ellipsis"
        default: "waveform"
        }
    }

    // MARK: Actions

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        draft = ""
        if let q = question { answer(q, text: text, shown: text) } else { run(shown: text) { try await agent.send(text) } }
    }

    private func answer(_ q: AgentCapture.Question, optionID: String? = nil, text: String? = nil, shown: String) {
        run(shown: shown) { try await agent.answer(q, optionID: optionID, text: text) }
    }

    /// One step with the assistant. Only this exchange is shown: what you said, then what came back (its answer, or a question).
    private func run(shown: String, _ step: @escaping () async throws -> AgentCapture.Outcome) {
        request = shown; response = ""
        sending = true; error = nil; question = nil
        Task {
            do {
                switch try await step() {
                case .reply(let r):
                    response = r.isEmpty ? "Done." : r
                    await refresh()
                case .question(let q):
                    question = q
                }
            } catch { self.error = error.localizedDescription }
            sending = false
            focused = true
        }
    }

    private func refresh() async {
        async let reminders: Void = life.loadReminders()
        async let routines: Void = life.loadRoutines()
        _ = await (reminders, routines)
    }

    /// Talking replaces typing: the text connection steps aside so the two never answer the same turn.
    private func startVoice() {
        if sending || question != nil { agent.cancel() }
        agent.close()
        question = nil; error = nil; sending = false
        voice.updateGatewayAppActivity(scenePhase == .active)
        voice.toggle()
    }

    /// Keeps the last exchange on screen after the microphone stops, then reads whatever the assistant created.
    private func endVoice() {
        request = voice.conversationText.userText
        response = voice.conversationText.assistantText
        voice.toggle()
        Task { await refresh() }
    }

    /// Leaving while the assistant is working or waiting on an answer stops that turn, so it is not left hanging.
    private func leave() {
        if voiceOn { voice.cancel() }
        voice.updateGatewayAppActivity(false)
        if sending || question != nil { agent.cancel() }
        let agent = agent
        Task { try? await Task.sleep(for: .milliseconds(600)); agent.close() }
        Task { await refresh() }
        dismiss()
    }
}

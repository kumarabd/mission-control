import SwiftUI

/// Remember this: a line typed or dictated (the keyboard microphone) goes straight to the assistant, and the sheet stays a
/// conversation, so when it asks something you can answer in place.
///
/// Nothing is interpreted on the phone. The assistant decides what it is and saves it through the Life Engine, the same operations
/// the app uses; whatever it creates shows up in Today and Progress when the turn ends.
struct CaptureSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Line] = []
    @State private var question: AgentCapture.Question?
    @State private var draft = ""
    @State private var error: String?
    @State private var sending = false
    @State private var agent = AgentCapture()
    @FocusState private var focused: Bool

    struct Line: Identifiable {
        let id = UUID()
        let fromYou: Bool
        let text: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcript
                Divider().overlay(Tok.hairline)
                composer
            }
            .screenBackground()
            .navigationTitle("Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(messages.isEmpty ? "Cancel" : "Done") { leave() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(sending || question != nil)
    }

    // MARK: Conversation

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    if messages.isEmpty {
                        Text("Try \u{201C}remind me to call Sam tomorrow at 5pm\u{201D} or \u{201C}I want to drink more water\u{201D}. Tap the keyboard's microphone to speak.")
                            .font(.mission(.footnote)).foregroundStyle(Tok.muted)
                    }
                    ForEach(messages) { bubble($0) }
                    if sending { HStack { ProgressView(); Text("Thinking\u{2026}").font(.mission(.footnote)).foregroundStyle(Tok.muted) } }
                    if let question { askBlock(question) }
                    if let error { Text(error).font(.mission(.callout)).foregroundStyle(Tok.critical) }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(Space.l)
            }
            .onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo("end") } }
            .onChange(of: sending) { _, _ in withAnimation { proxy.scrollTo("end") } }
        }
    }

    private func bubble(_ line: Line) -> some View {
        HStack {
            if line.fromYou { Spacer(minLength: Space.xl) }
            Text(line.text).font(.mission(.body)).foregroundStyle(line.fromYou ? Tok.onAccent : Tok.text)
                .padding(Space.m)
                .background(line.fromYou ? Tok.accent : Tok.surface, in: MissionTheme.cardShape)
                .overlay { if !line.fromYou { MissionTheme.cardShape.strokeBorder(Tok.hairline) } }
            if !line.fromYou { Spacer(minLength: Space.xl) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel((line.fromYou ? "You: " : "Assistant: ") + line.text)
    }

    /// A question the assistant needs answered, with its suggested answers as buttons.
    private func askBlock(_ q: AgentCapture.Question) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(q.prompt).font(.mission(.body)).padding(Space.m)
                .background(Tok.surface, in: MissionTheme.cardShape).overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
            ForEach(q.options, id: \.id) { option in
                Button(option.label) { answer(q, optionID: option.id, shown: option.label) }
                    .buttonStyle(SecondaryButtonStyle()).disabled(sending)
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Space.s) {
            TextField(question == nil ? (messages.isEmpty ? "What do you want to remember or do?" : "Reply") : "Your answer", text: $draft, axis: .vertical)
                .font(.mission(.body)).lineLimit(1...5).focused($focused)
                .padding(Space.m).background(Tok.surface, in: MissionTheme.cardShape)
                .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
            Button { send() } label: {
                Image(systemName: "arrow.up").font(.mission(.headline, .semibold)).foregroundStyle(Tok.onAccent)
                    .frame(width: 44, height: 44).background(Tok.accent.opacity(canSend ? 1 : 0.35), in: Circle())
            }
            .disabled(!canSend).accessibilityLabel("Send")
        }
        .padding(Space.m)
    }

    private var canSend: Bool { !draft.trimmed.isEmpty && !sending && (question == nil || question!.allowsFreeText || question!.options.isEmpty) }

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

    /// One step with the assistant: show what you said, then what came back (its answer, or a question it needs answered).
    private func run(shown: String, _ step: @escaping () async throws -> AgentCapture.Outcome) {
        messages.append(Line(fromYou: true, text: shown))
        sending = true; error = nil; question = nil
        Task {
            do {
                switch try await step() {
                case .reply(let r):
                    messages.append(Line(fromYou: false, text: r.isEmpty ? "Done." : r))
                    async let reminders: Void = life.loadReminders()
                    async let routines: Void = life.loadRoutines()
                    _ = await (reminders, routines)
                case .question(let q):
                    question = q
                }
            } catch { self.error = error.localizedDescription }
            sending = false
            focused = true
        }
    }

    /// Leaving while the assistant is working or waiting on an answer stops that turn, so it is not left hanging.
    private func leave() {
        if sending || question != nil { agent.cancel() }
        let agent = agent
        Task { try? await Task.sleep(for: .milliseconds(600)); agent.close() }
        dismiss()
    }
}

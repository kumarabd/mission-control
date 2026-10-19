import SwiftUI

/// A goal's own conversation: the gateway's session for this goal alone, so what is said here, and what the assistant
/// does about it, stays on the goal. It opens at the last exchange and fetches earlier messages as you scroll up.
struct GoalChatView: View {
    let goal: Wire.Goal
    var model: ChatModel
    var onDone: () -> Void
    @Environment(Life.self) private var life
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    /// The message at the top before older ones were loaded, so the thread stays where it was instead of jumping.
    @State private var keepAtTop: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.m) {
                        if model.transcript.items.isEmpty && !model.transcript.isRunning { greeting }
                        if model.transcript.hasMoreEarlier && !model.transcript.items.isEmpty {
                            earlierRow.onAppear { loadEarlier() }
                        }
                        ForEach(model.transcript.displayed) { item in ChatBubble(item: item).id(item.id) }
                        if model.transcript.isWorking { working }
                        if let question = model.question { askBlock(question) }
                        if let failure = model.transcript.failure {
                            Text(failure).font(.mission(.callout)).foregroundStyle(Tok.critical)
                        }
                    }
                    .padding(.horizontal, Space.l).padding(.vertical, Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.transcript.items.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: model.transcript.items.last?.text) { _, _ in scrollToEnd(proxy) }
                .onChange(of: model.question?.requestID) { _, _ in scrollToEnd(proxy) }
                .onChange(of: model.transcript.earlier.count) { old, new in
                    guard new > old, let id = keepAtTop else { return }
                    keepAtTop = nil
                    proxy.scrollTo(id, anchor: .top)
                }
            }
            .screenBackground()
            .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { composer }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDone) } }
            .onAppear { model.beginInteraction(); consumeDraft() }
            .onDisappear { model.endInteraction() }
            .onChange(of: model.draftToken) { _, _ in consumeDraft() }
            .onChange(of: model.completedTurns) { _, _ in Task { await life.refreshWorkspace() } }
        }
    }

    private var greeting: some View {
        Text("This chat is about \u{201C}\(goal.title)\u{201D} alone. Tell me how it is going, ask me to change its view, steps or routines, or ask what to do next.")
            .font(.mission(.footnote)).foregroundStyle(Tok.muted)
    }

    private var working: some View {
        HStack(spacing: Space.s) {
            ProgressView()
            Text(model.transcript.progress.isEmpty ? "Thinking\u{2026}" : model.transcript.progress)
                .font(.mission(.footnote)).foregroundStyle(Tok.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private func askBlock(_ q: ChatModel.Question) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            MarkdownView(text: q.prompt)
            ForEach(q.options, id: \.id) { option in
                Button(option.label) { model.answer(q, optionID: option.id) }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var earlierRow: some View {
        HStack(spacing: Space.s) {
            if model.transcript.loadingEarlier {
                ProgressView()
                Text("Loading earlier messages\u{2026}").font(.mission(.footnote)).foregroundStyle(Tok.muted)
            } else if let failure = model.transcript.earlierFailure {
                Text(failure).font(.mission(.footnote)).foregroundStyle(Tok.muted)
                Button("Try again") { loadEarlier() }.font(.mission(.footnote)).frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Space.s) {
            TextField(model.question == nil ? "Say something about this goal" : "Your answer", text: $draft, axis: .vertical)
                .font(.mission(.body)).lineLimit(1...5).focused($focused)
                .padding(Space.m).background(Tok.surface, in: MissionTheme.cardShape)
                .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
            if model.transcript.isWorking {
                Button { model.cancelTurn() } label: {
                    Image(systemName: "stop.fill").font(.mission(.headline, .semibold)).foregroundStyle(Tok.onAccent)
                        .frame(width: 44, height: 44).background(Tok.accent.opacity(0.6), in: Circle())
                }.accessibilityLabel("Stop")
            } else {
                Button { send() } label: {
                    Image(systemName: "arrow.up").font(.mission(.headline, .semibold)).foregroundStyle(Tok.onAccent)
                        .frame(width: 44, height: 44).background(Tok.accent.opacity(canSend ? 1 : 0.35), in: Circle())
                }.disabled(!canSend).accessibilityLabel("Send")
            }
        }
        .padding(Space.m).background(Tok.surface)
        .overlay(alignment: .top) { Rectangle().fill(Tok.hairline).frame(height: 1) }
    }

    private var canSend: Bool {
        !draft.trimmed.isEmpty && !model.transcript.isWorking
            && (model.question == nil || model.question!.allowsFreeText || model.question!.options.isEmpty)
    }

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty else { return }
        draft = ""
        if let question = model.question { model.answer(question, text: text) } else { model.send(text) }
    }

    private func consumeDraft() {
        if let text = model.consumeDraft(), !text.isEmpty { draft = text; focused = true }
    }

    private func loadEarlier() {
        keepAtTop = model.transcript.displayed.first?.id
        model.loadEarlier()
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        guard let last = model.transcript.items.last?.id else { return }
        if reduceMotion { proxy.scrollTo(last, anchor: .bottom) }
        else { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last, anchor: .bottom) } }
    }
}

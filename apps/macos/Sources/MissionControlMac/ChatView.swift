import SwiftUI

struct ChatView: View {
    @Bindable var store: ChatStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            if let question = store.pendingQuestion {
                PendingQuestionView(question: question, onAnswer: store.answer)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }
            ComposerView(store: store)
        }
        .background(MissionTheme.canvas)
        .navigationTitle(store.selectedSession.title)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.selectedSession.title)
                    .font(.mission(.title3, .bold))
                    .foregroundStyle(MissionTheme.ink)
                    .lineLimit(1)
                Text(store.selectedSession.parentSessionID == nil ? "Main desktop conversation" : "Desktop conversation")
                    .font(.mission(.caption))
                    .foregroundStyle(MissionTheme.quietText)
            }
            Spacer()
            HStack(spacing: 8) {
                if store.assistantState != .ready {
                    ProgressView().controlSize(.small)
                }
                Text(store.assistantState.rawValue.lowercased())
                    .font(.missionMono(.callout, .medium))
                    .foregroundStyle(MissionTheme.tint)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(MissionTheme.tint.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(MissionTheme.tint.opacity(0.24)))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    if store.messages.isEmpty {
                        EmptyConversationView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 110)
                    }
                    ForEach(store.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                    }
                }
                .frame(maxWidth: 820)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: store.messages) { _, messages in
                guard let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
}

private struct EmptyConversationView: View {
    var body: some View {
        VStack(spacing: 13) {
            AssistantGlyph(size: 124)
            Text("What can I help you accomplish?")
                .font(.mission(.title2, .semibold))
                .foregroundStyle(MissionTheme.ink)
            Text("Messages, progress, tool calls, and approvals stay together in this conversation.")
                .foregroundStyle(MissionTheme.quietText)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ComposerView: View {
    @Bindable var store: ChatStore

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message Mission Control", text: $store.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...7)
                .font(.mission(.body))
                .foregroundStyle(MissionTheme.ink)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) { store.sendDraft() }
                }
            if store.isRunning {
                Button(action: store.cancel) {
                    Image(systemName: "stop.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .help("Stop response")
            } else {
                Button(action: store.sendDraft) {
                    Image(systemName: "arrow.up")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send")
            }
        }
        .padding(12)
        .background(MissionTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MissionTheme.line))
        .frame(maxWidth: 820)
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
    }
}

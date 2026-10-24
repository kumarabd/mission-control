import SwiftUI

/// A pending ask from the assistant, drawn as its own card in the thread instead of loose text: an `ask_user`
/// question, or a permission request ("Approve calling restaurants/book?"). One component for both, so every ask
/// looks the same and is answered where it is asked — an option button, or typing in the card. All it needs is the
/// prompt and the ways it can be answered: options, free text, or both.
struct AskBubble: View {
    let question: ChatModel.Question
    var agent = ChatParty(name: "Assistant")
    var showsPrompt = true
    let onOption: (ChatModel.Question, MobileGateway.GatewayQuestion.Option) -> Void
    let onText: (ChatModel.Question, String) -> Void

    @State private var reply = ""
    @FocusState private var focused: Bool

    private var prompt: String { ToolCallText.stripped(question.prompt).trimmed }
    private var canSend: Bool { !reply.trimmed.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            AvatarView(name: agent.name, url: agent.imageURL, size: ChatBubble.avatarSize, agent: true)
            VStack(alignment: .leading, spacing: Space.m) {
                if showsPrompt, !prompt.isEmpty {
                    MarkdownView(text: prompt)
                }
                if !question.options.isEmpty { options }
                if question.allowsFreeText { answerField }
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tok.accent.opacity(0.08), in: MissionTheme.cardShape)
            .overlay { MissionTheme.cardShape.strokeBorder(Tok.accent.opacity(0.3)) }
            Spacer(minLength: 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(agent.name) asks: \(prompt)")
    }

    private var options: some View {
        VStack(spacing: Space.s) {
            ForEach(question.options, id: \.id) { option in
                Button(option.label) { onOption(question, option) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var answerField: some View {
        HStack(alignment: .bottom, spacing: Space.s) {
            TextField(question.options.isEmpty ? "Your answer" : "Or type your answer", text: $reply, axis: .vertical)
                .font(.mission(.body)).lineLimit(1...4).focused($focused)
                .padding(.horizontal, Space.m).padding(.vertical, 10)
                .background(Tok.surface, in: MissionTheme.cardShape)
                .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.mission(.subheadline, .semibold)).foregroundStyle(Tok.onAccent)
                    .frame(width: 40, height: 40)
                    .background(Tok.accent.opacity(canSend ? 1 : 0.35), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send answer")
        }
    }

    private func submit() {
        let text = reply.trimmed
        guard !text.isEmpty else { return }
        reply = ""
        focused = false
        onText(question, text)
    }
}

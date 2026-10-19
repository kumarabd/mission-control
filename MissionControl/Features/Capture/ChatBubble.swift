import SwiftUI

/// One message of a conversation: yours on the right, the assistant's (set as markdown) on the left.
struct ChatBubble: View {
    let item: ChatTranscript.Item

    var body: some View {
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
}

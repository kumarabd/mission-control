import SwiftUI

/// Every assistant reply, drawn compactly: a short one as it is, a long one as a sentence or two. Expanding is a
/// long-press action on the bubble, which opens the whole message over a blurred thread.
struct AssistantMessage: View {
    let id: String
    let text: String
    let streaming: Bool

    /// Seeded from the store, so a row that is rebuilt (scrolled back in, or its stream replaced by the saved message) draws
    /// the same compact text from its first frame rather than regenerating it.
    @State private var summary: String?

    init(id: String, text: String, streaming: Bool) {
        self.id = id; self.text = text; self.streaming = streaming
        _summary = State(initialValue: streaming ? nil : MessageCondenser.shared.cached(text))
    }

    /// A reply that already fits in a sentence or two needs no model call.
    private var needsSummary: Bool { !streaming && MessageCondenser.isLong(text) }

    var body: some View {
        Group {
            if needsSummary {
                MarkdownView(text: summary ?? MessageCondenser.preview(text))
            } else {
                MarkdownView(text: text)
            }
        }
        .task(id: needsSummary ? text : "") {
            guard needsSummary, summary == nil else { return }
            let made = await MessageCondenser.shared.summary(of: text)
            // The swap changes the bubble's height; doing it unanimated keeps the thread from visibly shifting.
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { summary = made }
        }
    }
}

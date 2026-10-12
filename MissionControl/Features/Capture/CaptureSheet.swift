import SwiftUI

/// Remember this: one line (typed or dictated with the keyboard microphone) goes straight to the agent.
///
/// Nothing is interpreted on the phone. The agent decides what it is and saves it through the Life Engine, the same
/// operations the app uses; reminders it sets show up on Today when the turn ends.
struct CaptureSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var reply: String?
    @State private var error: String?
    @State private var sending = false
    @State private var agent = AgentCapture()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.l) {
                if let reply { result(reply) } else { input }
            }
            .padding(Space.l).screenBackground()
            .navigationTitle("Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(reply == nil ? "Cancel" : "Done") { dismiss() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private var input: some View {
        Group {
            TextField("What do you want to remember or do?", text: $text, axis: .vertical)
                .font(.mission(.title3)).lineLimit(3...8).focused($focused)
                .padding(Space.l).background(Tok.surface, in: MissionTheme.cardShape)
                .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
            Text("Try \u{201C}remind me to call Sam tomorrow at 5pm\u{201D} or \u{201C}decided to walk after lunch because I focus better\u{201D}. Tap the keyboard's microphone to speak.")
                .font(.mission(.footnote)).foregroundStyle(Tok.muted)
            if let error { Text(error).font(.mission(.callout)).foregroundStyle(Tok.critical) }
            Spacer()
            Button {
                sending = true; error = nil
                Task {
                    do { reply = try await agent.send(text.trimmed); await life.loadReminders() }
                    catch { self.error = error.localizedDescription }
                    sending = false
                }
            } label: { if sending { ProgressView().tint(Tok.onAccent) } else { Text("Send") } }
                .buttonStyle(PrimaryButtonStyle()).disabled(text.trimmed.isEmpty || sending)
        }
    }

    private func result(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(text.trimmed).font(.mission(.footnote)).foregroundStyle(Tok.muted)
            ScrollView { Text(answer.isEmpty ? "Done." : answer).font(.mission(.title3)).frame(maxWidth: .infinity, alignment: .leading) }
            Button("Add another") { text = ""; reply = nil; focused = true }.buttonStyle(SecondaryButtonStyle())
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }
}

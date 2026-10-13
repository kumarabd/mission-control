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
    @State private var question: AgentCapture.Question?
    @State private var answerText = ""
    @State private var error: String?
    @State private var sending = false
    @State private var agent = AgentCapture()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.l) {
                if let reply { result(reply) } else if let question { ask(question) } else { input }
            }
            .padding(Space.l).screenBackground()
            .navigationTitle("Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(reply == nil ? "Cancel" : "Done") { leave() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(sending || question != nil)
    }

    /// Leaving while the assistant is working or waiting on an answer stops that turn, so it is not left hanging.
    private func leave() {
        if sending || question != nil { agent.cancel() }
        let agent = agent
        Task { try? await Task.sleep(for: .milliseconds(600)); agent.close() }
        dismiss()
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
                run { try await agent.send(text.trimmed) }
            } label: { if sending { ProgressView().tint(Tok.onAccent) } else { Text("Send") } }
                .buttonStyle(PrimaryButtonStyle()).disabled(text.trimmed.isEmpty || sending)
        }
    }

    /// The assistant needs something first, such as the times for "remind me 3 times a day".
    private func ask(_ q: AgentCapture.Question) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(text.trimmed).font(.mission(.footnote)).foregroundStyle(Tok.muted)
            Text(q.prompt).font(.mission(.title3)).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(q.options, id: \.id) { option in
                Button(option.label) { run { try await agent.answer(q, optionID: option.id) } }
                    .buttonStyle(SecondaryButtonStyle()).disabled(sending)
            }
            if q.allowsFreeText || q.options.isEmpty {
                TextField("Your answer", text: $answerText, axis: .vertical)
                    .font(.mission(.body)).lineLimit(1...4)
                    .padding(Space.m).background(Tok.surface, in: MissionTheme.cardShape)
                    .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
                Button {
                    let answer = answerText.trimmed
                    run { try await agent.answer(q, text: answer) }
                } label: { if sending { ProgressView().tint(Tok.onAccent) } else { Text("Answer") } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(answerText.trimmed.isEmpty || sending)
            }
            if let error { Text(error).font(.mission(.callout)).foregroundStyle(Tok.critical) }
            Spacer()
        }
    }

    private func result(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(text.trimmed).font(.mission(.footnote)).foregroundStyle(Tok.muted)
            ScrollView { Text(answer.isEmpty ? "Done." : answer).font(.mission(.title3)).frame(maxWidth: .infinity, alignment: .leading) }
            Button("Add another") { text = ""; reply = nil; question = nil; answerText = ""; focused = true }.buttonStyle(SecondaryButtonStyle())
            Button("Done") { leave() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    /// Runs one step with the assistant and shows what came back: its answer, or a question it needs answered.
    private func run(_ step: @escaping () async throws -> AgentCapture.Outcome) {
        sending = true; error = nil
        Task {
            do {
                switch try await step() {
                case .reply(let r): question = nil; answerText = ""; reply = r; await life.loadReminders()
                case .question(let q): question = q; answerText = ""
                }
            } catch { self.error = error.localizedDescription }
            sending = false
        }
    }
}

import SwiftUI

/// Remember this: one line (typed or dictated with the keyboard microphone) becomes a task, reminder, journal entry or memory.
struct CaptureSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var outcome: CaptureOutcome?
    @State private var saving = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.l) {
                if let outcome {
                    result(outcome)
                } else {
                    TextField("What do you want to remember or do?", text: $text, axis: .vertical)
                        .font(.mission(.title3)).lineLimit(3...8).focused($focused)
                        .padding(Space.l).background(Tok.surface, in: MissionTheme.cardShape)
                        .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
                    Text("Try \u{201C}remind me to call Sam tomorrow\u{201D}, \u{201C}decided to walk after lunch because I focus better\u{201D}, or \u{201C}today I felt calm\u{201D}. Tap the keyboard's microphone to speak.")
                        .font(.mission(.footnote)).foregroundStyle(Tok.muted)
                    if let error = life.error { Text(error).font(.mission(.callout)).foregroundStyle(Tok.critical) }
                    Spacer()
                    Button {
                        saving = true
                        Task { outcome = await life.capture(text); saving = false }
                    } label: { if saving { ProgressView().tint(Tok.onAccent) } else { Text("Save") } }
                        .buttonStyle(PrimaryButtonStyle()).disabled(text.trimmed.isEmpty || saving)
                }
            }
            .padding(Space.l).screenBackground()
            .navigationTitle("Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(outcome == nil ? "Cancel" : "Done") { dismiss() } } }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func result(_ o: CaptureOutcome) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Label(o.label, systemImage: o.symbol).font(.mission(.headline, .medium)).foregroundStyle(Tok.accent)
            Text(text.trimmed).font(.mission(.title3))
            Text(hint(o)).font(.mission(.footnote)).foregroundStyle(Tok.muted)
            Spacer()
            Button("Add another") { text = ""; outcome = nil; focused = true }.buttonStyle(SecondaryButtonStyle())
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func hint(_ o: CaptureOutcome) -> String {
        switch o {
        case .task: "It's on today's list. Open Today to change the time or mark it a priority."
        case .reminder(let r): r.due.map { "You'll be reminded \($0.formatted(date: .abbreviated, time: .shortened))." } ?? "Kept with your reminders on Today."
        case .journal: "Find it under Journal."
        case .memory(let m): m.reason.map { "Remembered with the reason: \($0)." } ?? "Search for it any time under Memory."
        }
    }
}


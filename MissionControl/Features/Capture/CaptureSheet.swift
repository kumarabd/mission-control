import SwiftUI

/// Remember this: one line (typed or dictated with the keyboard microphone) becomes a task, reminder, journal entry or memory.
///
/// A reminder is never saved blind. The words are read, then you see the title and the time that were understood and can
/// change either before anything is saved; saving calls the Life Engine, the same operation the agent uses.
struct CaptureSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var outcome: CaptureOutcome?
    @State private var saving = false
    @State private var draft: ReminderDraft?
    @FocusState private var focused: Bool

    /// What was understood from the words, held for review.
    struct ReminderDraft {
        var title: String
        var hasTime: Bool
        var due: Date
        var repeatRule = "none"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.l) {
                if let outcome {
                    result(outcome)
                } else if draft != nil {
                    review
                } else {
                    input
                }
            }
            .padding(Space.l).screenBackground()
            .navigationTitle(draft != nil && outcome == nil ? "Check reminder" : "Capture").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(outcome == nil ? "Cancel" : "Done") { dismiss() } } }
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
            Text("Try \u{201C}remind me to call Sam tomorrow at 5pm\u{201D}, \u{201C}decided to walk after lunch because I focus better\u{201D}, or \u{201C}today I felt calm\u{201D}. Tap the keyboard's microphone to speak.")
                .font(.mission(.footnote)).foregroundStyle(Tok.muted)
            if let error = life.error { Text(error).font(.mission(.callout)).foregroundStyle(Tok.critical) }
            Spacer()
            Button {
                if case .reminder(let r) = Planner.capture(text) {
                    // Review first: nothing is saved until the time and title look right.
                    let fallback = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                    life.error = nil
                    draft = ReminderDraft(title: r.title, hasTime: r.due != nil, due: r.due ?? fallback)
                } else {
                    saving = true
                    Task { outcome = await life.capture(text); saving = false }
                }
            } label: { if saving { ProgressView().tint(Tok.onAccent) } else { Text("Save") } }
                .buttonStyle(PrimaryButtonStyle()).disabled(text.trimmed.isEmpty || saving)
        }
    }

    private var review: some View {
        let binding = Binding(get: { draft ?? ReminderDraft(title: "", hasTime: false, due: Date()) }, set: { draft = $0 })
        return VStack(alignment: .leading, spacing: Space.l) {
            Text("This is what will be saved to your workspace.").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
            Form {
                Section { TextField("Title", text: binding.title) }
                Section {
                    Toggle("Set a time", isOn: binding.hasTime)
                    if binding.wrappedValue.hasTime {
                        DatePicker("When", selection: binding.due, displayedComponents: [.date, .hourAndMinute])
                        Picker("Repeat", selection: binding.repeatRule) {
                            Text("Never").tag("none"); Text("Every day").tag("daily"); Text("Every week").tag("weekly"); Text("Every month").tag("monthly")
                        }
                    }
                } footer: { if !binding.wrappedValue.hasTime { Text("We didn't find a time in what you wrote. Without one it stays on your list until you finish it.") } }
                if let error = life.error { Section { Text(error).foregroundStyle(Tok.critical) } }
            }
            .scrollContentBackground(.hidden)
            Button {
                guard let d = draft else { return }
                saving = true
                Task {
                    let rule: Wire.Recurrence? = d.hasTime && d.repeatRule != "none" ? .init(freq: d.repeatRule, interval: nil, weekdays: nil) : nil
                    if await life.addReminder(title: d.title.trimmed, due: d.hasTime ? d.due : nil, recurrence: rule) {
                        outcome = .reminder(Reminder(title: d.title.trimmed, due: d.hasTime ? d.due : nil))
                    }
                    saving = false
                }
            } label: { if saving { ProgressView().tint(Tok.onAccent) } else { Text("Set reminder") } }
                .buttonStyle(PrimaryButtonStyle()).disabled((draft?.title.trimmed.isEmpty ?? true) || saving)
            Button("Edit what I wrote") { draft = nil }.buttonStyle(SecondaryButtonStyle())
        }
    }

    private func result(_ o: CaptureOutcome) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Label(o.label, systemImage: o.symbol).font(.mission(.headline, .medium)).foregroundStyle(Tok.accent)
            Text(shownTitle(o)).font(.mission(.title3))
            Text(hint(o)).font(.mission(.footnote)).foregroundStyle(Tok.muted)
            Spacer()
            Button("Add another") { text = ""; outcome = nil; draft = nil; focused = true }.buttonStyle(SecondaryButtonStyle())
            Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func shownTitle(_ o: CaptureOutcome) -> String {
        if case .reminder(let r) = o { return r.title }
        return text.trimmed
    }

    private func hint(_ o: CaptureOutcome) -> String {
        switch o {
        case .task: "It's on today's list. Open Today to change the time or mark it a priority."
        case .reminder(let r): r.due.map { "Saved to your workspace. You'll be reminded \($0.formatted(date: .abbreviated, time: .shortened))." } ?? "Saved to your workspace, on your reminders list until you finish it."
        case .journal: "Find it under Journal."
        case .memory(let m): m.reason.map { "Remembered with the reason: \($0)." } ?? "Search for it any time under Memory."
        }
    }
}

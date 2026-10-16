import SwiftUI

struct ReminderRef: Identifiable { let id: String }

/// The reminders' home: what is due, what is coming, what has no time, what is done. A reminder is a cue the person
/// asked for; a behaviour they want to repeat is a routine, which lives in its own segment.
struct RemindersList: View {
    @Environment(Life.self) private var life
    /// Opened by a row, and by a tapped notification that lands on this segment.
    @Binding var detail: ReminderRef?
    let onNew: () -> Void

    var body: some View {
        Group {
            if !life.remindersAvailable {
                EmptyState(symbol: "icloud.slash", title: "Reminders need your workspace", message: "They are kept with your assistant, which isn't reachable right now.")
            } else if !life.workspaceLoaded {
                ProgressView("Loading reminders…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = life.remindersLoadError, life.reminders.isEmpty {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load reminders", message: error, actionTitle: "Try again") { Task { await life.loadReminders() } }
            } else if life.reminders.isEmpty {
                EmptyState(symbol: "bell", title: "Nothing to be reminded of",
                           message: "A one-off cue or an event: call Sam at 5, pay rent on the 1st. Something you want to keep doing is a routine.",
                           actionTitle: "New reminder", action: onNew)
            } else {
                List {
                    ForEach(ReminderSections.sections(life.reminders), id: \.group) { section in
                        Section {
                            ForEach(section.items) { reminder in row(reminder) }
                        } header: {
                            Text(section.group.rawValue).font(.mission(.subheadline, .medium))
                        }
                        .listRowBackground(Tok.surface)
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await life.loadReminders() }
            }
        }
        .task { await life.loadReminders() }
    }

    /// The cue that has fired is cleared from here, where the record now lives; a reminder still to come is left alone.
    private func row(_ r: Wire.Reminder) -> some View {
        let due = life.agenda.first { $0.reminder.id == r.id && $0.state == "due" }
        return HStack(spacing: Space.s) {
            Button { detail = ReminderRef(id: r.id) } label: {
                HStack(spacing: Space.m) {
                    Image(systemName: r.isDone ? "checkmark.circle" : "bell")
                        .foregroundStyle(Tok.accent).frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(r.title).foregroundStyle(r.isDone ? Tok.muted : Tok.text)
                            .strikethrough(r.isDone).multilineTextAlignment(.leading)
                        Text(when(r)).font(.mission(.caption)).foregroundStyle(Tok.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Tok.muted)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(r.title). \(r.isDone ? "Done" : when(r)). Show details")
            if let due {
                Button { Task { await life.ackCue(due) } } label: {
                    Image(systemName: "checkmark.circle").font(.mission(.title2)).frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless).disabled(life.busyReminders.contains(r.id))
                .accessibilityLabel("Got it: \(r.title)")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !r.isDone {
                Button("Snooze 1 hr", systemImage: "moon.zzz") { Task { await life.snoozeReminder(r, until: Date().addingTimeInterval(3600)) } }
                    .tint(MissionTone.reminder.color)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { Task { await life.deleteReminder(r) } }
        }
    }

    private func when(_ r: Wire.Reminder) -> String {
        if r.isDone {
            return (r.completedAt ?? r.lastCompletedAt).map { "Done \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Done"
        }
        if let snoozed = r.snoozedUntil { return "Snoozed until \(snoozed.formatted(date: .abbreviated, time: .shortened))" }
        if let due = r.dueAt { return due.formatted(date: .abbreviated, time: .shortened) }
        return "No time set"
    }
}

/// Everything the engine holds about one reminder, with the same actions as the row. It reads the live list, so a
/// change made here (or by the assistant) shows straight away.
struct ReminderDetailSheet: View {
    let id: String
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss

    private var reminder: Wire.Reminder? { life.reminders.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            Group {
                if let r = reminder { details(r) } else {
                    ContentUnavailableView("This reminder is gone", systemImage: "bell.slash", description: Text("It was finished a while ago or removed."))
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Reminder").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func details(_ r: Wire.Reminder) -> some View {
        let due = life.agenda.first { $0.reminder.id == r.id && $0.state == "due" }
        return List {
            Section {
                Text(r.title).font(.mission(.title3)).strikethrough(r.isDone).foregroundStyle(r.isDone ? Tok.muted : Tok.text)
                if !r.notes.isEmpty { Text(r.notes).font(.mission(.body)).foregroundStyle(Tok.text) }
            }
            Section("When") {
                row("Next", r.dueAt.map { $0.formatted(date: .complete, time: .shortened) } ?? "No time set")
                if let until = r.snoozedUntil { row("Snoozed until", until.formatted(date: .abbreviated, time: .shortened)) }
                if let rule = r.repeatDescription { row("Repeats", rule) }
                if r.dueAt != nil { row("Time zone", r.timeZone) }
            }
            DisclosureGroup("Status and origin") {
                row("State", r.isDone ? "Done" : due != nil ? "Waiting for you" : "Set")
                if let when = r.completedAt ?? r.lastCompletedAt { row(r.isDone ? "Finished" : "Last cleared", when.formatted(date: .abbreviated, time: .shortened)) }

                row("Set by", r.source == "agent" ? "Your assistant" : "You")
                row("Created", r.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            if !r.isDone {
                Section {
                    if r.dueAt == nil { Button("Mark done", systemImage: "checkmark.circle") { Task { await life.completeReminder(r) } }.disabled(life.busyReminders.contains(r.id)) }
                    if let due { Button("Got it", systemImage: "checkmark.circle") { Task { await life.ackCue(due) } }.disabled(life.busyReminders.contains(r.id)) }
                    Button("Snooze for an hour", systemImage: "moon.zzz") { Task { await life.snoozeReminder(r, until: Date().addingTimeInterval(3600)) } }
                    Button("Delete", systemImage: "trash", role: .destructive) { Task { if await life.deleteReminder(r) { dismiss() } } }
                }
            }
        }
        .listRowBackground(Tok.surface)
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) { Text(value).foregroundStyle(Tok.muted).multilineTextAlignment(.trailing) }
    }
}

/// A reminder with a real date and time chosen on screen: no text is interpreted, so what is saved is exactly what was picked.
struct AddReminderSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var hasTime = true
    @State private var due = Calendar.current.date(byAdding: .hour, value: 1, to: Date()).map { Calendar.current.date(bySetting: .minute, value: 0, of: $0) ?? $0 } ?? Date()
    @State private var repeatRule = "none"
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("What should we remind you of?", text: $title) }
                Section {
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("When", selection: $due, displayedComponents: [.date, .hourAndMinute])
                        Picker("Repeat", selection: $repeatRule) {
                            Text("Never").tag("none"); Text("Every day").tag("daily"); Text("Every week").tag("weekly"); Text("Every month").tag("monthly")
                        }
                    }
                } footer: { if !hasTime { Text("Without a time it stays on your list until you finish it.") } }
                Section("Notes (optional)") { TextField("Anything to remember", text: $notes, axis: .vertical) }
                if let error = life.error { Section { Text(error).foregroundStyle(Tok.critical) } }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("New reminder").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saving = true
                        Task {
                            let rule: Wire.Recurrence? = hasTime && repeatRule != "none" ? .init(freq: repeatRule, interval: nil, weekdays: nil) : nil
                            if await life.addReminder(title: title.trimmed, notes: notes.trimmed, due: hasTime ? due : nil, recurrence: rule) { dismiss() }
                            saving = false
                        }
                    }.disabled(title.trimmed.isEmpty || saving)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

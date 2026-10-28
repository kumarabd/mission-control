import SwiftUI

/// A task or event to open: the record, and for one occurrence of a repeating item, which.
struct ItemRef: Identifiable, Hashable {
    let id: String
    var at: Date? = nil
}

/// Adds a task or an event, or edits one. What is picked on screen is what is saved: no text is interpreted.
struct ItemFormSheet: View {
    enum Mode { case new(goalID: String?), edit(Wire.Item) }

    let mode: Mode
    var initialKind = ItemsService.Kind.task
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var kind = ItemsService.Kind.task
    @State private var draft = ItemsService.Draft()
    @State private var hasTime = false
    @State private var at = Self.nextHour()
    @State private var repeatRule = "none"
    @State private var alertChoice = -1          // -1 none; otherwise minutes before
    @State private var hasLength = false
    @State private var minutes = 30
    @State private var saving = false

    private var editing: Wire.Item? { if case .edit(let item) = mode { item } else { nil } }
    private var timed: Bool { kind == .event || hasTime }

    var body: some View {
        NavigationStack {
            Form {
                if editing == nil {
                    Picker("Kind", selection: $kind) { Text("Task").tag(ItemsService.Kind.task); Text("Event").tag(ItemsService.Kind.event) }.pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                }
                Section { TextField(kind == .task ? "What needs doing?" : "What is happening?", text: $draft.title) }
                Section {
                    if kind == .task { Toggle("Set a time", isOn: $hasTime) }
                    if timed {
                        DatePicker(kind == .event ? "Starts" : "When", selection: $at, displayedComponents: [.date, .hourAndMinute])
                        Picker("Repeat", selection: $repeatRule) {
                            Text("Never").tag("none"); Text("Every day").tag("daily"); Text("Every week").tag("weekly"); Text("Every month").tag("monthly")
                        }
                        Picker("Tell me", selection: $alertChoice) {
                            Text("No alert").tag(-1); Text("At the time").tag(0); Text("5 minutes before").tag(5); Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30); Text("1 hour before").tag(60)
                            if repeatRule == "none" { Text("1 day before").tag(1440) }
                        }
                    }
                    Toggle(kind == .event ? "Set a length" : "Takes a set time", isOn: $hasLength)
                    if hasLength { Stepper("\(minutes) minutes", value: $minutes, in: 5...480, step: 5) }
                } footer: {
                    if kind == .task && !hasTime { Text("Without a time it stays on your list until you finish it.") }
                    else if alertChoice >= 0 { Text("You'll get a notification. Allow notifications when asked.") }
                }
                if kind == .task { Section { Toggle("A priority", isOn: $draft.isPriority) } }
                if !life.goals.isEmpty {
                    Section {
                        Picker("Goal", selection: $draft.goalId) {
                            Text("None").tag(String?.none)
                            ForEach(life.goals) { Text($0.title).tag(String?.some($0.id)) }
                        }
                    }
                }
                Section("Notes (optional)") { TextField("Anything to remember", text: $draft.notes, axis: .vertical) }
                if let error = life.error { Section { Text(error).foregroundStyle(Tok.critical) } }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(editing == nil ? "New \(kind == .task ? "task" : "event")" : "Edit").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Add" : "Save") { save() }.disabled(draft.title.trimmed.isEmpty || saving)
                }
            }
            .onAppear(perform: load)
            .onChange(of: repeatRule) { _, rule in if rule != "none" && alertChoice == 1440 { alertChoice = 60 } }
        }
        .presentationDetents([.medium, .large])
    }

    private func load() {
        switch mode {
        case .new(let goalID): draft.goalId = goalID; kind = initialKind
        case .edit(let item):
            kind = item.isEvent ? .event : .task
            draft = ItemsService.Draft(item)
            hasTime = item.at != nil; if let t = item.at { at = t }
            repeatRule = item.recurrence?.freq ?? "none"
            alertChoice = item.alertBeforeMinutes ?? -1
            hasLength = item.minutes != nil; minutes = item.minutes ?? 30
        }
    }

    private func save() {
        saving = true
        var d = draft
        d.title = d.title.trimmed; d.notes = d.notes.trimmed
        d.at = timed ? at : nil
        d.minutes = hasLength ? minutes : nil
        d.recurrence = timed && repeatRule != "none" ? Wire.Recurrence(freq: repeatRule, interval: nil, weekdays: nil) : nil
        d.alertBeforeMinutes = timed && alertChoice >= 0 ? alertChoice : nil
        d.timeZone = TimeZone.current.identifier
        Task {
            let ok: Bool
            if let item = editing { ok = await life.save(item, d) } else { ok = await life.add(kind, d) }
            if ok { dismiss() }
            saving = false
        }
    }

    private static func nextHour() -> Date {
        let hour = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Calendar.current.date(bySetting: .minute, value: 0, of: hour) ?? hour
    }
}

/// One task or event: when it is, whether it repeats or alerts, and what can be done with it.
struct ItemDetailSheet: View {
    let ref: ItemRef
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var editing: Wire.Item?
    private var item: Wire.Item? { life.item(ref.id) }

    var body: some View {
        NavigationStack {
            Group {
                if let item { details(item) } else {
                    ContentUnavailableView("This is gone", systemImage: "checklist", description: Text("It was finished a while ago or removed."))
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(item?.isEvent == true ? "Event" : "Task").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editing) { ItemFormSheet(mode: .edit($0)).environment(life) }
            .confirmationDialog("Delete this?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { guard let item else { return }; Task { if await life.delete(item) { dismiss() } } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func details(_ t: Wire.Item) -> some View {
        List {
            Section {
                Text(t.title).font(.mission(.title3, .medium)).strikethrough(t.isDone).foregroundStyle(t.isDone ? Tok.muted : Tok.text)
                if !t.notes.isEmpty { Text(t.notes).font(.mission(.body)) }
                if let goal = life.goals.first(where: { $0.id == t.goalId }) { Text("For \(goal.title)").foregroundStyle(Tok.muted) }
            }
            Section("When") {
                row(t.isEvent ? "Starts" : "Time", (ref.at ?? t.at).map { $0.formatted(date: .complete, time: .shortened) } ?? "No time set")
                if let m = t.minutes { row("Length", "\(m) minutes") }
                if let rule = t.repeatDescription { row("Repeats", rule) }
                if let alert = t.alertDescription { row("Alert", alert) }
                if let until = t.snoozedUntil, until > Date() { row("Snoozed until", until.formatted(date: .abbreviated, time: .shortened)) }
            }
            Section {
                NavigationLink {
                    KitScreen(subject: ViewSubject(kind: t.kind, id: t.id), title: t.title, notes: t.notes) { EmptyView() }
                } label: { Label("Its view", systemImage: "chart.xyaxis.line") }
            }
            Section {
                if t.isTask {
                    let done = ref.at == nil ? t.isDone : (life.day?.entries.first { $0.item.id == t.id && $0.at == ref.at }?.isDone ?? false)
                    Button(done ? "Mark not done" : "Mark done", systemImage: "checkmark.circle") {
                        Task { await life.complete(t, at: t.repeats ? ref.at : nil, done: !done) }
                    }
                }
                if t.alertBeforeMinutes != nil {
                    Button("Snooze the alert for an hour", systemImage: "moon.zzz") { Task { await life.snooze(t, until: Date().addingTimeInterval(3600)) } }
                }
                Button("Edit", systemImage: "pencil") { editing = t }
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }.disabled(life.busyItems.contains(t.id))
            if let error = life.error { Section { Text(error).foregroundStyle(Tok.critical) } }
        }
        .listRowBackground(Tok.surface)
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) { Text(value).foregroundStyle(Tok.muted).multilineTextAlignment(.trailing) }
    }
}

extension Wire.Item: Hashable { func hash(into hasher: inout Hasher) { hasher.combine(id); hasher.combine(version) } }

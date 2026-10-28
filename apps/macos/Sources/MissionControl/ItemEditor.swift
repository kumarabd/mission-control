import SwiftUI

/// Adds a task or event, or edits one. The same Life Engine records the phone
/// and web write: nothing here invents a local item.
struct ItemEditor: View {
    enum Mode {
        case new(goalID: String?)
        case edit(Wire.Item)
    }

    let mode: Mode
    var initialKind: ItemsService.Kind = .task
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ItemsService.Kind = .task
    @State private var draft = ItemsService.Draft()
    @State private var hasTime = false
    @State private var at = Self.nextHour()
    @State private var repeatRule = "none"
    @State private var alertChoice = -1
    @State private var hasLength = false
    @State private var minutes = 30
    @State private var saving = false

    private var editing: Wire.Item? {
        if case .edit(let item) = mode { return item }
        return nil
    }
    private var timed: Bool { kind == .event || hasTime }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                if editing == nil {
                    Picker("Kind", selection: $kind) {
                        Text("Task").tag(ItemsService.Kind.task)
                        Text("Event").tag(ItemsService.Kind.event)
                    }
                    .pickerStyle(.segmented)
                }
                Section("What") {
                    TextField(kind == .task ? "What needs doing?" : "What is happening?", text: $draft.title)
                }
                Section("When") {
                    if kind == .task { Toggle("Set a time", isOn: $hasTime) }
                    if timed {
                        DatePicker(kind == .event ? "Starts" : "When", selection: $at,
                                   displayedComponents: [.date, .hourAndMinute])
                        Picker("Repeats", selection: $repeatRule) {
                            Text("Never").tag("none")
                            Text("Every day").tag("daily")
                            Text("Every week").tag("weekly")
                            Text("Every month").tag("monthly")
                        }
                        Picker("Alert", selection: $alertChoice) {
                            Text("No alert").tag(-1)
                            Text("At the time").tag(0)
                            Text("5 minutes before").tag(5)
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                            Text("1 hour before").tag(60)
                            if repeatRule == "none" { Text("1 day before").tag(1440) }
                        }
                    }
                    Toggle(kind == .event ? "Set a length" : "Takes a set time", isOn: $hasLength)
                    if hasLength {
                        Stepper("\(minutes) minutes", value: $minutes, in: 5...480, step: 5)
                    }
                }
                if kind == .task {
                    Section("Priority") {
                        Toggle("A priority", isOn: $draft.isPriority)
                    }
                }
                if !life.goals.isEmpty {
                    Section("Goal") {
                        Picker("Goal", selection: $draft.goalId) {
                            Text("None").tag(String?.none)
                            ForEach(life.goals) { goal in
                                Text(goal.title).tag(String?.some(goal.id))
                            }
                        }
                    }
                }
                Section("Notes") {
                    TextField("Anything to remember", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let error = life.error {
                    Section {
                        Text(error).font(.mission(.subheadline)).foregroundStyle(Tok.critical)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Tok.background)
        .frame(width: 540, height: 620)
        .onAppear(perform: load)
        .onChange(of: repeatRule) { _, rule in
            if rule != "none" && alertChoice == 1440 { alertChoice = 60 }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(editing == nil ? "New \(kind == .task ? "task" : "event")" : "Edit \(kind == .task ? "task" : "event")")
                    .font(.mission(.title3, .semibold))
                Text(editing == nil
                     ? "Saved to your workspace, so the assistant sees it too."
                     : "Changes replace the record the other clients read.")
                    .font(.mission(.caption))
                    .foregroundStyle(Tok.muted)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(saving ? "Saving…" : editing == nil ? "Add" : "Save") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.title.trimmed.isEmpty || saving)
        }
        .padding(Space.l)
    }

    private func load() {
        switch mode {
        case .new(let goalID):
            draft.goalId = goalID
            kind = initialKind
            hasTime = initialKind == .task ? false : true
        case .edit(let item):
            kind = item.isEvent ? .event : .task
            draft = ItemsService.Draft(item)
            hasTime = item.at != nil
            if let time = item.at { at = time }
            repeatRule = item.recurrence?.freq ?? "none"
            alertChoice = item.alertBeforeMinutes ?? -1
            hasLength = item.minutes != nil
            minutes = item.minutes ?? 30
        }
    }

    private func save() {
        saving = true
        var value = draft
        value.title = value.title.trimmed
        value.notes = value.notes.trimmed
        value.at = timed ? at : nil
        value.minutes = hasLength ? minutes : nil
        value.recurrence = timed && repeatRule != "none"
            ? Wire.Recurrence(freq: repeatRule, interval: nil, weekdays: nil) : nil
        value.alertBeforeMinutes = timed && alertChoice >= 0 ? alertChoice : nil
        value.timeZone = TimeZone.current.identifier
        Task {
            let ok: Bool
            if let item = editing { ok = await life.save(item, value) }
            else { ok = await life.add(kind, value) }
            saving = false
            if ok { dismiss() }
        }
    }

    private static func nextHour() -> Date {
        let hour = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Calendar.current.date(bySetting: .minute, value: 0, of: hour) ?? hour
    }
}

extension ItemsService.Kind: Identifiable {
    var id: String { rawValue }
}

import SwiftUI
import EventKit

struct TodayView: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @State private var events: [DayEvent] = []
    @State private var sheet: Sheet?
    @State private var detail: ReminderRef?
    @State private var openRoutine: RoutineRef?
    @State private var openGoal: GoalRef?
    @State private var openTask: PlanItemRef?
    @State private var loading = true

    enum Sheet: Identifiable { case add, reminder, reminders; var id: Self { self } }

    private var flexibleTasks: [Wire.PlanItem] { TodayLayout.untimedTasks(life.tasks) }
    private var flexibleRoutines: [Wire.RoutineStatus] { TodayLayout.untimedRoutines(life.routines) }
    private var flexibleReminders: [Wire.Reminder] { TodayLayout.untimedReminders(life.reminders) }

    private var dueCards: [TaskCard] {
        let open = flexibleTasks.filter { $0.doneAt == nil }
        var cards = (open.filter(\.isPriority) + open.filter { !$0.isPriority }).map(TaskCard.task)
        if let s = life.nextSuggestion, s.source == "goal_step", !life.tasks.contains(where: { $0.stepId == s.stepId }) { cards.append(.step(s)) }
        cards += flexibleRoutines.filter { !$0.done }.map(TaskCard.routine)
        cards += flexibleReminders.filter { !$0.isDone }.map(TaskCard.reminder)
        return cards
    }

    private var doneItems: Int {
        flexibleTasks.filter { $0.doneAt != nil }.count + flexibleRoutines.filter(\.done).count + flexibleReminders.filter(\.isDone).count
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                List {
                    Section {
                        Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    }.listRowBackground(Color.clear)
                    if loading {
                        Section { Label("Loading your day…", systemImage: "clock").foregroundStyle(Tok.muted) }
                    } else {
                        if !life.planAvailable && !life.remindersAvailable && !life.routinesAvailable {
                            Section { Text("Connect your workspace to see today's tasks and reminders.").foregroundStyle(Tok.muted) }
                        }
                        if let error = life.planLoadError ?? life.remindersLoadError ?? life.routinesLoadError {
                            Section {
                                Label("Some items couldn't load", systemImage: "wifi.exclamationmark").font(.mission(.headline))
                                Text(error).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                                Button("Try again") { Task { await refresh() } }.frame(minHeight: 44)
                            }.listRowBackground(Tok.surface)
                        }
                        ScheduleSection(events: events, openReminder: { detail = ReminderRef(id: $0) },
                                        openTask: { openTask = PlanItemRef(id: $0) })
                        tasksSection
                        Section {
                            if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                                Button("Include my calendar", systemImage: "calendar.badge.plus") {
                                    Task { events = await DayEvents.today(requestAccess: true) }
                                }.frame(minHeight: 44)
                            }
                            Button("All reminders", systemImage: "bell") { sheet = .reminders }.frame(minHeight: 44)
                        }.listRowBackground(Tok.surface)
                    }
                }
                .safeAreaPadding(.bottom, 80)
                .scrollContentBackground(.hidden).screenBackground()
                .refreshable { await refresh() }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add a task", systemImage: "checklist") { sheet = .add }
                        Button("Add a reminder", systemImage: "bell") { sheet = .reminder }
                    } label: { Label("Add", systemImage: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Add a task or reminder")
                }
            }
            .sheet(item: $sheet) { s in
                switch s {
                case .add: AddPlanItemSheet()
                case .reminder: AddReminderSheet()
                case .reminders: AllRemindersSheet()
                }
            }
            .sheet(item: $detail) { ReminderDetailSheet(id: $0.id) }
            .sheet(item: $openTask) { PlanItemDetailSheet(id: $0.id) }
            .navigationDestination(item: $openRoutine) { RoutineDetailView(id: $0.id) }
            .navigationDestination(item: $openGoal) { GoalDetail(goalID: $0.id) }
            .onAppear { openLink(DeepLink.shared.pending) }
            .onChange(of: DeepLink.shared.pending) { _, target in openLink(target) }
            .task { await refresh(); loading = false }
            .alert("Couldn't update your day", isPresented: Binding(get: { life.error != nil }, set: { if !$0 { life.error = nil } })) {
                Button("OK") { life.error = nil }
            } message: { Text(life.error ?? "") }
        }
    }

    private func refresh() async {
        await life.refreshWorkspace()
        events = await DayEvents.today()
    }

    private func openLink(_ target: PushLink.Target?) {
        guard let target else { return }
        switch target.entity {
        case "reminder": detail = ReminderRef(id: target.id)
        case "routine": openRoutine = RoutineRef(id: target.id)
        case "plan_item": openTask = PlanItemRef(id: target.id)
        default: return
        }
        DeepLink.shared.pending = nil
    }

    private var tasksSection: some View {
        Section {
            TaskDeck(cards: dueCards, doneToday: doneItems) { card in
                switch card {
                case .routine(let s): openRoutine = RoutineRef(id: s.id)
                case .reminder(let r): detail = ReminderRef(id: r.id)
                case .task(let t): openTask = PlanItemRef(id: t.id)
                case .step(let s): if let id = s.goalId { openGoal = GoalRef(id: id) }
                }
            }
        } header: {
            Text("Tasks").font(.mission(.subheadline, .medium))
        } footer: { Text("Things to do without a set time.").font(.mission(.footnote)) }
        .listRowBackground(Tok.surface)
    }
}

struct AddPlanItemSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var minutes = 25
    @State private var priority = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("What will you do?", text: $title) }
                Section {
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...240, step: 5)
                    Toggle("One of today's priorities", isOn: $priority)
                }
                if let error = life.error { Section { Text(error).foregroundStyle(Tok.critical) } }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Add to today").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saving = true
                        Task {
                            if await life.addTask(title: title.trimmed, minutes: minutes, priority: priority) { dismiss() }
                            saving = false
                        }
                    }.disabled(title.trimmed.isEmpty || saving)
                }
            }
        }
        .presentationDetents([.medium, .large])
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


struct ReminderRef: Identifiable { let id: String }

/// Everything the engine holds about one reminder, with the same actions as the row. It reads the live list, so a change made
/// here (or by the assistant) shows straight away.
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

import SwiftUI

struct TodayView: View {
    @Environment(Life.self) private var life
    @State private var events: [DayEvent] = []
    @State private var sheet: Sheet?
    @State private var detail: ReminderRef?
    @State private var openRoutine: RoutineRef?

    enum Sheet: Identifiable { case add, reminder, replan, close, time
        var id: Self { self }
    }

    private var tasksToday: [Wire.PlanItem] { life.tasks.filter { $0.kind != "event" } }
    private var todayRoutines: [Wire.RoutineStatus] { life.routines.filter(\.scheduled) }

    /// The tasks still to do, as cards: today's priorities, then its other tasks without a time, the next milestone of a goal, and the
    /// routines due (the one with the nearest nudge first). Anything with a start time lives in the Schedule instead.
    private var dueCards: [TaskCard] {
        let open = tasksToday.filter { $0.startAt == nil && $0.doneAt == nil }
        var cards = (open.filter(\.isPriority) + open.filter { !$0.isPriority }).map(TaskCard.task)
        if let s = life.nextSuggestion, s.source == "goal_step" { cards.append(.step(s)) }
        let due = todayRoutines.filter { !$0.done }.sorted {
            let a = RoutineSchedule.nextCue(cues: $0.routine.cues, zone: $0.routine.timeZone), b = RoutineSchedule.nextCue(cues: $1.routine.cues, zone: $1.routine.timeZone)
            switch (a, b) { case let (x?, y?): return x < y; case (_?, nil): return true; case (nil, _?): return false; default: return $0.routine.title < $1.routine.title }
        }
        return cards + due.map(TaskCard.routine)
    }
    /// Cards finished today: tasks without a time and routines.
    private var doneItems: Int { tasksToday.filter { $0.startAt == nil && $0.doneAt != nil }.count + todayRoutines.filter(\.done).count }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if dayTotal > 0 { ringSection(proxy) }
                    tasksSection
                    ScheduleSection(events: events) { detail = ReminderRef(id: $0) }
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).day().month()))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add to today", systemImage: "checklist") { sheet = .add }
                        Button("Add a reminder", systemImage: "bell") { sheet = .reminder }
                        Button("I have a few minutes", systemImage: "clock") { sheet = .time }
                        Button("My day changed", systemImage: "arrow.triangle.2.circlepath") { sheet = .replan }
                        Button("Close the day", systemImage: "moon.stars") { sheet = .close }
                    } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Day actions")
                }
            }
            .sheet(item: $sheet) { s in
                switch s {
                case .add: AddPlanItemSheet()
                case .reminder: AddReminderSheet()
                case .replan: ReplanSheet()
                case .close: CloseDaySheet()
                case .time: TimeSheet()
                }
            }
            .sheet(item: $detail) { ReminderDetailSheet(id: $0.id) }
            .navigationDestination(item: $openRoutine) { RoutineDetailView(id: $0.id) }
            .onAppear { openLink(DeepLink.shared.pending) }
            .onChange(of: DeepLink.shared.pending) { _, target in openLink(target) }
            .task { events = await DayEvents.today(); await life.loadPlan() }
            .alert("Something went wrong", isPresented: Binding(get: { life.error != nil }, set: { if !$0 { life.error = nil } })) {
                Button("OK") { life.error = nil }
            } message: { Text(life.error ?? "") }
        }
    }

    /// A tapped notification for a reminder or a routine opens that record here.
    private func openLink(_ target: PushLink.Target?) {
        guard let target else { return }
        switch target.entity {
        case "reminder": detail = ReminderRef(id: target.id)
        case "routine": openRoutine = RoutineRef(id: target.id)
        default: return
        }
        DeepLink.shared.pending = nil
    }

    // MARK: Tasks. What to do today, one card at a time.

    private var tasksSection: some View {
        Section {
            TaskDeck(cards: dueCards, doneToday: doneItems) { card in
                if case .routine(let s) = card { openRoutine = RoutineRef(id: s.id) }
            }
        } header: {
            HStack {
                Text("Tasks")
                Spacer()
                Text("\(doneItems) of \(doneItems + dueCards.count)").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
            .font(.mission(.subheadline, .medium)).id(DayKind.tasks)
        }
    }


    /// Tasks without a time come first; then everything with a time in the order it happens: calendar events, timed tasks, and the reminders
    /// as they are due to fire.
    // MARK: Your day. One ring for the whole day, a segment for each kind of thing in it.

    private var daySegments: [DaySegment] {
        let tasks = tasksToday
        return DayProgress.segments(routines: life.routines, tasksDone: tasks.filter { $0.doneAt != nil }.count, tasksTotal: tasks.count, cues: life.agenda)
    }
    private var dayTotal: Int { daySegments.reduce(0) { $0 + $1.total } }

    private func ringSection(_ proxy: ScrollViewProxy) -> some View {
        let segments = daySegments
        return Section {
            HStack(spacing: Space.l) {
                DayRing(segments: segments)
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(segments) { seg in
                        Button { withAnimation { proxy.scrollTo(seg.kind, anchor: .top) } } label: {
                            HStack(spacing: Space.s) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(seg.kind.color).frame(width: 12, height: 12).accessibilityHidden(true)
                                Text(seg.kind.rawValue).font(.mission(.subheadline)).foregroundStyle(Tok.text)
                                Spacer(minLength: Space.s)
                                Text("\(seg.done)/\(seg.total)").font(.missionMono(.subheadline, .medium)).foregroundStyle(Tok.muted)
                            }.frame(minHeight: 32).contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(seg.kind.rawValue): \(seg.done) of \(seg.total). Jump to it")
                    }
                }
            }
            .padding(.vertical, Space.xs)
        } header: { Text("Your day").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }
}

struct AddPlanItemSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var minutes = 25
    @State private var priority = false

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("What will you do?", text: $title) }
                Section {
                    Stepper("\(minutes) minutes", value: $minutes, in: 5...240, step: 5)
                    Toggle("One of today's priorities", isOn: $priority)
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Add to today").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { if await life.addTask(title: title.trimmed, minutes: minutes, priority: priority) { dismiss() } }
                    }.disabled(title.trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// My day changed: say how much time is left; unfinished work that no longer fits moves to tomorrow, after you look.
struct ReplanSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var minutesLeft: Int?
    @State private var change: Wire.Replan?

    var body: some View {
        NavigationStack {
            List {
                Section("How much time do you have left today?") {
                    HStack(spacing: Space.s) {
                        ForEach([(30, "30 min"), (60, "1 hr"), (120, "2 hrs"), (240, "4 hrs")], id: \.0) { m, label in
                            Chip(title: label, selected: minutesLeft == m) { minutesLeft = m }
                        }
                    }.listRowBackground(Color.clear)
                }
                if minutesLeft != nil, let change {
                    Section("Keep today") { list(change.keep.filter { $0.doneAt == nil }, empty: "Nothing else fits. That's fine.") }
                        .listRowBackground(Tok.surface)
                    Section("Move to tomorrow") { list(change.moveToTomorrow, empty: "Nothing needs to move.") }
                        .listRowBackground(Tok.surface)
                    Section {
                        Button("Apply this plan") { Task { await life.applyReplan(change); dismiss() } }
                            .buttonStyle(PrimaryButtonStyle()).listRowBackground(Color.clear).listRowInsets(.init())
                    }
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("My day changed").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: minutesLeft) {
                guard let minutesLeft else { change = nil; return }
                change = await life.replanPreview(minutesLeft: minutesLeft)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder private func list(_ items: [Wire.PlanItem], empty: String) -> some View {
        if items.isEmpty { Text(empty).font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
        ForEach(items) { i in
            HStack { Text(i.title).font(.mission(.body)); Spacer(); Text("\(i.minutes) min").font(.missionMono(.caption)).foregroundStyle(Tok.muted) }
                .frame(minHeight: 44)
        }
    }
}

/// Close the day: acknowledge progress, take one line of reflection, carry the unfinished forward.
struct CloseDaySheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var reflection = ""
    @State private var result: Wire.DayCloseResult?

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    VStack(alignment: .leading, spacing: Space.l) {
                        Label("Day closed", systemImage: "moon.stars").font(.mission(.headline, .medium)).foregroundStyle(Tok.accent)
                        Text(result.summary).font(.mission(.title3))
                        Text(result.tomorrowNote).font(.mission(.body)).foregroundStyle(Tok.muted)
                        if !result.carried.isEmpty { Text("Moved to tomorrow: " + result.carried.map(\.title).joined(separator: ", ")).font(.mission(.footnote)).foregroundStyle(Tok.muted) }
                        Spacer()
                        Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    }
                } else {
                    VStack(alignment: .leading, spacing: Space.l) {
                        let items = life.tasks.filter { $0.kind != "event" }
                        Text("\(items.filter { $0.doneAt != nil }.count) of \(items.count) done today").font(.mission(.title3, .medium))
                        Text("Anything unfinished moves to tomorrow. How was the day?").font(.mission(.body)).foregroundStyle(Tok.muted)
                        TextField("One line is enough (optional)", text: $reflection, axis: .vertical)
                            .font(.mission(.body)).lineLimit(2...6)
                            .padding(Space.l).background(Tok.surface, in: MissionTheme.cardShape)
                            .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
                        Spacer()
                        Button("Close the day") { Task { result = await life.closeDay(reflection: reflection) } }.buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding(Space.l).screenBackground()
            .navigationTitle("Close the day").navigationBarTitleDisplayMode(.inline)
            .toolbar { if result == nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
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
            Section("Status") {
                row("State", r.isDone ? "Done" : due != nil ? "Waiting for you" : "Set")
                if let when = r.completedAt ?? r.lastCompletedAt { row(r.isDone ? "Finished" : "Last cleared", when.formatted(date: .abbreviated, time: .shortened)) }
            }
            Section("Origin") {
                row("Set by", r.source == "agent" ? "Your assistant" : "You")
                row("Created", r.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            if !r.isDone {
                Section {
                    if let due { Button("Got it", systemImage: "checkmark.circle") { Task { await life.ackCue(due) } }.disabled(life.busyReminders.contains(r.id)) }
                    Button("Snooze for an hour", systemImage: "moon.zzz") { Task { await life.snoozeReminder(r, until: Date().addingTimeInterval(3600)) } }
                    Button("Delete", systemImage: "trash", role: .destructive) { Task { await life.deleteReminder(r); dismiss() } }
                }
            }
        }
        .listRowBackground(Tok.surface)
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) { Text(value).foregroundStyle(Tok.muted).multilineTextAlignment(.trailing) }
    }
}

// MARK: - The day ring

extension DayKind {
    /// Each kind has its own colour; the legend and the ring use the same one.
    var color: Color {
        switch self {
        case .tasks: MissionTone.focus.color
        case .cues: MissionTone.reminder.color
        }
    }
}

/// One ring for the whole day. A segment's length is how many things of that kind the day holds; the part filled in is how many are
/// done. The number in the middle and the legend beside it say the same thing, so colour is never the only signal.
struct DayRing: View {
    let segments: [DaySegment]
    var size: CGFloat = 112
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Int { segments.reduce(0) { $0 + $1.total } }
    private var done: Int { segments.reduce(0) { $0 + $1.done } }

    /// Start and end of each segment as a fraction of the circle, with a small gap between neighbours.
    private var layout: [(seg: DaySegment, start: Double, end: Double)] {
        guard total > 0 else { return [] }
        let gap = segments.count > 1 ? 0.012 : 0
        var cursor = 0.0
        return segments.map { seg in
            let share = Double(seg.total) / Double(total)
            defer { cursor += share }
            return (seg, cursor + gap / 2, cursor + share - gap / 2)
        }
    }

    var body: some View {
        ZStack {
            ForEach(layout, id: \.seg.id) { item in
                let fraction = item.seg.total > 0 ? Double(item.seg.done) / Double(item.seg.total) : 0
                Circle().trim(from: item.start, to: item.end)
                    .stroke(item.seg.kind.color.opacity(0.22), style: StrokeStyle(lineWidth: size * 0.12, lineCap: .butt))
                Circle().trim(from: item.start, to: item.start + (item.end - item.start) * fraction)
                    .stroke(item.seg.kind.color, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .butt))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: item.seg.done)
            }
            .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(done)").font(.mission(.title, .semibold)).foregroundStyle(Tok.text)
                Text("of \(total)").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your day: \(done) of \(total) done. " + segments.map { "\($0.kind.rawValue) \($0.done) of \($0.total)" }.joined(separator: ", "))
    }
}

/// "I have 10 minutes": the one thing worth doing in the time you have, from the engine.
struct TimeSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int?
    @State private var chosen: Wire.Suggestion?
    @State private var choosing = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("How long do you have?").font(.mission(.title3, .medium))
                HStack(spacing: Space.s) {
                    ForEach([10, 20, 45], id: \.self) { m in Chip(title: "\(m) min", selected: minutes == m) { minutes = m } }
                }
                if choosing { ProgressView() }
                else if let s = chosen {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(s.title).font(.mission(.headline, .medium))
                        Text("\(s.minutes) min · \(s.reason)").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                        Button("Mark done") { Task { await life.completeSuggestion(s); dismiss() } }
                            .buttonStyle(SecondaryButtonStyle()).padding(.top, Space.xs)
                    }
                } else if let minutes {
                    Text("Nothing planned fits \(minutes) minutes. Take the break, or capture something small.")
                        .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                }
                Spacer()
            }
            .padding(Space.l).frame(maxWidth: .infinity, alignment: .leading)
            .screenBackground()
            .navigationTitle("A few minutes").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task(id: minutes) {
                guard let minutes else { return }
                choosing = true; chosen = await life.suggestion(minutes: minutes); choosing = false
            }
        }
        .presentationDetents([.medium])
    }
}

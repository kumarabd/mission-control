import SwiftUI

struct TodayView: View {
    @Environment(Life.self) private var life
    @State private var events: [DayEvent] = []
    @State private var minutes: Int?
    @State private var sheet: Sheet?
    @State private var detail: ReminderRef?

    enum Sheet: Identifiable { case add, reminder, replan, close
        var id: Self { self }
    }

    private var openItems: [PlanItem] { life.todayItems.filter { !$0.isDone && $0.kind != .event } }
    private var next: PlanItem? { openItems.first(where: \.isPriority) ?? openItems.first }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if dayTotal > 0 { ringSection(proxy) }
                    nextSection
                    timeSection
                    if !todayRoutines.isEmpty { routinesSection }
                    daySection
                    if !comingUp.isEmpty { comingUpSection }
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).day().month()))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add to today", systemImage: "checklist") { sheet = .add }
                        Button("Add a reminder", systemImage: "bell") { sheet = .reminder }
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
                }
            }
            .sheet(item: $detail) { ReminderDetailSheet(id: $0.id) }
            .task { events = await DayEvents.today() }
            .alert("Something went wrong", isPresented: Binding(get: { life.error != nil }, set: { if !$0 { life.error = nil } })) {
                Button("OK") { life.error = nil }
            } message: { Text(life.error ?? "") }
        }
    }

    // MARK: Sections

    private var nextSection: some View {
        Section {
            if let next {
                VStack(alignment: .leading, spacing: Space.s) {
                    Label("Do this next", systemImage: "scope").font(.missionMono(.caption, .medium)).foregroundStyle(Tok.accent)
                    Text(next.title).font(.mission(.title2, .medium))
                    Text("\(next.minutes) min").font(.missionMono(.subheadline)).foregroundStyle(Tok.muted)
                    Button("Mark done") { Task { await life.setPlanItem(next.id, done: true) } }
                        .buttonStyle(PrimaryButtonStyle()).padding(.top, Space.xs)
                }
                .padding(.vertical, Space.xs)
                .accessibilityElement(children: .contain)
            } else {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(life.todayItems.isEmpty ? "Nothing planned yet" : "Everything on today's list is done").font(.mission(.title3, .medium))
                    Text("Add one thing that would make today a good day.").font(.mission(.body)).foregroundStyle(Tok.muted)
                    Button("Add to today") { sheet = .add }.buttonStyle(SecondaryButtonStyle())
                }
                .padding(.vertical, Space.xs)
            }
        }
        .listRowBackground(Tok.surface)
    }

    private var timeSection: some View {
        Section {
            HStack(spacing: Space.s) {
                ForEach([10, 20, 45], id: \.self) { m in
                    Chip(title: "\(m) min", selected: minutes == m) { minutes = minutes == m ? nil : m }
                }
            }
            if let minutes {
                if let s = life.suggestion(minutes: minutes) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(s.title).font(.mission(.headline, .medium))
                        Text("\(s.minutes) min · \(s.reason)").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                        if let id = s.planItemID {
                            Button("Mark done") { Task { await life.setPlanItem(id, done: true); self.minutes = nil } }
                                .buttonStyle(SecondaryButtonStyle()).padding(.top, Space.xs)
                        } else if let g = s.goalID, let st = s.stepID {
                            Button("Mark step done") { Task { await life.setStep(goal: g, step: st, done: true); self.minutes = nil } }
                                .buttonStyle(SecondaryButtonStyle()).padding(.top, Space.xs)
                        }
                    }
                } else {
                    Text("Nothing planned fits \(minutes) minutes. Take the break, or capture something small.")
                        .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                }
            }
        } header: { Text("I have\u{2026}").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }

    private var daySection: some View {
        Section {
            let rows = timeline
            if rows.isEmpty {
                Text("Your day is open.").font(.mission(.body)).foregroundStyle(Tok.muted)
            }
            ForEach(rows) { row in
                switch row {
                case .event(let e): eventRow(e)
                case .item(let i): PlanRow(item: i)
                }
            }
        } header: { Text("Tasks").font(.mission(.subheadline, .medium)).id(DayKind.tasks) }
        .listRowBackground(Tok.surface)
    }

    private var todayRoutines: [Wire.RoutineStatus] { life.routines.filter(\.scheduled) }

    private var routinesSection: some View {
        Section {
            ForEach(todayRoutines) { s in
                HStack(spacing: Space.m) {
                    LogRing(status: s, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.routine.title).font(.mission(.body)).foregroundStyle(s.done ? Tok.muted : Tok.text)
                        Text(s.done ? "Done today" : s.hint).font(.mission(.caption)).foregroundStyle(s.gap && !s.done ? Tok.warn : Tok.muted).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 48)
            }
        } header: { Text("Routines").font(.mission(.subheadline, .medium)).id(DayKind.routines) }
        .listRowBackground(Tok.surface)
    }

    // MARK: Coming up. Reminders are cues: you are told, and you can clear one that has fired. Nothing here is ticked off.

    private struct Cue: Identifiable {
        let id: String
        let reminder: Wire.Reminder
        let at: Date
        let item: Wire.AgendaItem?   // nil for a cue on a later day
        var due: Bool { item?.state == "due" }
    }

    /// Today's cues that are still to come or fired and not cleared, then the next few on later days.
    private var comingUp: [Cue] {
        let today = life.agenda.filter { $0.state != "acknowledged" }.map { Cue(id: $0.id, reminder: $0.reminder, at: $0.at, item: $0) }
        let onToday = Set(life.agenda.map(\.reminder.id))
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
        let later = life.reminders.compactMap { r -> Cue? in
            guard !r.isDone, !onToday.contains(r.id), let at = r.snoozedUntil ?? r.dueAt, at >= tomorrow else { return nil }
            return Cue(id: r.id + "@later", reminder: r, at: at, item: nil)
        }.sorted { $0.at < $1.at }.prefix(4)
        return today + Array(later)
    }

    private var comingUpSection: some View {
        Section {
            ForEach(comingUp) { cue in
                HStack(spacing: Space.s) {
                    Button { detail = ReminderRef(id: cue.reminder.id) } label: {
                        HStack(spacing: Space.m) {
                            Text(Self.cueTime(cue.at)).font(.missionMono(.caption, .medium)).foregroundStyle(cue.due ? Tok.warn : Tok.muted).frame(width: 64, alignment: .leading)
                            Text(cue.reminder.title).font(.mission(.body)).foregroundStyle(Tok.text).multilineTextAlignment(.leading)
                            if cue.reminder.recurrence != nil { Image(systemName: "repeat").font(.caption).foregroundStyle(Tok.muted).accessibilityLabel("repeats") }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("\(cue.reminder.title), \(Self.cueTime(cue.at)). Show details")
                    if cue.due, let item = cue.item {
                        Button("Got it") { Task { await life.ackCue(item) } }
                            .font(.mission(.subheadline, .medium)).buttonStyle(.bordered).tint(Tok.accent)
                            .disabled(life.busyReminders.contains(cue.reminder.id))
                            .accessibilityLabel("Got it: \(cue.reminder.title)")
                    }
                }
                .swipeActions(edge: .trailing) { Button("Delete", role: .destructive) { Task { await life.deleteReminder(cue.reminder) } } }
                .swipeActions(edge: .leading) {
                    Button("Snooze 1 hr", systemImage: "moon.zzz") { Task { await life.snoozeReminder(cue.reminder, until: Date().addingTimeInterval(3600)) } }.tint(MissionTone.reminder.color)
                }
            }
        } header: { Text("Coming up").font(.mission(.subheadline, .medium)).id(DayKind.cues) }
        .listRowBackground(Tok.surface)
    }

    /// "5:00 PM" for today; "Thu 9:00 AM" for another day.
    static func cueTime(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    // MARK: Your day. One ring for the whole day, a segment for each kind of thing in it.

    private var daySegments: [DaySegment] {
        let tasks = life.todayItems.filter { $0.kind != .event }
        return DayProgress.segments(routines: life.routines, tasksDone: tasks.filter(\.isDone).count, tasksTotal: tasks.count, cues: life.agenda)
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

    private func eventRow(_ e: DayEvent) -> some View {
        HStack(spacing: Space.m) {
            MissionIconBadge(symbol: MissionTone.scheduled.symbol, color: MissionTone.scheduled.color, padding: 8)
            VStack(alignment: .leading) {
                Text(e.title).font(.mission(.body))
                Text("\(e.start.formatted(date: .omitted, time: .shortened)) · \(e.minutes) min").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private enum Row: Identifiable {
        case event(DayEvent), item(PlanItem)
        var id: String { switch self { case .event(let e): e.id; case .item(let i): i.id.uuidString } }
        var start: Date? { switch self { case .event(let e): e.start; case .item(let i): i.start } }
    }

    private var timeline: [Row] {
        let rows = events.map(Row.event) + life.todayItems.map(Row.item)
        return rows.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }
}

struct PlanRow: View {
    @Environment(Life.self) private var life
    let item: PlanItem

    var body: some View {
        HStack(spacing: Space.m) {
            Button { Task { await life.setPlanItem(item.id, done: !item.isDone) } } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.mission(.title2)).foregroundStyle(item.isDone ? Tok.accent : Tok.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark \(item.title) not done" : "Mark \(item.title) done")
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.mission(.body)).strikethrough(item.isDone).foregroundStyle(item.isDone ? Tok.muted : Tok.text)
                HStack(spacing: Space.s) {
                    if item.isPriority { Label("Priority", systemImage: "star.fill").foregroundStyle(MissionTone.attention.color) }
                    Text("\(item.minutes) min")
                }
                .font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { Task { await life.deletePlanItem(item.id) } }
        }
        .swipeActions(edge: .leading) {
            Button(item.isPriority ? "Unstar" : "Priority", systemImage: "star") { Task { await life.setPriority(item.id, !item.isPriority) } }.tint(MissionTone.attention.color)
        }
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
                        Task { await life.addPlanItem(PlanItem(title: title.trimmed, minutes: minutes, day: life.today, isPriority: priority)); dismiss() }
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
                if let minutesLeft {
                    let change = life.replan(minutesLeft: minutesLeft)
                    Section("Keep today") { list(change.keep.filter { !$0.isDone }, empty: "Nothing else fits. That's fine.") }
                    Section("Move to tomorrow") { list(change.moveToTomorrow, empty: "Nothing needs to move.") }
                        .listRowBackground(Tok.surface)
                    Section {
                        Button("Apply this plan") { Task { await life.apply(change); dismiss() } }
                            .buttonStyle(PrimaryButtonStyle()).listRowBackground(Color.clear).listRowInsets(.init())
                    }
                }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("My day changed").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder private func list(_ items: [PlanItem], empty: String) -> some View {
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
    @State private var result: DayClose?

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
                        let items = life.todayItems
                        Text("\(items.filter(\.isDone).count) of \(items.filter { $0.kind != .event }.count) done today").font(.mission(.title3, .medium))
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
        case .routines: MissionTone.focus.color
        case .tasks: MissionTone.scheduled.color
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

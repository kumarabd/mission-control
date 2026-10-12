import SwiftUI

struct TodayView: View {
    @Environment(Life.self) private var life
    @State private var events: [DayEvent] = []
    @State private var minutes: Int?
    @State private var sheet: Sheet?

    enum Sheet: Identifiable { case add, replan, close
        var id: Self { self }
    }

    private var openItems: [PlanItem] { life.todayItems.filter { !$0.isDone && $0.kind != .event } }
    private var next: PlanItem? { openItems.first(where: \.isPriority) ?? openItems.first }

    var body: some View {
        NavigationStack {
            List {
                nextSection
                timeSection
                daySection
                if !life.openReminders.isEmpty { remindersSection }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).day().month()))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add to today", systemImage: "plus") { sheet = .add }
                        Button("My day changed", systemImage: "arrow.triangle.2.circlepath") { sheet = .replan }
                        Button("Close the day", systemImage: "moon.stars") { sheet = .close }
                    } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Day actions")
                }
            }
            .sheet(item: $sheet) { s in
                switch s {
                case .add: AddPlanItemSheet()
                case .replan: ReplanSheet()
                case .close: CloseDaySheet()
                }
            }
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
        } header: { Text("Today").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface)
    }

    private var remindersSection: some View {
        Section {
            ForEach(life.openReminders) { r in
                Button { Task { await life.setReminder(r.id, done: true) } } label: {
                    HStack(spacing: Space.m) {
                        Image(systemName: "circle").foregroundStyle(MissionTone.reminder.color)
                        VStack(alignment: .leading) {
                            Text(r.title).font(.mission(.body)).foregroundStyle(Tok.text)
                            if let due = r.due { Text(due.formatted(date: .abbreviated, time: .shortened)).font(.missionMono(.caption)).foregroundStyle(Tok.muted) }
                        }
                    }.frame(minHeight: 44)
                }
                .accessibilityLabel("\(r.title). Mark done")
            }
        } header: { Text("Reminders").font(.mission(.subheadline, .medium)) }
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

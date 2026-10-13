import SwiftUI

/// Everything tied to a time, on one rail: calendar events, reminders as they are due to fire, and tasks with a start time. The time is
/// on the left, a node for each entry sits on the line, and a marker shows where the day is now. Calendar events and reminders have the
/// same shape; only the icon differs.
struct ScheduleSection: View {
    @Environment(Life.self) private var life
    let events: [DayEvent]
    let openReminder: (String) -> Void

    private enum Kind { case event, task, reminder }

    private struct Entry: Identifiable {
        let id: String
        let kind: Kind
        let at: Date
        let title: String
        let detail: String
        var cue: Wire.AgendaItem?
        var task: Wire.PlanItem?
        var reminder: Wire.Reminder?
        var cleared = false
        var due = false
    }

    private enum RailRow: Identifiable {
        case entry(Entry), now
        var id: String { switch self { case .entry(let e): e.id; case .now: "now" } }
    }

    // MARK: Today

    private var entries: [Entry] {
        var out: [Entry] = events.map { Entry(id: "e:" + $0.id, kind: .event, at: $0.start, title: $0.title, detail: "\($0.minutes) min") }
        out += life.tasks.filter { $0.kind != "event" && $0.startAt != nil }.map {
            Entry(id: "t:" + $0.id, kind: .task, at: $0.startAt!, title: $0.title, detail: $0.isPriority ? "\($0.minutes) min · Priority" : "\($0.minutes) min", task: $0)
        }
        out += life.agenda.map {
            Entry(id: "c:" + $0.id, kind: .reminder, at: $0.at, title: $0.reminder.title, detail: $0.reminder.recurrence != nil ? "Reminder · repeats" : "Reminder",
                  cue: $0, reminder: $0.reminder, cleared: $0.state == "acknowledged", due: $0.state == "due")
        }
        return out.sorted { $0.at < $1.at }
    }

    /// The entries with a marker where the current time falls among them.
    private var rows: [RailRow] {
        let now = Date()
        var out: [RailRow] = []
        var placed = false
        for e in entries {
            if !placed, e.at > now { out.append(.now); placed = true }
            out.append(.entry(e))
        }
        if !placed, !out.isEmpty { out.append(.now) }
        return out
    }

    private var nextID: String? { entries.first { $0.at > Date() }?.id }

    // MARK: Later

    private var later: [Entry] {
        let onToday = Set(life.agenda.map(\.reminder.id))
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
        return life.reminders.compactMap { r -> Entry? in
            guard !r.isDone, !onToday.contains(r.id), let at = r.snoozedUntil ?? r.dueAt, at >= tomorrow else { return nil }
            return Entry(id: "l:" + r.id, kind: .reminder, at: at, title: r.title, detail: r.recurrence != nil ? "Reminder · repeats" : "Reminder", reminder: r)
        }.sorted { $0.at < $1.at }.prefix(4).map { $0 }
    }

    var body: some View {
        Section {
            let list = rows
            if list.isEmpty { Text("Nothing scheduled today.").font(.mission(.body)).foregroundStyle(Tok.muted).padding(.vertical, Space.s) }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, row in
                switch row {
                case .now: nowRow(first: i == 0, last: i == list.count - 1)
                case .entry(let e): entryRow(e, first: i == 0, last: i == list.count - 1, next: e.id == nextID)
                }
            }
        } header: { Text("Schedule").font(.mission(.subheadline, .medium)).id(DayKind.cues) }
        .listRowBackground(Tok.surface)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: Space.l, bottom: 0, trailing: Space.l))

        let upcoming = later
        if !upcoming.isEmpty {
            Section {
                ForEach(Array(upcoming.enumerated()), id: \.element.id) { i, e in entryRow(e, first: i == 0, last: i == upcoming.count - 1, next: false, day: true) }
            } header: { Text("Later").font(.mission(.subheadline, .medium)) }
            .listRowBackground(Tok.surface)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Space.l, bottom: 0, trailing: Space.l))
        }
    }

    // MARK: Rows

    private let timeWidth: CGFloat = 62
    private let railWidth: CGFloat = 44

    /// The line the nodes sit on. It is cut at the top of the first row and the bottom of the last so it starts and ends at a node.
    private func rail(first: Bool, last: Bool, @ViewBuilder node: () -> some View) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(first ? Color.clear : Tok.hairline).frame(width: 2)
                Rectangle().fill(last ? Color.clear : Tok.hairline).frame(width: 2)
            }
            node()
        }
        .frame(width: railWidth)
    }

    private func entryRow(_ e: Entry, first: Bool, last: Bool, next: Bool, day: Bool = false) -> some View {
        let past = e.at < Date() && !e.due && e.kind != .task
        let tint: Color = e.due ? Tok.warn : (e.kind == .event ? MissionTone.scheduled.color : e.kind == .reminder ? MissionTone.reminder.color : Tok.accent)
        return HStack(alignment: .center, spacing: Space.s) {
            Text(day ? Self.dayTime(e.at) : e.at.formatted(date: .omitted, time: .shortened))
                .font(.missionMono(.caption, next || e.due ? .semibold : .regular)).foregroundStyle(e.due ? Tok.warn : next ? Tok.accent : Tok.muted)
                .frame(width: timeWidth, alignment: .trailing).lineLimit(2).multilineTextAlignment(.trailing)
            rail(first: first, last: last) { node(e, tint: tint, past: past) }
            Button { if let r = e.reminder { openReminder(r.id) } } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.title).font(.mission(.body, next ? .medium : .regular)).foregroundStyle(past || e.cleared ? Tok.muted : Tok.text).multilineTextAlignment(.leading)
                    Text(e.detail).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.borderless).disabled(e.reminder == nil)
            if e.due, let cue = e.cue {
                Button { Task { await life.ackCue(cue) } } label: {
                    Image(systemName: "checkmark.circle").font(.mission(.title2)).foregroundStyle(Tok.accent).frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless).disabled(life.busyReminders.contains(cue.reminder.id)).accessibilityLabel("Got it: \(e.title)")
            }
        }
        .padding(.vertical, 6).frame(minHeight: 56)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .swipeActions(edge: .trailing) {
            if let r = e.reminder { Button("Delete", role: .destructive) { Task { await life.deleteReminder(r) } } }
            if let t = e.task { Button("Delete", role: .destructive) { Task { await life.deleteTask(t) } } }
        }
        .swipeActions(edge: .leading) {
            if let r = e.reminder { Button("Snooze 1 hr", systemImage: "moon.zzz") { Task { await life.snoozeReminder(r, until: Date().addingTimeInterval(3600)) } }.tint(MissionTone.reminder.color) }
        }
    }

    /// The marker on the rail: a calendar for an event, a bell for a reminder (to come, waiting, cleared), a checkbox for a task.
    @ViewBuilder private func node(_ e: Entry, tint: Color, past: Bool) -> some View {
        switch e.kind {
        case .task:
            let done = e.task?.doneAt != nil
            Button { if let t = e.task { Task { await life.completeTask(t, done: !done) } } } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.mission(.title2)).foregroundStyle(done ? Tok.accent : Tok.muted)
                    .frame(width: 44, height: 44).background(Tok.surface, in: Circle())
            }
            .buttonStyle(.borderless).accessibilityLabel(done ? "Mark \(e.title) not done" : "Mark \(e.title) done")
        case .event:
            Image(systemName: "calendar").font(.mission(.footnote, .semibold)).foregroundStyle(tint)
                .frame(width: 32, height: 32).background(Tok.surface, in: Circle()).overlay { Circle().strokeBorder(tint.opacity(past ? 0.3 : 0.9), lineWidth: 2) }
                .accessibilityLabel("Calendar event")
        case .reminder:
            Image(systemName: e.cleared ? "bell.slash" : e.due ? "bell.badge.fill" : "bell").font(.mission(.footnote, .semibold)).foregroundStyle(past ? Tok.muted : tint)
                .frame(width: 32, height: 32).background(Tok.surface, in: Circle()).overlay { Circle().strokeBorder(tint.opacity(past || e.cleared ? 0.3 : 0.9), lineWidth: 2) }
                .accessibilityLabel("Reminder")
        }
    }

    /// Where the day is now: the current time on the left, a node on the rail and an accent line across.
    private func nowRow(first: Bool, last: Bool) -> some View {
        HStack(spacing: Space.s) {
            Text(Date().formatted(date: .omitted, time: .shortened)).font(.missionMono(.caption, .bold)).foregroundStyle(Tok.accent)
                .frame(width: timeWidth, alignment: .trailing)
            rail(first: first, last: last) { Circle().fill(Tok.accent).frame(width: 12, height: 12) }
            Rectangle().fill(Tok.accent).frame(height: 2)
                .overlay(alignment: .leading) { Text("Now").font(.missionMono(.caption, .bold)).foregroundStyle(Tok.onAccent).padding(.horizontal, 8).padding(.vertical, 2).background(Tok.accent, in: Capsule()) }
        }
        .frame(minHeight: 28).fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore).accessibilityLabel("Now, \(Date().formatted(date: .omitted, time: .shortened))")
    }

    /// "Thu 9:00 AM"
    static func dayTime(_ date: Date) -> String { date.formatted(.dateTime.weekday(.abbreviated).hour().minute()) }
}

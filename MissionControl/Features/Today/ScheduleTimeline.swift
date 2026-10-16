import SwiftUI

/// Timed items share one chronological rail; untimed work stays in Tasks. A routine is untimed work even when it has
/// nudge times: a nudge is the assistant's cue, not a time the person is due at, so it stays off this rail.
struct ScheduleSection: View {
    @Environment(Life.self) private var life
    @Environment(\.dynamicTypeSize) private var typeSize
    let events: [DayEvent]
    let openReminder: (String) -> Void
    let openTask: (String) -> Void

    private enum Kind { case event, task, reminder }
    private struct Entry: Identifiable {
        let id: String
        let kind: Kind
        let at: Date
        let title: String
        let detail: String
        var task: Wire.PlanItem?
        var cue: Wire.AgendaItem?
        var cleared: Bool { task?.doneAt != nil || cue?.state == "acknowledged" }
        var due: Bool { cue?.state == "due" }
    }
    private enum RailRow: Identifiable {
        case entry(Entry), now
        var id: String { switch self { case .entry(let e): e.id; case .now: "now" } }
    }

    private var entries: [Entry] {
        var result = events.map { Entry(id: "e:" + $0.id, kind: .event, at: $0.start, title: $0.title, detail: "Calendar · \($0.minutes) min") }
        result += life.tasks.compactMap { t in
            guard let at = t.startAt else { return nil }
            let goal = life.goals.first { $0.id == t.goalId }?.title
            let detail = [t.kind == "event" ? "Event" : t.kind == "checkin" ? "Check-in" : "\(t.minutes) min", goal, t.isPriority ? "Priority" : nil].compactMap { $0 }.joined(separator: " · ")
            return Entry(id: "t:" + t.id, kind: t.kind == "event" ? .event : .task, at: at, title: t.title, detail: detail, task: t)
        }
        result += life.agenda.map { Entry(id: "c:" + $0.id, kind: .reminder, at: $0.at, title: $0.reminder.title,
                                         detail: $0.state == "acknowledged" ? "Reminder · acknowledged" : $0.state == "due" ? "Reminder · waiting for you" : "Reminder", cue: $0) }
        return result.sorted { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }
    }
    private var rows: [RailRow] {
        var result: [RailRow] = []
        var placed = false
        for e in entries {
            if !placed, e.at > Date() { result.append(.now); placed = true }
            result.append(.entry(e))
        }
        if !placed, !result.isEmpty { result.append(.now) }
        return result
    }

    var body: some View {
        Section {
            if rows.isEmpty {
                Text("No timed items today.").font(.mission(.body)).foregroundStyle(Tok.muted).padding(.vertical, Space.s)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                switch row {
                case .now: nowRow
                case .entry(let e): entryRow(e, first: i == 0, last: i == rows.count - 1)
                }
            }
        } header: { Text("Schedule").font(.mission(.subheadline, .medium)) }
        .listRowBackground(Tok.surface).listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: Space.l, bottom: 0, trailing: Space.l))
    }

    private func entryRow(_ e: Entry, first: Bool, last: Bool) -> some View {
        HStack(spacing: Space.s) {
            if !typeSize.isAccessibilitySize {
                Text(time(e.at)).font(.missionMono(.caption)).foregroundStyle(e.due ? Tok.warn : Tok.muted)
                    .frame(width: 62, alignment: .trailing).multilineTextAlignment(.trailing)
            }
            ZStack {
                if !typeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        Rectangle().fill(first ? Color.clear : Tok.hairline)
                        Rectangle().fill(last ? Color.clear : Tok.hairline)
                    }.frame(width: 2)
                }
                node(e)
            }.frame(width: 44)
            if e.kind == .event {
                content(e)
            } else {
                Button { open(e) } label: { content(e) }.buttonStyle(.borderless)
            }
            if e.due, let cue = e.cue {
                Button { Task { await life.ackCue(cue) } } label: {
                    Image(systemName: "checkmark.circle").font(.mission(.title2)).frame(width: 44, height: 44)
                }.buttonStyle(.borderless).disabled(life.busyReminders.contains(cue.reminder.id))
                    .accessibilityLabel("Got it: \(e.title)")
            }
        }
        .padding(.vertical, Space.s).frame(minHeight: 60).fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if let cue = e.cue {
                Button("Snooze 1 hr", systemImage: "moon.zzz") { Task { await life.snoozeReminder(cue.reminder, until: Date().addingTimeInterval(3600)) } }
                    .tint(MissionTone.reminder.color)
            }
        }
    }

    private func content(_ e: Entry) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if typeSize.isAccessibilitySize { Text(time(e.at)).font(.mission(.caption)).foregroundStyle(Tok.muted) }
            Text(e.title).font(.mission(.body)).foregroundStyle(e.cleared ? Tok.muted : Tok.text).multilineTextAlignment(.leading)
            Text(e.detail).font(.mission(.caption)).foregroundStyle(e.due ? Tok.warn : Tok.muted).multilineTextAlignment(.leading)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }

    @ViewBuilder private func node(_ e: Entry) -> some View {
        if e.kind == .task, let t = e.task {
            Button { Task { await life.completeTask(t, done: t.doneAt == nil) } } label: {
                Image(systemName: e.cleared ? "checkmark.circle.fill" : "circle").font(.mission(.title2))
                    .frame(width: 44, height: 44).background(Tok.surface, in: Circle())
            }.buttonStyle(.borderless).disabled(life.busyTasks.contains(t.id))
                .accessibilityLabel("Mark \(e.title) \(e.cleared ? "not done" : "done")")
        } else {
            Image(systemName: e.kind == .event ? "calendar" : e.cleared ? "bell.slash" : e.due ? "bell.badge.fill" : "bell")
                .font(.mission(.body)).foregroundStyle(e.kind == .event ? MissionTone.scheduled.color : MissionTone.reminder.color)
                .frame(width: 44, height: 44).background(Tok.surface, in: Circle()).accessibilityHidden(true)
        }
    }

    private func open(_ e: Entry) {
        if let r = e.cue { openReminder(r.reminder.id) }
        else if let t = e.task { openTask(t.id) }
    }
    private func time(_ at: Date) -> String {
        Calendar.current.isDateInToday(at) ? at.formatted(date: .omitted, time: .shortened) : at.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
    private var nowRow: some View {
        HStack(spacing: Space.s) {
            Text("Now · " + Date().formatted(date: .omitted, time: .shortened)).font(.mission(.caption, .medium))
            Rectangle().fill(Tok.accent.opacity(0.4)).frame(height: 1)
        }.foregroundStyle(Tok.accent).frame(minHeight: 32)
            .accessibilityElement(children: .combine)
    }
}

import SwiftUI

/// The day's timed items in one chronological rail, shown as a compact window a few rows tall with Now centred: the
/// day scrolls inside the window instead of growing the page. Untimed work stays in Tasks — a routine is untimed work
/// even when it has nudge times, because a nudge is the assistant's cue rather than a time the person is due at.
/// Today's reminder cues sit on the rail at their time; the full list lives in Goals ▸ Reminders.
struct ScheduleSection: View {
    @Environment(Life.self) private var life
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let events: [DayEvent]
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
    }
    private enum Row: Identifiable {
        case entry(Entry), now
        var id: String { switch self { case .entry(let e): e.id; case .now: ScheduleWindow.nowID } }
    }

    /// The scroller rests on the Now rule until the person moves it.
    @State private var centered: String? = ScheduleWindow.nowID

    private var entries: [Entry] {
        var result = events.map { Entry(id: "e:" + $0.id, kind: .event, at: $0.start, title: $0.title, detail: "Calendar · \($0.minutes) min") }
        result += life.tasks.compactMap { t in
            guard let at = t.startAt else { return nil }
            let goal = life.goals.first { $0.id == t.goalId }?.title
            let detail = [t.kind == "event" ? "Event" : t.kind == "checkin" ? "Check-in" : "\(t.minutes) min", goal, t.isPriority ? "Priority" : nil].compactMap { $0 }.joined(separator: " · ")
            return Entry(id: "t:" + t.id, kind: t.kind == "event" ? .event : .task, at: at, title: t.title, detail: detail, task: t)
        }
        result += life.agenda.map {
            Entry(id: "r:" + $0.id, kind: .reminder, at: $0.at, title: $0.reminder.title,
                  detail: $0.overdue ? "Reminder · Overdue" : "Reminder", cue: $0)
        }
        return result.sorted { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }
    }

    private var placements: [ScheduleWindow.Placement] {
        ScheduleWindow.placements(items: entries.map { (id: $0.id, at: $0.at) }, now: Date())
    }

    private var rows: [Row] {
        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        return placements.compactMap { placement in
            if placement.isNow { return .now }
            return byID[placement.id].map(Row.entry)
        }
    }

    private var away: Bool { ScheduleWindow.isAway(centered: centered) }

    var body: some View {
        Section {
            if rows.isEmpty {
                Text("No timed items today.").font(.mission(.body)).foregroundStyle(Tok.muted)
                    .padding(.horizontal, Space.l).padding(.vertical, Space.s)
            } else {
                window
            }
        } header: { Text("Schedule").font(.mission(.subheadline, .medium)) }
        .listRowInsets(EdgeInsets())              // the window draws its own gutters
        .listRowSeparator(.hidden)
        .listRowBackground(Tok.surface)
    }

    private var window: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Group {
                        switch row {
                        case .now: nowRow
                        case .entry(let e): entryRow(e, first: index == 0, last: index == rows.count - 1)
                        }
                    }
                    .id(row.id)
                    // Rows crossing the window's edges soften, so it reads as a window over the day rather than a cut list.
                    .scrollTransition(reduceMotion ? .identity : .animated(.easeOut(duration: 0.2))) { content, phase in
                        content.opacity(phase.isIdentity ? 1 : 0.35)
                            .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.97)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Space.l)
        }
        .frame(height: ScheduleWindow.height(rowCount: rows.count, isAccessibilitySize: typeSize.isAccessibilitySize))
        .scrollPosition(id: $centered, anchor: .center)
        .overlay(alignment: .bottomTrailing) {
            if away {
                Chip(title: "Back to now", symbol: "arrow.down") {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { centered = ScheduleWindow.nowID }
                }
                .padding(Space.s)
                .transition(.opacity)
                .accessibilityLabel("Back to now")
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: rows.map(\.id))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: away)
        // A minute passing moves the Now rule; keep the window on it unless the person has scrolled away themselves.
        .onChange(of: rows.map(\.id)) { _, _ in
            guard !away else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { centered = ScheduleWindow.nowID }
        }
    }

    private func entryRow(_ e: Entry, first: Bool, last: Bool) -> some View {
        HStack(spacing: Space.s) {
            if !typeSize.isAccessibilitySize {
                Text(time(e.at)).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
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
            if e.kind != .task {
                content(e)
            } else {
                Button { open(e) } label: { content(e) }.buttonStyle(.borderless)
            }
        }
        .padding(.vertical, Space.s).frame(minHeight: 60).fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }

    private func content(_ e: Entry) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if typeSize.isAccessibilitySize { Text(time(e.at)).font(.mission(.caption)).foregroundStyle(Tok.muted) }
            Text(e.title).font(.mission(.body)).foregroundStyle(e.cleared ? Tok.muted : Tok.text).multilineTextAlignment(.leading)
            Text(e.detail).font(.mission(.caption)).foregroundStyle(Tok.muted).multilineTextAlignment(.leading)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }

    @ViewBuilder private func node(_ e: Entry) -> some View {
        if e.kind == .task, let t = e.task {
            Button { Task { await life.completeTask(t, done: t.doneAt == nil) } } label: {
                Image(systemName: e.cleared ? "checkmark.circle.fill" : "circle").font(.mission(.title2))
                    .frame(width: 44, height: 44).background(Tok.surface, in: Circle())
            }.buttonStyle(.borderless).disabled(life.busyTasks.contains(t.id))
                .accessibilityLabel("Mark \(e.title) \(e.cleared ? "not done" : "done")")
        } else if e.kind == .reminder, let cue = e.cue {
            Button { Task { await life.ackCue(cue) } } label: {
                Image(systemName: e.cleared ? "bell.fill" : "bell").font(.mission(.title2))
                    .frame(width: 44, height: 44).background(Tok.surface, in: Circle())
            }.buttonStyle(.borderless).disabled(e.cleared || life.busyReminders.contains(cue.reminder.id))
                .accessibilityLabel(e.cleared ? "\(e.title) acknowledged" : "Got it: \(e.title)")
        } else {
            Image(systemName: "calendar")
                .font(.mission(.body)).foregroundStyle(MissionTone.scheduled.color)
                .frame(width: 44, height: 44).background(Tok.surface, in: Circle()).accessibilityHidden(true)
        }
    }

    private func open(_ e: Entry) {
        if let t = e.task { openTask(t.id) }
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

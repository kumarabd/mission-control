import SwiftUI

/// The day's timed items in one chronological rail, shown as a compact window a few rows tall with Now centred: the
/// day scrolls inside the window instead of growing the page. Events (the phone's calendar and the engine's), and tasks that
/// have a time, sit on it at that time; each occurrence of a repeating one has its own row. Untimed and overdue tasks stay in
/// Tasks.
struct ScheduleSection: View {
    @Environment(Life.self) private var life
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let events: [DayEvent]
    let openItem: (ItemRef) -> Void

    private enum Kind { case calendar, event, task }
    private struct Entry: Identifiable {
        let id: String
        let kind: Kind
        let at: Date
        let title: String
        let detail: String
        var item: Wire.Item?
        var cleared: Bool = false
    }
    private enum Row: Identifiable {
        case entry(Entry), now
        var id: String { switch self { case .entry(let e): e.id; case .now: ScheduleWindow.nowID } }
    }

    /// The scroller rests on the Now rule until the person moves it.
    @State private var centered: String? = ScheduleWindow.nowID

    private var entries: [Entry] {
        var result = events.map { Entry(id: "c:" + $0.id, kind: .calendar, at: $0.start, title: $0.title, detail: "Calendar · \($0.minutes) min") }
        result += (life.day?.entries ?? []).filter { !$0.overdue }.map { e in
            let item = e.item
            let goal = life.goals.first { $0.id == item.goalId }?.title
            let length = item.minutes.map { "\($0) min" }
            let detail = [item.isEvent ? "Event" : "Task", length, goal, item.isPriority ? "Priority" : nil, item.repeats ? "Repeats" : nil].compactMap { $0 }.joined(separator: " · ")
            return Entry(id: "i:" + e.id, kind: item.isEvent ? .event : .task, at: e.at, title: item.title, detail: detail, item: item, cleared: e.isDone)
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
            if e.item == nil {
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
        if e.kind == .task, let item = e.item {
            Button { Task { await life.complete(item, at: item.repeats ? e.at : nil, done: !e.cleared) } } label: {
                Image(systemName: e.cleared ? "checkmark.circle.fill" : "circle").font(.mission(.title2))
                    .frame(width: 44, height: 44).background(Tok.surface, in: Circle())
            }.buttonStyle(.borderless).disabled(life.busyItems.contains(item.id))
                .accessibilityLabel("Mark \(e.title) \(e.cleared ? "not done" : "done")")
        } else {
            Image(systemName: "calendar")
                .font(.mission(.body)).foregroundStyle(MissionTone.scheduled.color)
                .frame(width: 44, height: 44).background(Tok.surface, in: Circle()).accessibilityHidden(true)
        }
    }

    private func open(_ e: Entry) {
        if let item = e.item { openItem(ItemRef(id: item.id, at: item.repeats ? e.at : nil)) }
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

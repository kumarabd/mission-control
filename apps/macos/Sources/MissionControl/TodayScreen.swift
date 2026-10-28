import EventKit
import SwiftUI

/// Today at desktop detail: the day's timed rail beside everything still to
/// do. The same `day_get` / `tasks_list` records the web and phone show.
struct TodayScreen: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(Life.self) private var life
    @Environment(NotificationsModel.self) private var notifications

    @State private var calendarEvents: [DayEvent] = []
    @State private var newItem: NewItem?
    @State private var editingItem: Wire.Item?
    @State private var selectedItem: ItemRef?
    @State private var loading = true
    @State private var showCompleted = false
    @State private var centeredOnNow = false

    private struct NewItem: Identifiable {
        let kind: ItemsService.Kind
        var id: String { kind.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            ConsolePageHeader(
                "Today",
                eyebrow: Date().formatted(.dateTime.weekday(.wide).month(.wide).day()),
                description: daySummary
            ) {
                Button { newItem = NewItem(kind: .task) } label: {
                    Label("Add a task", systemImage: "checklist")
                }
                .buttonStyle(.borderedProminent)
                Button { newItem = NewItem(kind: .event) } label: {
                    Label("Add an event", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.bordered)
                if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                    Button("Include my calendar", systemImage: "calendar.badge.plus") {
                        Task { calendarEvents = await DayEvents.today(requestAccess: true) }
                    }
                    .buttonStyle(.bordered)
                }
                if loading {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel("Loading today")
                }
            }
            statsStrip
            if let loadError = life.dayLoadError, life.day == nil {
                ConsoleNotice(title: "Today couldn't load", message: loadError) {
                    Task { await refresh() }
                }
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.m)
            }
            Divider()
            HSplitView {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    schedulePanel
                }
                .frame(minWidth: 420, idealWidth: 520)
                tasksPanel
                    .frame(minWidth: 360, idealWidth: 440)
            }
        }
        .background(Tok.background)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    workspace.showNotifications()
                } label: {
                    Label(notifications.unread == 0 ? "Notifications" : "Notifications, \(notifications.unread) unread",
                          systemImage: notifications.unread == 0 ? "tray" : "tray.full")
                }
                Button { Task { await refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task { await refresh() }
        .onChange(of: workspace.pendingItem) { _, ref in
            if let ref { selectedItem = ref; workspace.pendingItem = nil }
        }
        .onChange(of: workspace.pendingNewItem) { _, kind in
            guard let kind else { return }
            newItem = NewItem(kind: kind)
            workspace.pendingNewItem = nil
        }
        .onAppear {
            if let ref = workspace.pendingItem { selectedItem = ref; workspace.pendingItem = nil }
            if let kind = workspace.pendingNewItem {
                newItem = NewItem(kind: kind)
                workspace.pendingNewItem = nil
            }
        }
        .sheet(item: $newItem) { item in
            ItemEditor(mode: .new(goalID: nil), initialKind: item.kind)
        }
        .sheet(item: $editingItem) { item in
            ItemEditor(mode: .edit(item))
        }
        .sheet(item: $selectedItem) { ref in
            TaskDetailView(ref: ref)
                .frame(width: 540, height: 600)
        }
        .alert("Couldn't update your day", isPresented: Binding(
            get: { life.error != nil },
            set: { if !$0 { life.error = nil } })) {
            Button("OK") { life.error = nil }
        } message: {
            Text(life.error ?? "")
        }
    }

    private var statsStrip: some View {
        let entries = life.day?.entries ?? []
        let tasks = entries.filter { $0.item.isTask }
        let done = tasks.filter(\.isDone).count
        let timed = entries.count + calendarEvents.count
        let upcoming = entries.filter { $0.at >= Date() }.min { $0.at < $1.at }
        return HStack(spacing: Space.m) {
            ConsoleStat(label: "Tasks done", value: "\(done)/\(tasks.count)", hint: "today", symbol: "checkmark.circle")
            ConsoleStat(label: "Timed", value: "\(timed)", hint: "on the schedule", symbol: "clock")
            ConsoleStat(
                label: "Next up",
                value: upcoming?.at.formatted(date: .omitted, time: .shortened) ?? "Clear",
                hint: upcoming?.item.title ?? "No timed items left",
                symbol: "arrow.right.circle",
                tint: Tok.scheduled
            )
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.m)
    }

    private var daySummary: String {
        let entries = life.day?.entries ?? []
        let tasks = entries.filter { $0.item.isTask }
        let done = tasks.filter(\.isDone).count
        let timed = entries.count + calendarEvents.count
        return "\(done) of \(tasks.count) tasks done · \(timed) timed \(timed == 1 ? "item" : "items")"
    }

    // MARK: Schedule

    private struct ScheduleEntry: Identifiable {
        enum Kind { case calendar, event, task }
        let id: String
        let kind: Kind
        let at: Date
        let title: String
        let detail: String
        var item: Wire.Item?
        var occurrence: Date?
        var cleared = false
    }

    private enum ScheduleRow: Identifiable {
        case entry(ScheduleEntry), now
        var id: String {
            switch self {
            case .entry(let entry): entry.id
            case .now: ScheduleWindow.nowID
            }
        }
    }

    private var entries: [ScheduleEntry] {
        var result = calendarEvents.map { event in
            ScheduleEntry(id: "c:" + event.id, kind: .calendar, at: event.start, title: event.title,
                          detail: "Calendar · \(event.minutes) min")
        }
        result += (life.day?.entries ?? []).filter { !$0.overdue }.map { entry in
            let item = entry.item
            let goal = life.goals.first { $0.id == item.goalId }?.title
            let detail = [item.isEvent ? "Event" : "Task",
                          item.minutes.map { "\($0) min" },
                          goal,
                          item.isPriority ? "Priority" : nil,
                          item.repeats ? "Repeats" : nil]
                .compactMap { $0 }.joined(separator: " · ")
            return ScheduleEntry(id: "i:" + entry.id, kind: item.isEvent ? .event : .task, at: entry.at,
                                 title: item.title, detail: detail, item: item,
                                 occurrence: item.repeats ? entry.at : nil, cleared: entry.isDone)
        }
        return result.sorted { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }
    }

    private var rows: [ScheduleRow] {
        guard !entries.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let placements = ScheduleWindow.placements(items: entries.map { ($0.id, $0.at) }, now: Date())
        return placements.compactMap { placement in
            placement.isNow ? .now : byID[placement.id].map(ScheduleRow.entry)
        }
    }

    private var schedulePanel: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHeading("Schedule", detail: "\(entries.count) timed")
                .padding(.horizontal, Space.l)
            ConsolePanel {
                VStack(spacing: 0) {
                    if loading && entries.isEmpty {
                        ConsoleSkeletonRows(count: 3)
                    } else if rows.isEmpty {
                        empty("No timed items today.", symbol: "clock",
                              actionTitle: "Add an event") {
                            newItem = NewItem(kind: .event)
                        }
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                        switch row {
                                        case .now: nowRow
                                        case .entry(let entry): entryRow(entry)
                                        }
                                        if index < rows.count - 1 {
                                            Divider().padding(.leading, 112)
                                        }
                                    }
                                }
                                .padding(.vertical, Space.xs)
                            }
                            .onAppear {
                                guard !centeredOnNow else { return }
                                centeredOnNow = true
                                proxy.scrollTo(ScheduleWindow.nowID, anchor: .center)
                            }
                            .onChange(of: rows.map(\.id)) { _, _ in
                                proxy.scrollTo(ScheduleWindow.nowID, anchor: .center)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var nowRow: some View {
        HStack(spacing: Space.s) {
            Text("Now · " + Date().formatted(date: .omitted, time: .shortened))
                .font(.missionMono(.caption, .medium))
            Rectangle().fill(Tok.accent.opacity(0.5)).frame(height: 1)
        }
        .foregroundStyle(Tok.accent)
        .padding(.vertical, Space.s)
        .id(ScheduleWindow.nowID)
        .accessibilityElement(children: .combine)
    }

    private func entryRow(_ entry: ScheduleEntry) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Text(entry.at.formatted(date: Calendar.current.isDateInToday(entry.at) ? .omitted : .abbreviated,
                                    time: .shortened))
                .font(.missionMono(.caption))
                .foregroundStyle(Tok.muted)
                .frame(width: 64, alignment: .trailing)
            ZStack {
                Rectangle().fill(Tok.hairline).frame(width: 2)
                node(entry)
            }
            .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.mission(.body, .medium))
                    .strikethrough(entry.cleared)
                    .foregroundStyle(entry.cleared ? Tok.muted : Tok.text)
                Text(entry.detail).font(.mission(.caption)).foregroundStyle(Tok.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if let item = entry.item {
                    selectedItem = ItemRef(id: item.id, at: entry.occurrence)
                }
            }
            .accessibilityAddTraits(entry.item == nil ? [] : .isButton)
            .accessibilityAction {
                if let item = entry.item {
                    selectedItem = ItemRef(id: item.id, at: entry.occurrence)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .hoverHighlight(radius: 0)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func node(_ entry: ScheduleEntry) -> some View {
        if entry.kind == .task, let item = entry.item {
            Button {
                Task { await life.complete(item, at: item.repeats ? entry.occurrence : nil, done: !entry.cleared) }
            } label: {
                Image(systemName: entry.cleared ? "checkmark.circle.fill" : "circle")
                    .font(.mission(.title3))
                    .foregroundStyle(entry.cleared ? Tok.accent : Tok.accent)
                    .background(Tok.background, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(life.busyItems.contains(item.id))
            .accessibilityLabel("Mark \(entry.title) \(entry.cleared ? "not done" : "done")")
        } else {
            Image(systemName: entry.kind == .calendar ? "calendar" : "calendar.badge.clock")
                .font(.mission(.caption))
                .foregroundStyle(entry.kind == .calendar ? Tok.muted : Tok.scheduled)
                .frame(width: 24, height: 24)
                .background(Tok.background, in: Circle())
                .accessibilityHidden(true)
        }
    }

    // MARK: Tasks

    private struct TaskCard: Identifiable {
        let item: Wire.Item
        var at: Date?
        var overdue = false
        var id: String { item.id + (at.map { "@" + String(Int($0.timeIntervalSince1970)) } ?? "") }
        var title: String { item.title }
        var detail: String {
            var parts: [String] = []
            if overdue, let at { parts.append("Was due " + at.formatted(.dateTime.month(.abbreviated).day())) }
            if let minutes = item.minutes { parts.append("\(minutes) min") }
            if item.isPriority { parts.append("Priority") }
            if item.repeats { parts.append("Repeats") }
            return parts.joined(separator: " · ")
        }
    }

    private var cards: [TaskCard] {
        let overdue = (life.day?.entries ?? []).filter(\.overdue).map {
            TaskCard(item: $0.item, at: $0.at, overdue: true)
        }
        let untimed = life.openTasks.filter { $0.at == nil }.map { TaskCard(item: $0, at: nil) }
        let all = overdue + untimed
        return all.filter(\.item.isPriority) + all.filter { !$0.item.isPriority }
    }

    private var tasksPanel: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHeading("Tasks", detail: cards.isEmpty ? "No set time" : "\(cards.count) to do")
                .padding(.horizontal, Space.l)
            ConsolePanel {
                VStack(spacing: 0) {
                    if loading && life.day == nil && cards.isEmpty {
                        ConsoleSkeletonRows(count: 3)
                    } else if !life.workspaceAvailable {
                        empty("Connect your workspace to see today's tasks.", symbol: "icloud.slash")
                    } else if life.dayLoadError != nil && life.openTasks.isEmpty {
                        ConsoleNotice(title: "Tasks didn't load", message: life.dayLoadError) {
                            Task { await life.loadDay() }
                        }
                        .padding(Space.m)
                    } else if cards.isEmpty {
                        empty("Nothing untimed is waiting.", symbol: "checkmark.seal",
                              actionTitle: "Add a task") {
                            newItem = NewItem(kind: .task)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(cards) { card in
                                    taskRow(card)
                                    if card.id != cards.last?.id {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                            }
                            .padding(.vertical, Space.xs)
                        }
                    }
                    completedSection
                }
            }
            .frame(maxHeight: .infinity)
            Text("Things to do without a set time.")
                .font(.mission(.caption2))
                .foregroundStyle(Tok.muted)
                .padding(.horizontal, Space.m)
        }
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func taskRow(_ card: TaskCard) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Button {
                Task { await life.complete(card.item, at: card.item.repeats ? card.at : nil) }
            } label: {
                Image(systemName: "circle")
                    .font(.mission(.title3))
                    .foregroundStyle(Tok.accent)
            }
            .buttonStyle(.plain)
            .disabled(life.busyItems.contains(card.item.id))
            .accessibilityLabel("Mark done: \(card.title)")

            Button {
                selectedItem = ItemRef(id: card.item.id, at: card.item.repeats ? card.at : nil)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.item.title)
                        .font(.mission(.body, card.item.isPriority ? .semibold : .regular))
                        .foregroundStyle(Tok.text)
                    let goal = life.goals.first { $0.id == card.item.goalId }?.title
                    Text([card.detail, goal ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.mission(.caption))
                        .foregroundStyle(Tok.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if card.item.isPriority {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Tok.warn)
                    .accessibilityLabel("Priority")
            }
            Menu {
                taskActions(card)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.mission(.caption, .medium))
                    .foregroundStyle(Tok.muted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Options for \(card.title)")
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .hoverHighlight(radius: 0)
        .contextMenu { taskActions(card) }
    }

    @ViewBuilder private func taskActions(_ card: TaskCard) -> some View {
        Button("Open") { selectedItem = ItemRef(id: card.item.id, at: card.item.repeats ? card.at : nil) }
        Button("Edit") { editingItem = card.item }
        Button(card.item.isPriority ? "Remove priority" : "Mark as priority") {
            var draft = ItemsService.Draft(card.item)
            draft.isPriority.toggle()
            Task { _ = await life.save(card.item, draft) }
        }
        Divider()
        Button("Delete", role: .destructive) { Task { _ = await life.delete(card.item) } }
    }

    @ViewBuilder private var completedSection: some View {
        let done = (life.day?.entries ?? []).filter { $0.item.isTask && $0.isDone }
        if !done.isEmpty {
            Divider()
            DisclosureGroup(isExpanded: $showCompleted) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(done) { entry in
                        HStack(spacing: Space.s) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tok.accent)
                            Text(entry.item.title)
                                .strikethrough()
                                .foregroundStyle(Tok.muted)
                            Spacer()
                        }
                        .font(.mission(.subheadline))
                    }
                }
                .padding(.top, Space.s)
            } label: {
                Text("Completed today · \(done.count)")
                    .font(.missionMono(.caption, .medium))
                    .foregroundStyle(Tok.muted)
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.m)
        }
    }

    private func empty(_ message: String, symbol: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: Space.s) {
            Image(systemName: symbol).font(.mission(.title)).foregroundStyle(Tok.accent.opacity(0.7))
            Text(message).font(.mission(.body)).foregroundStyle(Tok.muted)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, Space.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Space.xl)
    }

    private func refresh() async {
        loading = true
        await life.refreshWorkspace()
        calendarEvents = await DayEvents.today()
        loading = false
    }
}

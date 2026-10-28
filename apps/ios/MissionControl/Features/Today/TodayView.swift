import SwiftUI
import EventKit

struct TodayView: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @Environment(NotificationsModel.self) private var notifications
    @State private var events: [DayEvent] = []
    @State private var sheet: Sheet?
    @State private var openGoal: GoalRef?
    @State private var openItem: ItemRef?
    @State private var showNotifications = false
    /// A record a notification pointed at, held until the inbox screen has gone, so it cannot fight Today's own sheets.
    @State private var deferred: PushLink.Target?
    @State private var loading = true
    @Environment(\.horizontalSizeClass) private var sizeClass

    enum Sheet: Identifiable { case task, event; var id: Self { self } }

    /// Tasks with no time, and the ones still waiting from earlier days; priorities first.
    private var dueCards: [TaskCard] {
        let overdue = (life.day?.entries ?? []).filter(\.overdue).map { TaskCard(item: $0.item, at: $0.at, overdue: true) }
        let untimed = life.openTasks.filter { $0.at == nil }.map { TaskCard(item: $0, at: nil) }
        let cards = overdue + untimed
        return cards.filter(\.item.isPriority) + cards.filter { !$0.item.isPriority }
    }

    private var doneItems: Int { (life.day?.entries ?? []).filter { $0.item.isTask && $0.isDone }.count }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Group {
                    if sizeClass == .regular {
                        // iPad: the day's schedule beside what is still to do, instead of one long list.
                        HStack(alignment: .top, spacing: Space.l) {
                            List { schedule }.scrollContentBackground(.hidden)
                            List { tasks }.scrollContentBackground(.hidden)
                        }
                        .readableWidth(1100)
                    } else {
                        List { header; schedule; tasks }.scrollContentBackground(.hidden)
                    }
                }
                .screenBackground()
                .refreshable { await refresh() }
            }
            .navigationTitle("Today")
            .navigationSubtitle(sizeClass == .regular ? Date().formatted(.dateTime.weekday(.wide).month(.wide).day()) : "")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AppMark() }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showNotifications = true } label: {
                        Image(systemName: notifications.unread == 0 ? "tray" : "tray.full")
                            .frame(minWidth: 44, minHeight: 44)
                            .overlay(alignment: .topTrailing) {
                                if notifications.unread > 0 {
                                    Text("\(notifications.unread)")
                                        .font(.missionMono(.caption2, .medium))
                                        .foregroundStyle(Tok.onAccent)
                                        .padding(.horizontal, 5).frame(minHeight: 16)
                                        .background(Tok.accent, in: Capsule())
                                        .accessibilityHidden(true)
                                }
                            }
                    }
                    .accessibilityLabel(notifications.unread == 0 ? "Notifications" : "Notifications, \(notifications.unread) unread")
                    Menu {
                        Button("Add a task", systemImage: "checklist") { sheet = .task }
                        Button("Add an event", systemImage: "calendar.badge.plus") { sheet = .event }
                    } label: { Label("Add", systemImage: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Add a task or event")
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
            }
            .sheet(item: $sheet) { s in
                ItemFormSheet(mode: .new(goalID: nil), initialKind: s == .event ? .event : .task)
            }
            .sheet(item: $openItem) { ItemDetailSheet(ref: $0) }
            .navigationDestination(item: $openGoal) { GoalDetail(goalID: $0.id) }
            .navigationDestination(isPresented: $showNotifications) { NotificationsView(open: route) }
            .onAppear { openLink(DeepLink.shared.pending) }
            .onChange(of: DeepLink.shared.pending) { _, target in openLink(target) }
            .onChange(of: showNotifications) { _, shown in
                guard !shown, let target = deferred else { return }
                deferred = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(350))   // let the pop finish before presenting anything
                    DeepLink.shared.pending = target
                }
            }
            .task { await refresh(); loading = false }
            .alert("Couldn't update your day", isPresented: Binding(get: { life.error != nil }, set: { if !$0 { life.error = nil } })) {
                Button("OK") { life.error = nil }
            } message: { Text(life.error ?? "") }
        }
    }

    private var header: some View {
        Section {
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
        }.listRowBackground(Color.clear)
    }

    @ViewBuilder private var schedule: some View {
        if loading {
            Section { Label("Loading your day…", systemImage: "clock").foregroundStyle(Tok.muted) }
        } else {
            if !life.workspaceAvailable {
                Section { Text("Connect your workspace to see today's schedule and tasks.").foregroundStyle(Tok.muted) }
            }
            if let error = life.dayLoadError {
                Section {
                    Label("Some items couldn't load", systemImage: "wifi.exclamationmark").font(.mission(.headline))
                    Text(error).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    Button("Try again") { Task { await refresh() } }.frame(minHeight: 44)
                }.listRowBackground(Tok.surface)
            }
            ScheduleSection(events: events, openItem: { openItem = $0 })
        }
    }

    @ViewBuilder private var tasks: some View {
        if !loading {
            tasksSection
            if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
                Section {
                    Button("Include my calendar", systemImage: "calendar.badge.plus") {
                        Task { events = await DayEvents.today(requestAccess: true) }
                    }.frame(minHeight: 44)
                }.listRowBackground(Tok.surface)
            }
        }
    }

    private func refresh() async {
        await life.refreshWorkspace()
        events = await DayEvents.today()
    }

    /// A tapped notification: let the inbox screen close first, then follow its link.
    private func route(_ target: PushLink.Target) {
        deferred = target
        showNotifications = false
    }

    private func openLink(_ target: PushLink.Target?) {
        guard let target else { return }
        switch target.entity {
        case "task", "event": openItem = ItemRef(id: target.id)
        default: return
        }
        DeepLink.shared.pending = nil
    }

    private var tasksSection: some View {
        Section {
            TaskDeck(cards: dueCards, doneToday: doneItems) { openItem = $0.ref }
        } header: {
            Text("Tasks").font(.mission(.subheadline, .medium))
        } footer: { Text("Things to do without a set time.").font(.mission(.footnote)) }
        .listRowBackground(Tok.surface)
    }
}

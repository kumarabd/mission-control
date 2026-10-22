import SwiftUI
import EventKit

struct TodayView: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @Environment(NotificationsModel.self) private var notifications
    @State private var events: [DayEvent] = []
    @State private var sheet: Sheet?
    @State private var openRoutine: RoutineRef?
    @State private var openGoal: GoalRef?
    @State private var openTask: PlanItemRef?
    @State private var showNotifications = false
    /// A record a notification pointed at, held until the inbox screen has gone, so it cannot fight Today's own sheets.
    @State private var deferred: PushLink.Target?
    @State private var loading = true
    @Environment(\.horizontalSizeClass) private var sizeClass

    enum Sheet: Identifiable { case add, reminder; var id: Self { self } }

    private var flexibleTasks: [Wire.PlanItem] { TodayLayout.untimedTasks(life.tasks) }
    private var flexibleRoutines: [Wire.RoutineStatus] { TodayLayout.untimedRoutines(life.routines) }

    private var dueCards: [TaskCard] {
        let open = flexibleTasks.filter { $0.doneAt == nil }
        var cards = (open.filter(\.isPriority) + open.filter { !$0.isPriority }).map(TaskCard.task)
        if let s = life.nextSuggestion, s.source == "goal_step", !life.tasks.contains(where: { $0.stepId == s.stepId }) { cards.append(.step(s)) }
        cards += flexibleRoutines.filter { !$0.done }.map(TaskCard.routine)
        return cards
    }

    private var doneItems: Int {
        flexibleTasks.filter { $0.doneAt != nil }.count + flexibleRoutines.filter(\.done).count
    }

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
                        Button("Add a task", systemImage: "checklist") { sheet = .add }
                        Button("Add a reminder", systemImage: "bell") { sheet = .reminder }
                    } label: { Label("Add", systemImage: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Add a task or reminder")
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
            }
            .sheet(item: $sheet) { s in
                switch s {
                case .add: AddPlanItemSheet()
                case .reminder: AddReminderSheet()
                }
            }
            .sheet(item: $openTask) { PlanItemDetailSheet(id: $0.id) }
            .navigationDestination(item: $openRoutine) { RoutineDetailView(id: $0.id) }
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
            if !life.planAvailable && !life.routinesAvailable {
                Section { Text("Connect your workspace to see today's schedule and tasks.").foregroundStyle(Tok.muted) }
            }
            if let error = life.planLoadError ?? life.routinesLoadError {   // reminders are Goals ▸ Reminders' business
                Section {
                    Label("Some items couldn't load", systemImage: "wifi.exclamationmark").font(.mission(.headline))
                    Text(error).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    Button("Try again") { Task { await refresh() } }.frame(minHeight: 44)
                }.listRowBackground(Tok.surface)
            }
            ScheduleSection(events: events, openTask: { openTask = PlanItemRef(id: $0) })
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
        case "routine": openRoutine = RoutineRef(id: target.id)
        case "plan_item": openTask = PlanItemRef(id: target.id)
        // A reminder belongs to Goals ▸ Reminders now: leave it pending so that tab takes it.
        default: return
        }
        DeepLink.shared.pending = nil
    }

    private var tasksSection: some View {
        Section {
            TaskDeck(cards: dueCards, doneToday: doneItems) { card in
                switch card {
                case .routine(let s): openRoutine = RoutineRef(id: s.id)
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


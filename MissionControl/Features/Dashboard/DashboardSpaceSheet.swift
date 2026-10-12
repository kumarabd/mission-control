import SwiftUI
import SwiftData

enum DashboardSpace: String, Identifiable, CaseIterable {
    case projects, garage, systems, health, pantry, wardrobe, tasks, taskList, schedule, reply, spinach, spaces, focus
    var id: String { rawValue }
    var title: String {
        switch self {
        case .projects: "Projects"
        case .garage: "Garage"
        case .systems: "Devices"
        case .health: "Health"
        case .pantry: "Pantry"
        case .wardrobe: "Wardrobe"
        case .tasks: "Tasks"
        case .taskList: "All tasks"
        case .schedule: "Timeline"
        case .reply, .spinach: "Needs attention"
        case .spaces: "Your spaces"
        case .focus: "Choose your focus"
        }
    }
    var symbol: String {
        switch self {
        case .projects: "folder"
        case .garage: "car.side"
        case .systems: "desktopcomputer"
        case .health: "heart.text.square"
        case .pantry: "basket"
        case .wardrobe: "tshirt"
        case .tasks, .taskList: "checklist"
        case .schedule: "calendar"
        case .reply: "exclamationmark.bubble"
        case .spinach: "bell"
        case .spaces: "square.grid.2x2"
        case .focus: "scope"
        }
    }
    var accent: Color {
        switch self {
        case .projects, .schedule: MissionTheme.scheduled
        case .garage, .systems: MissionTheme.telemetry
        case .health: MissionTheme.health
        case .pantry, .tasks, .taskList, .focus: MissionTheme.tint
        case .wardrobe, .spinach: MissionTheme.reminder
        case .reply: MissionTheme.attention
        case .spaces: MissionTheme.quietText
        }
    }
    var examples: [SpaceExample] {
        switch self {
        case .health:
            []
        case .garage:
            [SpaceExample(title: "Daily driver", subtitle: "Vehicle data not connected", symbol: "car.side", detail: "This space will hold vehicle records and available readings. No vehicle health assessment is available."),
             SpaceExample(title: "Maintenance", subtitle: "Service dates and records", symbol: "wrench", detail: "Maintenance reminders will appear here when your vehicle records are added.", tone: .reminder)]
        case .systems:
            [SpaceExample(title: "MacBook", subtitle: "Sample · CPU 24% · memory 10 / 16 GB", symbol: "laptopcomputer", detail: "These illustrative readings show the layout only. No device monitoring or telemetry is connected."),
             SpaceExample(title: "Home server", subtitle: "Monitoring not connected", symbol: "server.rack", detail: "Device readings and recent alerts will appear here when a monitoring source is connected."),
             SpaceExample(title: "Services", subtitle: "No services connected", symbol: "network", detail: "No service availability assessment is available yet.")]
        case .pantry:
            [SpaceExample(title: "Use soon", subtitle: "Sample · spinach, use by tomorrow", symbol: "bell", detail: "Example inventory: spinach. Plan to use it in your next meal. This is not a saved pantry item.", tone: .reminder),
             SpaceExample(title: "Running low", subtitle: "Sample · milk and eggs", symbol: "exclamationmark.bubble", detail: "Example inventory: milk almost empty; two eggs remaining.", tone: .attention),
             SpaceExample(title: "Shopping list", subtitle: "Sample · three items", symbol: "list.bullet", detail: "Example list: milk, eggs, and bread. Pantry editing is not connected yet.")]
        case .wardrobe:
            [SpaceExample(title: "Everyday outfits", subtitle: "Sample · light layers", symbol: "tshirt", detail: "Example outfit: an overshirt, cotton tee, and comfortable trousers. This is not based on your wardrobe or live weather."),
             SpaceExample(title: "Laundry & care", subtitle: "Sample · blue shirt at the cleaner", symbol: "bell", detail: "Example reminder: collect the blue shirt on Wednesday. No real care record has been added.", tone: .reminder),
             SpaceExample(title: "Your clothes", subtitle: "Categories for your collection", symbol: "square.grid.2x2", detail: "Tops, bottoms, outerwear, and shoes will live here. Your wardrobe is not connected.")]
        default: []
        }
    }
}

struct SpaceExample: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let subtitle: String
    let symbol: String
    let detail: String
    var tone: MissionTone? = nil
}

struct DashboardSpaceSheet: View {
    let space: DashboardSpace
    let tasks: [MissionTask]
    let repositories: [GitHubRepository]
    var selectedFocus: MissionTask? = nil
    var onChooseFocus: ((MissionTask) -> Void)? = nil
    let onDelete: (MissionTask) -> Void
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.48).ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                    .transition(.opacity)

                NavigationStack {
                    DashboardSpaceScreen(space: space, repositories: repositories, selectedFocus: selectedFocus,
                                         onChooseFocus: onChooseFocus, onDelete: onDelete, isSheet: true,
                                         onDismiss: onDismiss)
                        .navigationDestination(for: DashboardSpace.self) { selected in
                            DashboardSpaceScreen(space: selected, repositories: repositories, selectedFocus: selectedFocus,
                                                 onChooseFocus: onChooseFocus, onDelete: onDelete, isSheet: true,
                                                 onDismiss: onDismiss)
                        }
                }
                .frame(width: proxy.size.width * 0.9, height: proxy.size.height * 0.9)
                .background(MissionTheme.canvas, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
            }
            .accessibilityAddTraits(.isModal)
        }
    }
}

/// The same content lives in the centered dashboard detail panel on every device.
struct DashboardSpaceScreen: View {
    let space: DashboardSpace
    let repositories: [GitHubRepository]
    var selectedFocus: MissionTask? = nil
    var onChooseFocus: ((MissionTask) -> Void)? = nil
    let onDelete: (MissionTask) -> Void
    var isSheet = false
    var onDismiss: (() -> Void)? = nil
    @Query(sort: \MissionTask.createdAt) private var tasks: [MissionTask]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewTask = false
    @State private var saveError: String?
    @State private var timelineDestination: DashboardSpace?
    @State private var lastCompleted: MissionTask?

    var body: some View {
        Group {
            if space == .tasks {
                timeline
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        MissionIconBadge(symbol: space.symbol, color: space.accent)
                        contents
                    }
                        .padding(16).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }
            }
        }
            .background(MissionTheme.canvas)
            .navigationTitle(space.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isSheet {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { close() } }
                }
                if space == .tasks || space == .taskList || space == .schedule {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add task", systemImage: "plus") { showingNewTask = true }
                    }
                }
            }
            .navigationDestination(for: SpaceExample.self) { example in
                SpaceExampleDetail(example: example, accent: example.tone?.color ?? space.accent)
            }
            .navigationDestination(for: GitHubRepository.self) { repository in
                RepositoryDetail(repository: repository)
            }
        .foregroundStyle(MissionTheme.ink).tint(MissionTheme.tint)
        .navigationDestination(item: $timelineDestination) { selected in
            DashboardSpaceScreen(space: selected, repositories: repositories, selectedFocus: selectedFocus,
                                 onChooseFocus: onChooseFocus, onDelete: onDelete)
        }
        .sheet(isPresented: $showingNewTask) { NewTaskSheet(onSave: addTask) }
        .alert("Couldn’t save task", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
    }

    @ViewBuilder private var contents: some View {
        switch space {
        case .spaces:
            Text("Everything else, when you need it.").font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
            ForEach([DashboardSpace.tasks, .projects, .garage, .systems, .health, .pantry, .wardrobe]) { destination in
                NavigationLink(value: destination) {
                    HStack(spacing: 14) {
                        MissionIconBadge(symbol: destination.symbol, color: destination.accent)
                        Text(destination.title).font(.mission(.headline))
                        Spacer()
                        Image(systemName: "chevron.right").font(.mission(.caption)).accessibilityHidden(true)
                    }.frame(minHeight: 48).padding(.vertical, 8).contentShape(Rectangle())
                }.buttonStyle(MissionPressStyle())
                Divider().overlay(MissionTheme.line)
            }
        case .focus:
            Text("Pick the one thing you want to move forward.")
                .font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
            if tasks.allSatisfy(\.isCompleted) {
                ContentUnavailableView("Nothing waiting", systemImage: "checkmark.circle", description: Text("Add a task in Tasks to choose a focus."))
            }
            ForEach(tasks.filter { !$0.isCompleted }) { task in
                Button { onChooseFocus?(task); close() } label: {
                    MissionCard {
                        HStack(spacing: 12) {
                            MissionIconBadge(symbol: task.id == selectedFocus?.id ? "scope" : "circle", color: MissionTheme.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.mission(.headline))
                                Text(task.id == selectedFocus?.id ? "Current focus" : "Make this my focus")
                                    .font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
                                TaskTimingLabel(date: task.scheduledAt)
                            }
                            Spacer()
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }.buttonStyle(MissionPressStyle())
                    .accessibilityHint("Sets your current focus and returns to the previous view")
            }
            NavigationLink("Manage all tasks", value: DashboardSpace.taskList).frame(minHeight: 44)
        case .tasks, .taskList:
            TaskListView(tasks: tasks, onDelete: onDelete)
        case .projects:
            Text("Sample repositories · activity is based on pushed_at")
                .font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
            ProjectListView(repositories: repositories)
        case .schedule:
            Text("Planned times · local tasks").font(.mission(.headline))
            Text("Calendar isn’t connected. These times appear on your dashboard; notifications aren’t enabled.")
                .font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
            let scheduled = tasks.filter { !$0.isCompleted && $0.scheduledAt != nil }
                .sorted { $0.scheduledAt! < $1.scheduledAt! }
            if scheduled.isEmpty {
                ContentUnavailableView("No set times", systemImage: "clock", description: Text("Add a task with a specific time, or set a time from a task’s menu."))
            }
            ForEach(scheduled) { task in
                TaskRowView(task: task, onDelete: { onDelete(task) })
            }
        case .health:
            HealthSpaceView()
        case .reply, .spinach:
            MissionStatusLabel(title: space == .reply ? "Needs action · Sample" : "Reminder · Sample", tone: space == .reply ? .attention : .reminder)
            Text(space == .reply ? "Reply to Sam" : "Use the spinach").font(.mission(.title2, .medium))
            Text(space == .reply ? "An answer is needed today to confirm dinner plans." : "Plan the spinach into a meal by tomorrow to avoid waste.")
            Text("This illustrates how a timely exception will surface. It isn’t connected to your messages or pantry.")
                .font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
            if space == .spinach {
                NavigationLink("Explore pantry example", value: DashboardSpace.pantry.examples[0])
                    .frame(minHeight: 44)
            }
        default:
            Text(space == .garage ? "No vehicle records connected" : "Design examples · not live data")
                .font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
            ForEach(space.examples) { example in
                NavigationLink(value: example) {
                    MissionCard {
                        HStack(spacing: 14) {
                            MissionIconBadge(symbol: example.symbol, color: example.tone?.color ?? space.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(example.title).font(.mission(.headline))
                                Text(example.subtitle).font(.mission(.subheadline)).foregroundStyle(MissionTheme.quietText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.mission(.caption)).accessibilityHidden(true)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.buttonStyle(MissionPressStyle())
            }
        }
    }
    private var timeline: some View {
        GeometryReader { geometry in
            ScrollView {
                DashboardHeightLayout(minimumHeight: geometry.size.height, spacing: 8) {
                    DayTimelineView(tasks: tasks, focus: selectedFocus, onComplete: completeTask,
                                    onSelectFocus: { onChooseFocus?($0) },
                                    onOpen: { timelineDestination = $0 }, onAdd: { showingNewTask = true })
                        .layoutValue(key: DashboardExpandsVertically.self, value: true)
                    HStack {
                        Text("\(tasks.filter(\.isCompleted).count) of \(tasks.count) tasks complete")
                        Spacer()
                        if let task = lastCompleted, tasks.contains(where: { $0 === task }), task.isCompleted {
                            Button("Undo") {
                                task.isCompleted = false
                                do { try modelContext.save(); onChooseFocus?(task); lastCompleted = nil }
                                catch { task.isCompleted = true; saveError = error.localizedDescription }
                            }.frame(minHeight: 44)
                        }
                    }.font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
                        .padding(.horizontal, 16).padding(.bottom, 8)
                }
            }.scrollBounceBehavior(.basedOnSize)
        }
    }

    private func completeTask(_ task: MissionTask) {
        task.isCompleted = true
        do { try modelContext.save(); lastCompleted = task }
        catch { task.isCompleted = false; saveError = error.localizedDescription }
    }

    private func close() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    private func addTask(_ title: String, scheduledAt: Date?) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let task = MissionTask(title: cleaned, scheduledAt: scheduledAt)
        modelContext.insert(task)
        do { try modelContext.save() }
        catch { modelContext.delete(task); saveError = error.localizedDescription }
    }
}

private struct SpaceExampleDetail: View {
    let example: SpaceExample
    let accent: Color
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MissionIconBadge(symbol: example.symbol, color: accent)
                if let tone = example.tone {
                    MissionStatusLabel(title: "\(tone.label) · Sample", tone: tone)
                } else {
                    Label("Preview · Not connected", systemImage: "link.badge.plus").font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
                }
                Text(example.title).font(.mission(.title2, .medium))
                Text(example.detail).foregroundStyle(MissionTheme.quietText)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }.background(MissionTheme.canvas).navigationTitle(example.title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct RepositoryDetail: View {
    let repository: GitHubRepository
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MissionIconBadge(symbol: "folder", color: MissionTheme.scheduled)
                Text("Sample repository").font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
                Text(repository.name).font(.mission(.title2, .medium))
                if let description = repository.description { Text(description) }
                if let date = repository.pushedAt {
                    Label("Last push \(date.formatted(.relative(presentation: .named)))", systemImage: "clock")
                        .foregroundStyle(MissionTheme.quietText)
                } else { Text("No push activity available").foregroundStyle(MissionTheme.quietText) }
                Link(destination: repository.htmlURL) {
                    Label("Open repository on GitHub", systemImage: "arrow.up.right").frame(minHeight: 44)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }.background(MissionTheme.canvas).navigationTitle(repository.name).navigationBarTitleDisplayMode(.inline)
    }
}

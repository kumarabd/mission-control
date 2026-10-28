import SwiftUI

/// Goals, with the desktop room for a list beside its detail. The same goals,
/// tasks and events the assistant writes through the Life Engine.
struct GoalsScreen: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(Life.self) private var life

    @State private var segment = Segment.goals
    @State private var selectedGoal: GoalRef?
    @State private var selectedItem: ItemRef?
    @State private var newKind: ItemsService.Kind?
    @State private var newGoalID: String?
    @State private var editingItem: Wire.Item?
    @State private var goalToArchive: Wire.Goal?

    enum Segment: String, CaseIterable, Identifiable {
        case goals = "Goals", tasks = "Tasks", events = "Events"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            ConsolePageHeader(segment.rawValue, eyebrow: "Workspace", description: segmentDescription) {
                Button { new() } label: {
                    Label(newLabel, systemImage: segment == .goals ? "square.and.pencil" : "plus")
                }
                .buttonStyle(.borderedProminent)
                Button { Task { await life.refreshWorkspace() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            HSplitView {
                list
                    .frame(minWidth: 300, idealWidth: 360, maxWidth: 460)
                detail
                    .frame(minWidth: 480)
            }
        }
        .background(Tok.background)
        .navigationTitle(segment.rawValue)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if segment == .goals, let goal = selectedGoalRecord {
                    Menu {
                        Button("Add a task", systemImage: "checklist") {
                            newGoalID = goal.id
                            newKind = .task
                        }
                        Button("Add an event", systemImage: "calendar.badge.plus") {
                            newGoalID = goal.id
                            newKind = .event
                        }
                        Button("Talk about this goal", systemImage: "bubble.left") {
                            workspace.discuss("About my goal \u{201C}\(goal.title)\u{201D}: ")
                        }
                        Divider()
                        Button("Archive goal", systemImage: "archivebox", role: .destructive) {
                            goalToArchive = goal
                        }
                    } label: {
                        Label("Goal actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .task { await life.refreshWorkspace() }
        .onChange(of: life.goals) { _, goals in
            if let id = selectedGoal?.id, !goals.contains(where: { $0.id == id }) {
                selectedGoal = goals.first.map { GoalRef(id: $0.id) }
            } else if selectedGoal == nil, segment == .goals, let first = goals.first {
                selectedGoal = GoalRef(id: first.id)
            }
        }
        .onChange(of: workspace.pendingGoalID) { _, id in
            guard let id else { return }
            segment = .goals
            selectedGoal = GoalRef(id: id)
            workspace.pendingGoalID = nil
        }
        .onChange(of: workspace.pendingItem) { _, ref in
            guard let ref, workspace.destination == .goals else { return }
            segment = .tasks
            selectedItem = ref
            workspace.pendingItem = nil
        }
        .onAppear {
            if let id = workspace.pendingGoalID {
                segment = .goals
                selectedGoal = GoalRef(id: id)
                workspace.pendingGoalID = nil
            } else if let ref = workspace.pendingItem {
                segment = .tasks
                selectedItem = ref
                workspace.pendingItem = nil
            } else if selectedGoal == nil, let first = life.goals.first {
                selectedGoal = GoalRef(id: first.id)
            }
        }
        .sheet(item: $newKind, onDismiss: { newGoalID = nil }) { kind in
            ItemEditor(mode: .new(goalID: newGoalID), initialKind: kind)
        }
        .sheet(item: $editingItem) { item in
            ItemEditor(mode: .edit(item))
        }
        .alert("Couldn't update this", isPresented: Binding(
            get: { life.error != nil },
            set: { if !$0 { life.error = nil } })) {
            Button("OK") { life.error = nil }
        } message: {
            Text(life.error ?? "")
        }
        .confirmationDialog("Archive this goal?", isPresented: Binding(
            get: { goalToArchive != nil },
            set: { if !$0 { goalToArchive = nil } }),
            titleVisibility: .visible) {
            Button("Archive", role: .destructive) {
                guard let goal = goalToArchive else { return }
                Task {
                    await life.archive(goal)
                    selectedGoal = nil
                    goalToArchive = nil
                }
            }
        } message: {
            Text("Its tasks and events stay. You can ask your assistant to bring it back.")
        }
    }

    private var selectedGoalRecord: Wire.Goal? {
        guard let id = selectedGoal?.id else { return nil }
        return life.goals.first { $0.id == id }
    }

    private var list: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $segment) {
                ForEach(Segment.allCases) { item in
                    Text("\(item.rawValue) \(count(for: item))").tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.m)

            switch segment {
            case .goals:
                GoalsList(selection: $selectedGoal) { startGoal() }
            case .tasks:
                TasksList(open: { selectedItem = $0 }) { newKind = .task }
            case .events:
                EventsList(open: { selectedItem = $0 }) { newKind = .event }
            }
        }
        .background(Tok.surface)
    }

    private var detail: some View {
        NavigationStack {
            Group {
                switch segment {
                case .goals:
                    if let selectedGoal {
                        GoalDetail(goalID: selectedGoal.id)
                            .id(selectedGoal.id)
                    } else {
                        ContentUnavailableView("Select a goal", systemImage: "flag",
                                               description: Text("Its progress, tasks and composed view appear here."))
                    }
                case .tasks, .events:
                    if let selectedItem {
                        TaskDetailView(ref: selectedItem) { self.selectedItem = nil }
                            .id(selectedItem.id + String(describing: selectedItem.at))
                    } else {
                        ContentUnavailableView(
                            segment == .tasks ? "Select a task" : "Select an event",
                            systemImage: segment == .tasks ? "checklist" : "calendar",
                            description: Text("Its record appears here."))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func new() {
        switch segment {
        case .goals: startGoal()
        case .tasks: newKind = .task
        case .events: newKind = .event
        }
    }

    private var newLabel: String {
        switch segment {
        case .goals: "New goal"
        case .tasks: "New task"
        case .events: "New event"
        }
    }

    private func count(for segment: Segment) -> Int {
        switch segment {
        case .goals: life.goals.count
        case .tasks: life.openTasks.count
        case .events: life.upcomingEvents.count
        }
    }

    private var segmentDescription: String {
        switch segment {
        case .goals:
            "\(count(for: .goals)) \(count(for: .goals) == 1 ? "goal" : "goals"). What you’re working toward; progress comes from the tasks and events linked to each one."
        case .tasks:
            "\(count(for: .tasks)) open \(count(for: .tasks) == 1 ? "task" : "tasks"). Things to do; a repeating task is a routine, a time is a deadline or a cue."
        case .events:
            "\(count(for: .events)) \(count(for: .events) == 1 ? "event" : "events"). Things that happen at a set time, whether or not anyone acts."
        }
    }

    private func startGoal() {
        workspace.discuss("I want to ")
    }
}

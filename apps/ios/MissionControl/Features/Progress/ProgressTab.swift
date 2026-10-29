import SwiftUI

/// Where what you are working toward lives: goals, the tasks that serve them (and the ones that stand alone), and what is coming
/// up on the calendar.
struct ProgressTab: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    @State private var segment = Segment.goals
    @State private var sheet: ItemsService.Kind?
    @State private var detail: ItemRef?
    @State private var path = NavigationPath()
    @State private var selectedGoal: GoalRef?
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var splitGoals: Bool { sizeClass == .regular && segment == .goals }

    enum Segment: String, CaseIterable, Identifiable { case goals = "Goals", tasks = "Tasks", events = "Events"; var id: Self { self } }

    init(onSettings: @escaping () -> Void = {}) {
        self.onSettings = onSettings
        #if DEBUG
        // `-start-segment tasks` opens a developer build on that segment, like `-start-tab`.
        if let name = UserDefaults.standard.string(forKey: "start-segment"), let s = Segment(rawValue: name.capitalized) { _segment = State(initialValue: s) }
        // `-open-goal g1` pushes that goal's screen (iPhone).
        if let id = UserDefaults.standard.string(forKey: "open-goal") {
            _path = State(initialValue: NavigationPath([GoalRef(id: id)]))
        }
        // `-select-goal g1` selects it in the iPad split without pushing a stack.
        if let id = UserDefaults.standard.string(forKey: "select-goal") {
            _selectedGoal = State(initialValue: GoalRef(id: id))
        }
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Show", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, Space.l).padding(.vertical, Space.s)
                switch segment {
                case .goals: goals
                case .tasks: TasksList(open: { detail = $0 }) { sheet = .task }
                case .events: EventsList(open: { detail = $0 }) { sheet = .event }
                }
            }
            .readableWidth(splitGoals ? .infinity : 720)
            .screenBackground()
            .navigationTitle(segment.rawValue)
            .navigationDestination(for: GoalRef.self) { GoalDetail(goalID: $0.id) }
            .onAppear { openLink(DeepLink.shared.pending) }
            .onChange(of: DeepLink.shared.pending) { _, target in openLink(target) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AppMark() }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { new() } label: { Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel(newLabel)
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
            }
            .sheet(item: $sheet) { ItemFormSheet(mode: .new(goalID: nil), initialKind: $0).environment(life) }
            .sheet(item: $detail) { ItemDetailSheet(ref: $0) }
        }
    }

    /// iPhone pushes a goal; iPad keeps the list as a column and shows the selected goal beside it.
    @ViewBuilder private var goals: some View {
        if sizeClass == .regular {
            HStack(spacing: 0) {
                GoalsList(selection: $selectedGoal) { startGoal() }.frame(width: 380)
                Divider()
                NavigationStack {
                    if let selectedGoal { GoalDetail(goalID: selectedGoal.id).id(selectedGoal.id) }
                    else { ContentUnavailableView("Select a goal", systemImage: "flag", description: Text("Its progress and tasks appear here.")) }
                }
            }
        } else {
            GoalsList { startGoal() }
        }
    }

    /// A goal is made in conversation; a task or an event is a form.
    private func new() {
        switch segment {
        case .goals: startGoal()
        case .tasks: sheet = .task
        case .events: sheet = .event
        }
    }

    private func startGoal() { chat.request(draft: "I want to ") }

    private var newLabel: String {
        switch segment { case .goals: "New goal"; case .tasks: "New task"; case .events: "New event" }
    }

    /// A tapped notification opens the record it is about: a task or event in a sheet here, a goal in Goals.
    private func openLink(_ target: PushLink.Target?) {
        guard let target else { return }
        switch target.entity {
        case "goal":
            segment = .goals
            if sizeClass == .regular { selectedGoal = GoalRef(id: target.id) } else { path = NavigationPath([GoalRef(id: target.id)]) }
        case "task", "event": detail = ItemRef(id: target.id)
        default: return          // not ours; MainTabs clears anything unroutable
        }
        DeepLink.shared.pending = nil
    }
}

extension ItemsService.Kind: Identifiable { var id: String { rawValue } }

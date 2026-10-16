import SwiftUI

/// Where the things you keep doing live: goals you are working toward, routines you keep up, and the reminders
/// waiting to be told to you.
struct ProgressTab: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    @State private var segment = Segment.goals
    @State private var sheet: Sheet?
    @State private var detail: ReminderRef?
    @State private var path = NavigationPath()

    enum Segment: String, CaseIterable, Identifiable { case goals = "Goals", routines = "Routines", reminders = "Reminders"; var id: Self { self } }
    enum Sheet: Identifiable { case routine, reminder; var id: Self { self } }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Show", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, Space.l).padding(.vertical, Space.s)
                switch segment {
                case .routines: RoutinesList { sheet = .routine }
                case .goals: GoalsList { startGoal() }
                case .reminders: RemindersList(detail: $detail) { sheet = .reminder }
                }
            }
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
            .sheet(item: $sheet) { s in
                switch s {
                case .routine: NewRoutineSheet().environment(life)
                case .reminder: AddReminderSheet().environment(life)
                }
            }
            .sheet(item: $detail) { ReminderDetailSheet(id: $0.id) }
        }
    }

    /// A goal is made in conversation; a routine or a reminder is a form.
    private func new() {
        switch segment {
        case .goals: startGoal()
        case .routines: sheet = .routine
        case .reminders: sheet = .reminder
        }
    }

    private func startGoal() { chat.request(draft: "I want to ") }

    private var newLabel: String {
        switch segment { case .goals: "New goal"; case .routines: "New routine"; case .reminders: "New reminder" }
    }

    /// A tapped notification opens the record it is about: a reminder in this tab's Reminders segment, a goal in Goals.
    private func openLink(_ target: PushLink.Target?) {
        guard let target else { return }
        switch target.entity {
        case "goal": segment = .goals; path = NavigationPath([GoalRef(id: target.id)])
        case "reminder": segment = .reminders; detail = ReminderRef(id: target.id)
        default: return          // not ours; MainTabs clears anything unroutable
        }
        DeepLink.shared.pending = nil
    }
}

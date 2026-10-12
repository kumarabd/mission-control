import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MissionTask.createdAt) private var tasks: [MissionTask]
    @AppStorage("dashboardAppearance") private var appearance = "graphite"
    @AppStorage("dashboardAmbientMotion") private var ambientMotion = true
    @AppStorage("dashboardFocusReference") private var focusReference = ""
    @State private var space: DashboardSpace?
    @State private var showingNewTask = false
    @State private var showingSettings = false
    @State private var saveError: String?

    private let repositories = MockGitHubService().repositories()
    private var focus: MissionTask? { TaskFocusSelection.resolve(tasks: tasks, reference: focusReference) }
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    private var animateAmbient: Bool {
        ambientMotion && !reduceMotion && scenePhase == .active && space == nil && !showingNewTask && !showingSettings
    }
    private var scheme: ColorScheme? {
        appearance == "system" ? nil : (appearance == "pearl" ? .light : .dark)
    }

    var body: some View {
        assistantHome
        .background(MissionTheme.canvas.ignoresSafeArea())
        .foregroundStyle(MissionTheme.ink).tint(MissionTheme.tint)
        .preferredColorScheme(scheme)
        // Only the dashboard is immersive. Keep native navigation in task/detail flows.
        .statusBarHidden(space == nil && !showingNewTask && !showingSettings)
        .overlay {
            if let selected = space {
                DashboardSpaceSheet(space: selected, tasks: tasks, repositories: repositories, selectedFocus: focus,
                                    onChooseFocus: chooseFocus, onDelete: deleteTask,
                                    onDismiss: dismissSpace)
                    .preferredColorScheme(scheme)
            }
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskSheet(onSave: addTask).preferredColorScheme(scheme)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            DashboardSettings(appearance: $appearance, ambientMotion: $ambientMotion).preferredColorScheme(scheme)
        }
        .alert("Couldn’t save your change", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
    }

    private var assistantHome: some View {
        AssistantHomeView(tasks: tasks, focus: focus, compact: isPhone, ambient: animateAmbient,
                          onOpen: openSpace, onAdd: { showingNewTask = true },
                          onSettings: { showingSettings = true })
    }

    private func openSpace(_ selected: DashboardSpace) {
        withAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.46, dampingFraction: 0.86)) {
            space = selected
        }
    }

    private func dismissSpace() {
        withAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.36, dampingFraction: 0.92)) {
            space = nil
        }
    }

    private func chooseFocus(_ task: MissionTask) {
        guard !task.isCompleted else { return }
        focusReference = TaskFocusSelection.reference(for: task)
    }

    private func addTask(title: String, scheduledAt: Date?) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let task = MissionTask(title: clean, scheduledAt: scheduledAt)
        modelContext.insert(task)
        do { try modelContext.save() }
        catch { modelContext.delete(task); saveError = error.localizedDescription }
    }
    private func deleteTask(_ task: MissionTask) {
        modelContext.delete(task)
        do { try modelContext.save() }
        catch { modelContext.rollback(); saveError = error.localizedDescription }
    }
}

#Preview {
    DashboardView().modelContainer(for: MissionTask.self, inMemory: true)
}

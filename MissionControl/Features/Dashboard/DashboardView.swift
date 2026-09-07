import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MissionTask.createdAt) private var tasks: [MissionTask]
    @State private var showingNewTask = false

    private let repositories = MockGitHubService().repositories()

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        DashboardHeader(date: context.date, remainingTaskCount: remainingTaskCount)
                        TaskListView(tasks: tasks, onDelete: deleteTask)
                    ProjectListView(repositories: repositories)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
            }
            .background(MissionTheme.canvas)
            .navigationTitle("Mission Control")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add task", systemImage: "plus") { showingNewTask = true }
                        .accessibilityHint("Creates a task for today")
                }
            }
        }
        .tint(MissionTheme.tint)
        .task {
            if tasks.isEmpty { addStarterTasks() }
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskSheet(onSave: addTask)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func addTask(title: String) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }
        modelContext.insert(MissionTask(title: cleanedTitle))
    }

    private func addStarterTasks() {
        ["Design Mission Control UI", "Review agent harness notes", "Buy groceries"].forEach { addTask(title: $0) }
    }

    private func deleteTask(_ task: MissionTask) {
        modelContext.delete(task)
    }

    private var remainingTaskCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }
}

private struct DashboardHeader: View {
    let date: Date
    let remainingTaskCount: Int

    var body: some View {
        MissionCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting)
                            .font(.headline)
                            .foregroundStyle(MissionTheme.quietText)
                        Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.title2.weight(.bold))
                    }
                    Spacer()
                    Image(systemName: "sun.max.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.yellow)
                        .font(.title2)
                        .accessibilityHidden(true)
                }

                HStack(alignment: .lastTextBaseline) {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.largeTitle.weight(.bold))
                        .monospacedDigit()
                    Spacer()
                    Label(taskSummary, systemImage: remainingTaskCount == 0 ? "checkmark.circle.fill" : "circle.dotted")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(remainingTaskCount == 0 ? .green : MissionTheme.tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private var taskSummary: String {
        remainingTaskCount == 0 ? "All clear" : "\(remainingTaskCount) to focus on"
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: MissionTask.self, inMemory: true)
}

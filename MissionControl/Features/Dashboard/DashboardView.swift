import SwiftUI
import SwiftData
import Combine

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MissionTask.createdAt) private var tasks: [MissionTask]
    @State private var currentDate = Date.now

    private let repositories = MockGitHubService().repositories()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    DashboardHeader(date: currentDate)
                    TaskListView(tasks: tasks, onAddTask: addTask)
                    ProjectListView(repositories: repositories)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Mission Control")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            if tasks.isEmpty { addStarterTasks() }
            for await _ in Timer.publish(every: 1, on: .main, in: .common).autoconnect().values {
                currentDate = .now
            }
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
}

private struct DashboardHeader: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: MissionTask.self, inMemory: true)
}

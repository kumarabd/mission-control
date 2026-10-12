import SwiftUI

struct TaskListView: View {
    let tasks: [MissionTask]
    let onDelete: (MissionTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Tasks", detail: "\(tasks.filter { !$0.isCompleted }.count) open")

            if tasks.isEmpty {
                ContentUnavailableView("Nothing planned", systemImage: "checkmark.circle", description: Text("Add a task to shape your day."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                MissionCard {
                    VStack(spacing: 0) {
                        ForEach(tasks) { task in
                            TaskRowView(task: task, onDelete: { onDelete(task) })
                            if task.id != tasks.last?.id { Divider().padding(.leading, 58) }
                        }
                    }
                }
            }
        }
    }
}

struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, Date?) -> Void
    @State private var title = ""
    @State private var hasTime = false
    @State private var scheduledAt = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("What needs your attention?") {
                    TextField("Task", text: $title)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                TaskTimingFields(hasTime: $hasTime, scheduledAt: $scheduledAt)
            }
                .scrollContentBackground(.hidden)
                .background(MissionTheme.canvas)
                .navigationTitle("New Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }
    }

    private func save() {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        onSave(cleaned, hasTime ? scheduledAt : nil)
        dismiss()
    }
}

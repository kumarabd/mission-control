import SwiftUI

struct TaskListView: View {
    let tasks: [MissionTask]
    let onDelete: (MissionTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Today", detail: "\(tasks.filter { !$0.isCompleted }.count) open")

            if tasks.isEmpty {
                ContentUnavailableView("Nothing planned", systemImage: "checkmark.circle", description: Text("Add a task to shape your day."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                MissionCard {
                    VStack(spacing: 0) {
                        ForEach(tasks) { task in
                            TaskRowView(task: task, onDelete: { onDelete(task) })
                            if task.id != tasks.last?.id { Divider().padding(.leading, 38) }
                        }
                    }
                }
            }
        }
    }
}

struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What needs your attention?") {
                    TextField("Task", text: $title)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
            }
                .navigationTitle("New Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }
    }

    private func save() { onSave(title); dismiss() }
}

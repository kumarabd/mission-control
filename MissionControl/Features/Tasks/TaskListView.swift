import SwiftUI

struct TaskListView: View {
    let tasks: [MissionTask]
    let onAddTask: (String) -> Void
    @State private var showingNewTask = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Button("Add task", systemImage: "plus") { showingNewTask = true }
                    .font(.subheadline.weight(.medium))
            }

            if tasks.isEmpty {
                ContentUnavailableView("Nothing planned", systemImage: "checkmark.circle", description: Text("Add a task to shape your day."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskRowView(task: task)
                        if task.id != tasks.last?.id { Divider().padding(.leading, 38) }
                    }
                }
                .padding(.horizontal, 14)
                .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskSheet(onSave: onAddTask)
                .presentationDetents([.height(210)])
        }
    }
}

private struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form { TextField("Task", text: $title).submitLabel(.done).onSubmit(save) }
                .navigationTitle("New Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }
    }

    private func save() { onSave(title); dismiss() }
}

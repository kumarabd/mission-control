import SwiftUI

struct PlanItemRef: Identifiable { let id: String }

struct PlanItemDetailSheet: View {
    let id: String
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    private var item: Wire.PlanItem? { life.tasks.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            Form {
                if let t = item {
                    Section {
                        Text(t.title).font(.mission(.title3, .medium))
                        LabeledContent("Time needed", value: "\(t.minutes) minutes")
                        if let at = t.startAt { LabeledContent("Scheduled", value: at.formatted(date: .abbreviated, time: .shortened)) }
                        if let goal = life.goals.first(where: { $0.id == t.goalId }) { Text("For \(goal.title)").foregroundStyle(Tok.muted) }
                    }
                    Section {
                        Button(t.doneAt == nil ? "Mark done" : "Mark not done", systemImage: "checkmark.circle") {
                            Task { await life.completeTask(t, done: t.doneAt == nil) }
                        }
                        Button(t.isPriority ? "Remove priority" : "Make a priority", systemImage: "star") {
                            Task { await life.setTaskPriority(t, !t.isPriority) }
                        }
                        Button("Delete task", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }.disabled(life.busyTasks.contains(t.id))
                    if let error = life.error { Section { Text(error).foregroundStyle(Tok.critical) } }
                } else { ContentUnavailableView("This task is gone", systemImage: "checklist") }
            }
            .scrollContentBackground(.hidden).screenBackground()
            .navigationTitle("Task").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    guard let item else { return }
                    Task { await life.deleteTask(item); if self.item == nil { dismiss() } }
                }
            }
        }.presentationDetents([.medium, .large])
    }
}
